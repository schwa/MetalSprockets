import Metal
import QuartzCore
import SwiftUI
import Synchronization

#if os(macOS)
import AppKit
internal typealias PlatformView = NSView
#else
import UIKit
internal typealias PlatformView = UIView
#endif

internal protocol MetalLayerViewDelegate: AnyObject, Sendable {
    /// Called on the main thread when the drawable size changes.
    @MainActor
    func metalLayerView(_ view: MetalLayerView, drawableSizeWillChange size: CGSize)

    /// Called on the surface's frame thread: the main thread, or the view's render thread.
    func render(on surface: MetalLayerSurface)

    /// Called once on the render thread when the view tears down, after its last frame.
    func finishRendering()
}

extension MetalLayerViewDelegate {
    func finishRendering() {
        // Nothing to finish by default.
    }
}

// MARK: - MetalLayerSurface

/// Settings the main thread writes and the frame thread reads at the start of each frame.
internal struct MetalSurfaceConfiguration: Sendable {
    var device: (any MTLDevice)?
    var colorPixelFormat: MTLPixelFormat = .bgra8Unorm
    var depthStencilPixelFormat: MTLPixelFormat = .invalid
    var depthStencilStorageMode: MTLStorageMode = .private
    var depthStencilAttachmentTextureUsage: MTLTextureUsage = .renderTarget
    var multisampleColorAttachmentTextureUsage: MTLTextureUsage = .renderTarget
    var sampleCount = 1
    var clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    var clearDepth: Double = 1
    var clearStencil: UInt32 = 0
    var drawableSize: CGSize = .zero
}

/// The thread-safe half of ``MetalLayerView``. Frames run on one thread at a time (the frame thread): drawable
/// acquisition, the render pass descriptor, and the MSAA and depth attachments it owns.
internal final class MetalLayerSurface: @unchecked Sendable {
    private struct AttachmentKey: Equatable {
        var device: ObjectIdentifier?
        var width: Int
        var height: Int
        var sampleCount: Int
        var colorPixelFormat: MTLPixelFormat
        var depthStencilPixelFormat: MTLPixelFormat
        var depthStencilStorageMode: MTLStorageMode
        var depthStencilUsage: MTLTextureUsage.RawValue
        var multisampleColorUsage: MTLTextureUsage.RawValue
    }

    private final class WeakDelegate: @unchecked Sendable {
        weak var value: (any MetalLayerViewDelegate)?
    }

    // `nextDrawable()` is thread-safe; other layer properties are only written on the main thread.
    let layer: CAMetalLayer
    private let configurationStorage = Mutex(MetalSurfaceConfiguration())
    private let delegateStorage = Mutex(WeakDelegate())

    // Frame thread only.
    private var attachmentKey: AttachmentKey?
    private(set) var depthStencilTexture: (any MTLTexture)?
    private(set) var multisampleColorTexture: (any MTLTexture)?
    private var isRendering = false

    init(layer: CAMetalLayer) {
        self.layer = layer
    }

    var configuration: MetalSurfaceConfiguration {
        get { configurationStorage.withLock { $0 } }
        set { configurationStorage.withLock { $0 = newValue } }
    }

    func updateConfiguration(_ update: (inout MetalSurfaceConfiguration) -> Void) {
        configurationStorage.withLock { update(&$0) }
    }

    var delegate: (any MetalLayerViewDelegate)? {
        get { delegateStorage.withLock { $0.value } }
        set {
            let box = WeakDelegate()
            box.value = newValue
            delegateStorage.withLock { $0 = box }
        }
    }

    var drawableSize: CGSize { configuration.drawableSize }
    var sampleCount: Int { configuration.sampleCount }
    var residencySet: any MTLResidencySet { layer.residencySet }

    /// Calls the delegate's `render(on:)`. Frame thread only.
    func renderFrame() {
        guard !isRendering, let delegate else {
            return
        }
        isRendering = true
        defer { isRendering = false }
        // The render thread's run loop may not return between display link ticks, so drain per frame (#564).
        autoreleasepool {
            delegate.render(on: self)
        }
    }

    /// May block until a drawable is free.
    func nextDrawable() -> (any CAMetalDrawable)? {
        let size = drawableSize
        guard size.width > 0, size.height > 0 else {
            return nil
        }
        return layer.nextDrawable()
    }

