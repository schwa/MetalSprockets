import Metal
import QuartzCore
import SwiftUI

#if os(macOS)
import AppKit
internal typealias PlatformView = NSView
#else
import UIKit
internal typealias PlatformView = UIView
#endif

@MainActor
internal protocol MetalLayerViewDelegate: AnyObject {
    func metalLayerView(_ view: MetalLayerView, drawableSizeWillChange size: CGSize)
    func draw(in view: MetalLayerView)
}

/// A view backed by a `CAMetalLayer` that drives frames from a display link and owns the frame's MSAA and depth
/// attachments. It replaces MTKView in RenderView. Its API follows MTKView's.
@MainActor
internal final class MetalLayerView: PlatformView {
    weak var delegate: (any MetalLayerViewDelegate)?

    var device: (any MTLDevice)? {
        didSet {
            guard device !== oldValue else {
                return
            }
            metalLayer.device = device
            releaseAttachments()
        }
    }

    // MARK: Attachments

    var colorPixelFormat: MTLPixelFormat = .bgra8Unorm {
        didSet {
            metalLayer.pixelFormat = colorPixelFormat
            multisampleColorTexture = nil
        }
    }
    var depthStencilPixelFormat: MTLPixelFormat = .invalid {
        didSet { depthStencilTexture = nil }
    }
    var depthStencilStorageMode: MTLStorageMode = .private {
        didSet { depthStencilTexture = nil }
    }
    var depthStencilAttachmentTextureUsage: MTLTextureUsage = .renderTarget {
        didSet { depthStencilTexture = nil }
    }
    var multisampleColorAttachmentTextureUsage: MTLTextureUsage = .renderTarget {
        didSet { multisampleColorTexture = nil }
    }
    var sampleCount = 1 {
        didSet { releaseAttachments() }
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

    var clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    var clearDepth: Double = 1
    var clearStencil: UInt32 = 0

    private(set) var depthStencilTexture: (any MTLTexture)?
    private(set) var multisampleColorTexture: (any MTLTexture)?

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
            releaseAttachments()
            delegate?.metalLayerView(self, drawableSizeWillChange: newValue)
        }
    }

    // Valid only inside `draw()`; both are released when the delegate returns.
    private var frameDrawable: (any CAMetalDrawable)?
    private var frameRenderPassDescriptor: MTL4RenderPassDescriptor?
    private var isDrawing = false

    private var displayLink: CADisplayLink?

    var metalLayer: CAMetalLayer {
        // swiftlint:disable:next force_cast
        layer as! CAMetalLayer
    }

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
        metalLayer.device = device
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func commonInit() {
        #if os(macOS)
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        #endif
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
            let target = DisplayLinkTarget(view: self)
            #if os(macOS)
            let link = displayLink(target: target, selector: #selector(DisplayLinkTarget.step(_:)))
            #else
            let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.step(_:)))
            #endif
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else if !wantsDisplayLink, let link = displayLink {
            link.invalidate()
            displayLink = nil
        }
        guard let displayLink else {
            return
        }
        displayLink.isPaused = isPaused
        let rate = Float(preferredFramesPerSecond)
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: min(rate, 30), maximum: rate, preferred: rate)
    }

    func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: Frame

    /// Calls the delegate's `draw(in:)`. The drawable and render pass descriptor are valid only during the call.
    func draw() {
        guard !isDrawing else {
            return
        }
        isDrawing = true
        defer {
            isDrawing = false
            frameDrawable = nil
            frameRenderPassDescriptor = nil
        }
        delegate?.draw(in: self)
    }

    var currentDrawable: (any CAMetalDrawable)? {
        if let frameDrawable {
            return frameDrawable
        }
        guard isDrawing, drawableSize.width > 0, drawableSize.height > 0 else {
            return nil
        }
        frameDrawable = metalLayer.nextDrawable()
        return frameDrawable
    }

    var currentMTL4RenderPassDescriptor: MTL4RenderPassDescriptor? {
        if let frameRenderPassDescriptor {
            return frameRenderPassDescriptor
        }
        guard let drawable = currentDrawable else {
            return nil
        }
        let descriptor = makeRenderPassDescriptor(drawableTexture: drawable.texture)
        frameRenderPassDescriptor = descriptor
        return descriptor
    }

    private func makeRenderPassDescriptor(drawableTexture: any MTLTexture) -> MTL4RenderPassDescriptor {
        let descriptor = MTL4RenderPassDescriptor()
        // swiftlint:disable:next force_unwrapping
        let color = descriptor.colorAttachments[0]!
        color.loadAction = .clear
        color.clearColor = clearColor
        if sampleCount > 1, let multisample = makeMultisampleColorTextureIfNeeded() {
            color.texture = multisample
            color.resolveTexture = drawableTexture
            color.storeAction = .multisampleResolve
        } else {
            color.texture = drawableTexture
            color.storeAction = .store
        }
        if let depthStencil = makeDepthStencilTextureIfNeeded() {
            if depthStencilPixelFormat.hasDepth {
                descriptor.depthAttachment.texture = depthStencil
                descriptor.depthAttachment.loadAction = .clear
                descriptor.depthAttachment.storeAction = .dontCare
                descriptor.depthAttachment.clearDepth = clearDepth
            }
            if depthStencilPixelFormat.hasStencil {
                descriptor.stencilAttachment.texture = depthStencil
                descriptor.stencilAttachment.loadAction = .clear
                descriptor.stencilAttachment.storeAction = .dontCare
                descriptor.stencilAttachment.clearStencil = clearStencil
            }
        }
        return descriptor
    }

    private func makeMultisampleColorTextureIfNeeded() -> (any MTLTexture)? {
        if let multisampleColorTexture {
            return multisampleColorTexture
        }
        guard let device else {
            return nil
        }
        let descriptor = attachmentDescriptor(pixelFormat: colorPixelFormat)
        descriptor.usage = multisampleColorAttachmentTextureUsage
        descriptor.storageMode = .private
        multisampleColorTexture = device.makeTexture(descriptor: descriptor)
        multisampleColorTexture?.label = "MultisampleColor"
        return multisampleColorTexture
    }

    private func makeDepthStencilTextureIfNeeded() -> (any MTLTexture)? {
        guard depthStencilPixelFormat != .invalid else {
            return nil
        }
        if let depthStencilTexture {
            return depthStencilTexture
        }
        guard let device else {
            return nil
        }
        let descriptor = attachmentDescriptor(pixelFormat: depthStencilPixelFormat)
        descriptor.usage = depthStencilAttachmentTextureUsage
        descriptor.storageMode = depthStencilStorageMode
        depthStencilTexture = device.makeTexture(descriptor: descriptor)
        depthStencilTexture?.label = "DepthStencil"
        return depthStencilTexture
    }

    private func attachmentDescriptor(pixelFormat: MTLPixelFormat) -> MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
        descriptor.textureType = sampleCount > 1 ? .type2DMultisample : .type2D
        descriptor.sampleCount = sampleCount
        return descriptor
    }

    private func releaseAttachments() {
        depthStencilTexture = nil
        multisampleColorTexture = nil
    }
}

/// Breaks the retain cycle between a display link and its view.
private final class DisplayLinkTarget: NSObject {
    weak var view: MetalLayerView?

    init(view: MetalLayerView) {
        self.view = view
    }

    @MainActor
    @objc
    func step(_ link: CADisplayLink) {
        guard let view else {
            link.invalidate()
            return
        }
        view.draw()
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