    func renderPassDescriptor(for drawable: any CAMetalDrawable) -> MTL4RenderPassDescriptor {
        let configuration = configuration
        let drawableTexture = drawable.texture
        updateAttachments(configuration: configuration, width: drawableTexture.width, height: drawableTexture.height)
        let descriptor = MTL4RenderPassDescriptor()
        // swiftlint:disable:next force_unwrapping
        let color = descriptor.colorAttachments[0]!
        color.loadAction = .clear
        color.clearColor = configuration.clearColor
        if let multisampleColorTexture {
            color.texture = multisampleColorTexture
            color.resolveTexture = drawableTexture
            color.storeAction = .multisampleResolve
        } else {
            color.texture = drawableTexture
            color.storeAction = .store
        }
        if let depthStencilTexture {
            let format = configuration.depthStencilPixelFormat
            if format.hasDepth {
                descriptor.depthAttachment.texture = depthStencilTexture
                descriptor.depthAttachment.loadAction = .clear
                descriptor.depthAttachment.storeAction = .dontCare
                descriptor.depthAttachment.clearDepth = configuration.clearDepth
            }
            if format.hasStencil {
                descriptor.stencilAttachment.texture = depthStencilTexture
                descriptor.stencilAttachment.loadAction = .clear
                descriptor.stencilAttachment.storeAction = .dontCare
                descriptor.stencilAttachment.clearStencil = configuration.clearStencil
            }
        }
        return descriptor
    }

    // Sized from the drawable, not the configuration, so a resize between the two cannot mismatch them.
    private func updateAttachments(configuration: MetalSurfaceConfiguration, width: Int, height: Int) {
        let key = AttachmentKey(
            device: configuration.device.map { ObjectIdentifier($0) },
            width: width,
            height: height,
            sampleCount: configuration.sampleCount,
            colorPixelFormat: configuration.colorPixelFormat,
            depthStencilPixelFormat: configuration.depthStencilPixelFormat,
            depthStencilStorageMode: configuration.depthStencilStorageMode,
            depthStencilUsage: configuration.depthStencilAttachmentTextureUsage.rawValue,
            multisampleColorUsage: configuration.multisampleColorAttachmentTextureUsage.rawValue
        )
        guard key != attachmentKey else {
            return
        }
        attachmentKey = key
        multisampleColorTexture = nil
        depthStencilTexture = nil
        guard let device = configuration.device else {
            return
        }
        func descriptor(_ pixelFormat: MTLPixelFormat) -> MTLTextureDescriptor {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
            descriptor.textureType = key.sampleCount > 1 ? .type2DMultisample : .type2D
            descriptor.sampleCount = key.sampleCount
            return descriptor
        }
        if key.sampleCount > 1 {
            let colorDescriptor = descriptor(key.colorPixelFormat)
            colorDescriptor.usage = configuration.multisampleColorAttachmentTextureUsage
            colorDescriptor.storageMode = .private
            multisampleColorTexture = device.makeTexture(descriptor: colorDescriptor)
            multisampleColorTexture?.label = "MultisampleColor"
        }
        if key.depthStencilPixelFormat != .invalid {
            let depthDescriptor = descriptor(key.depthStencilPixelFormat)
            depthDescriptor.usage = configuration.depthStencilAttachmentTextureUsage
            depthDescriptor.storageMode = key.depthStencilStorageMode
            depthStencilTexture = device.makeTexture(descriptor: depthDescriptor)
            depthStencilTexture?.label = "DepthStencil"
        }
    }
}

// MARK: - MetalLayerView

/// A view backed by a `CAMetalLayer` that drives frames from a display link. It replaces MTKView in RenderView. Its
/// API follows MTKView's. With a ``RenderThread``, frames run on that thread instead of the main thread (#560).
@MainActor
internal final class MetalLayerView: PlatformView {
    // swiftlint:disable:next implicitly_unwrapped_optional
    private(set) var surface: MetalLayerSurface!

    /// Set before the view joins a window. `nil` renders on the main thread.
    var renderThread: RenderThread? {
        didSet {
            precondition(displayLink == nil, "Set renderThread before the display link starts.")
        }
    }

    var delegate: (any MetalLayerViewDelegate)? {
        get { surface.delegate }
        set { surface.delegate = newValue }
    }

    var device: (any MTLDevice)? {
        get { surface.configuration.device }
        set {
            guard newValue !== device else {
                return
            }
            metalLayer.device = newValue
            surface.updateConfiguration { $0.device = newValue }
        }
    }

    // MARK: Attachments

    var colorPixelFormat: MTLPixelFormat {
        get { surface.configuration.colorPixelFormat }
        set {
            metalLayer.pixelFormat = newValue
            surface.updateConfiguration { $0.colorPixelFormat = newValue }
        }
    }
    var depthStencilPixelFormat: MTLPixelFormat {
        get { surface.configuration.depthStencilPixelFormat }
        set { surface.updateConfiguration { $0.depthStencilPixelFormat = newValue } }
    }
    var depthStencilStorageMode: MTLStorageMode {
        get { surface.configuration.depthStencilStorageMode }
        set { surface.updateConfiguration { $0.depthStencilStorageMode = newValue } }
    }
    var depthStencilAttachmentTextureUsage: MTLTextureUsage {
        get { surface.configuration.depthStencilAttachmentTextureUsage }
        set { surface.updateConfiguration { $0.depthStencilAttachmentTextureUsage = newValue } }
    }
    var multisampleColorAttachmentTextureUsage: MTLTextureUsage {
        get { surface.configuration.multisampleColorAttachmentTextureUsage }
        set { surface.updateConfiguration { $0.multisampleColorAttachmentTextureUsage = newValue } }
    }
    var sampleCount: Int {
        get { surface.configuration.sampleCount }
        set { surface.updateConfiguration { $0.sampleCount = newValue } }
    }
    var clearColor: MTLClearColor {
        get { surface.configuration.clearColor }
        set { surface.updateConfiguration { $0.clearColor = newValue } }
    }
    var clearDepth: Double {
        get { surface.configuration.clearDepth }
        set { surface.updateConfiguration { $0.clearDepth = newValue } }
    }
    var clearStencil: UInt32 {
        get { surface.configuration.clearStencil }
        set { surface.updateConfiguration { $0.clearStencil = newValue } }
    }
    var framebufferOnly: Bool {
        get { metalLayer.framebufferOnly }
        set { metalLayer.framebufferOnly = newValue }
    }
    var presentsWithTransaction: Bool {
        get { metalLayer.presentsWithTransaction }
        set { metalLayer.presentsWithTransaction = newValue }
    }
    #if os(macOS)
    var colorspace: CGColorSpace? {
        get { metalLayer.colorspace }
        set { metalLayer.colorspace = newValue }
    }
    #endif

    /// Frame-thread state; read it only from the frame thread (tests use the main thread).
    var depthStencilTexture: (any MTLTexture)? { surface.depthStencilTexture }
    var multisampleColorTexture: (any MTLTexture)? { surface.multisampleColorTexture }

    // MARK: Draw loop

    var preferredFramesPerSecond = 60 {
        didSet { updateDisplayLink() }
    }
    var enableSetNeedsDisplay = false {
        didSet { updateDisplayLink() }
    }
    var isPaused = false {
        didSet { updateDisplayLink() }
    }
    var autoResizeDrawable = true {
        didSet {
            if autoResizeDrawable {
                updateDrawableSizeFromBounds()
            }
        }
    }

    var drawableSize: CGSize {
        get { metalLayer.drawableSize }
        set {
            guard metalLayer.drawableSize != newValue else {
                return
            }
            metalLayer.drawableSize = newValue
            surface.updateConfiguration { $0.drawableSize = newValue }
            delegate?.metalLayerView(self, drawableSizeWillChange: newValue)
        }
    }

    private var displayLink: CADisplayLink?

    var metalLayer: CAMetalLayer { surface.layer }

    // MARK: Init

    #if os(macOS)
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    #else
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    #endif

    convenience init(frame: CGRect, device: (any MTLDevice)?) {
        self.init(frame: frame)
        self.device = device
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // RenderView tears down in dismantle; this covers views released any other way (#565).
    isolated deinit {
        tearDown()
    }

    private func commonInit() {
        #if os(macOS)
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        #endif
        // swiftlint:disable:next force_cast
        surface = MetalLayerSurface(layer: layer as! CAMetalLayer)
        metalLayer.pixelFormat = colorPixelFormat
        metalLayer.framebufferOnly = true
        updateDrawableSizeFromBounds()
    }

    #if os(macOS)
    override func makeBackingLayer() -> CALayer {
        CAMetalLayer()
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        if enableSetNeedsDisplay {
            draw()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateDrawableSizeFromBounds()
        updateDisplayLink()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSizeFromBounds()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSizeFromBounds()
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
    }
    #else
    override static var layerClass: AnyClass {
        CAMetalLayer.self
    }

    override func display(_ layer: CALayer) {
        if enableSetNeedsDisplay {
            draw()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDrawableSizeFromBounds()
        updateDisplayLink()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateDrawableSizeFromBounds()
    }

    private var scale: CGFloat {
        // 0 before the view joins a window.
        traitCollection.displayScale > 0 ? traitCollection.displayScale : 1
    }
    #endif

    private func updateDrawableSizeFromBounds() {
        metalLayer.contentsScale = scale
        guard autoResizeDrawable else {
            return
        }
        let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        guard size.width > 0, size.height > 0 else {
            return
        }
        drawableSize = size
    }

    // MARK: Display link

    private func updateDisplayLink() {
        let wantsDisplayLink = window != nil && !enableSetNeedsDisplay
        if wantsDisplayLink, displayLink == nil {
            let target = DisplayLinkTarget(surface: surface)
            #if os(macOS)
            let link = displayLink(target: target, selector: #selector(DisplayLinkTarget.step(_:)))
            #else
            let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.step(_:)))
            #endif
            displayLink = link
            onFrameThread { link.add(to: .current, forMode: .common) }
        } else if !wantsDisplayLink {
            invalidateDisplayLink()
        }
        guard let displayLink else {
            return
        }
        let isPaused = isPaused
        let rate = Float(preferredFramesPerSecond)
        onFrameThread {
            displayLink.isPaused = isPaused
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: min(rate, 30), maximum: rate, preferred: rate)
        }
    }

    func invalidateDisplayLink() {
        guard let link = displayLink else {
            return
        }
        displayLink = nil
        onFrameThread { link.invalidate() }
    }

    /// Stops the display link and drops the delegate. With a render thread, the thread then finishes the delegate's
    /// work and exits without blocking the main thread. The delegate and `owner` are released on the render thread, so
    /// frame state is torn down where it lives (#566).
    func tearDown(releasing owner: AnyObject? = nil) {
        invalidateDisplayLink()
        let delegate = delegate
        self.delegate = nil
        guard let renderThread else {
            return
        }
        nonisolated(unsafe) let owner = owner
        renderThread.stop {
            delegate?.finishRendering()
            withExtendedLifetime(owner) { /* released when this block is, on the render thread */ }
        }
    }

    // A display link must be configured on the run loop thread that it is scheduled on.
    private func onFrameThread(_ work: @escaping () -> Void) {
        guard let renderThread else {
            work()
            return
        }
        nonisolated(unsafe) let work = work
        renderThread.perform { work() }
    }

    // MARK: Frame

    /// Renders a frame on the frame thread. Without a render thread it renders before returning.
    func draw() {
        guard let renderThread else {
            surface.renderFrame()
            return
        }
        renderThread.perform { [surface] in
            surface?.renderFrame()
        }
    }
}

/// Breaks the retain cycle between a display link and its view. Runs on the display link's run loop thread. The view
/// owns the surface, so a link that outlives its view stops itself (#565).
private final class DisplayLinkTarget: NSObject {
    weak var surface: MetalLayerSurface?

    init(surface: MetalLayerSurface) {
        self.surface = surface
    }

    @objc
    func step(_ link: CADisplayLink) {
        guard let surface else {
            link.invalidate()
            return
        }
        surface.renderFrame()
    }
}

private extension MTLPixelFormat {
    var hasDepth: Bool {
        switch self {
        case .depth16Unorm, .depth32Float, .depth32Float_stencil8:
            return true
        default:
            #if os(macOS)
            return self == .depth24Unorm_stencil8
            #else
            return false
            #endif
        }
    }

    var hasStencil: Bool {
        switch self {
        case .stencil8, .depth32Float_stencil8, .x32_stencil8:
            return true
        default:
            #if os(macOS)
            return self == .depth24Unorm_stencil8 || self == .x24_stencil8
            #else
            return false
            #endif
        }
    }
}
