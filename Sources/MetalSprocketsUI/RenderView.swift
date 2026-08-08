import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsSupport
import MetalSupport
import Observation
internal import os
import QuartzCore
import SwiftUI

public extension EnvironmentValues {
    @Entry
    var device: MTLDevice?

    @Entry
    var commandQueue: MTLCommandQueue?

    @Entry
    internal var drawableSizeChange: CallbackBox<CGSize>?

    @Entry
    internal var frameTimingChange: CallbackBox<FrameTimingStatistics>?

    @Entry
    var shaderStore: ShaderStore?

    @Entry
    internal var renderViewCapture: RenderViewCaptureConfiguration?

    // Three-state on purpose: nil means "not specified", so the process environment decides. See #269.
    // swiftlint:disable discouraged_optional_boolean
    @Entry
    internal var renderViewLogFrame: Bool?

    @Entry
    internal var renderViewFatalErrorOnError: Bool?
    // swiftlint:enable discouraged_optional_boolean
}

// MARK: - RenderViewDiagnostics

/// Resolved per-frame diagnostics settings for a ``RenderView``.
///
/// There used to be two independent sources of truth here: SwiftUI environment values for the `MTKView`
/// settings, and direct `SystemEnvironment` (i.e. `ProcessInfo`) reads for the debugging flags. Both now
/// flow through the SwiftUI environment, with the process environment supplying the defaults, so a view
/// can turn frame logging on for one `RenderView` without setting a variable for the whole process. See #269.
internal struct RenderViewDiagnostics: Equatable {
    var logFrame: Bool
    var fatalErrorOnError: Bool

    init(logFrame: Bool, fatalErrorOnError: Bool) {
        self.logFrame = logFrame
        self.fatalErrorOnError = fatalErrorOnError
    }

    /// Resolves the settings, preferring explicit SwiftUI environment values over the process environment.
    init(environment: EnvironmentValues, systemEnvironment: SystemEnvironment = .current) {
        self.logFrame = environment.renderViewLogFrame ?? systemEnvironment.renderViewLogFrameEnabled
        self.fatalErrorOnError = environment.renderViewFatalErrorOnError ?? systemEnvironment.fatalErrorOnThrow
    }
}

public extension View {
    /// Logs a per-frame timing breakdown for descendant ``RenderView``s.
    ///
    /// Defaults to whatever the `MS_RENDERVIEW_LOG_FRAME` environment variable says; this modifier overrides it.
    func renderViewLogFrame(_ enabled: Bool = true) -> some View {
        environment(\.renderViewLogFrame, enabled)
    }

    /// Turns errors thrown while drawing into a `fatalError` for descendant ``RenderView``s.
    ///
    /// Defaults to whatever the `MS_FATALERROR_ON_THROW` environment variable says; this modifier overrides it.
    func renderViewFatalErrorOnError(_ enabled: Bool = true) -> some View {
        environment(\.renderViewFatalErrorOnError, enabled)
    }
}

public extension View {
    /// Attaches a ``ShaderStore`` to descendant ``RenderView``s.
    ///
    /// When multiple `RenderView`s share the same store, they share compiled
    /// Metal libraries and specialized functions. The store also outlives any
    /// individual `RenderView`, so shaders survive view teardown/rebuild.
    ///
    /// ```swift
    /// @State var store = ShaderStore()
    ///
    /// var body: some View {
    ///     HStack {
    ///         RenderView { ... }
    ///         RenderView { ... }
    ///     }
    ///     .shaderStore(store)
    /// }
    /// ```
    ///
    /// If no store is attached, each ``RenderView`` creates a private one
    /// scoped to its own lifetime.
    func shaderStore(_ store: ShaderStore) -> some View {
        environment(\.shaderStore, store)
    }
}

// MARK: - RenderViewCaptureConfiguration

internal struct RenderViewCaptureConfiguration: Equatable {
    var enabled: Bool
    var target: CaptureTarget
    var destination: MTLCaptureDestination
    var outputURL: URL?
}

public extension View {
    /// Wraps each rendered frame in an `MTLCaptureManager` GPU frame capture scope.
    ///
    /// Mirrors ``MetalSprockets/Element/capture(_:target:destination:)`` but applies
    /// to everything rendered inside a ``RenderView``. A capture is started and stopped
    /// for every frame while enabled, so prefer ``MTLCaptureDestination/developerTools``
    /// (Xcode) and toggle the modifier off when you have what you need.
    ///
    /// ```swift
    /// RenderView { context, size in
    ///     // ...
    /// }
    /// .capture(shouldCapture)
    /// ```
    ///
    /// - Parameters:
    ///   - enabled: When `false`, the modifier is a no-op. Defaults to `true`.
    ///   - target: Whether to capture all work on the device or only on the
    ///     current command queue. Defaults to ``MetalSprockets/CaptureTarget/device``.
    ///   - destination: The capture destination. Defaults to `.developerTools`.
    ///   - outputURL: Where to write the `.gputrace` file. Required for
    ///     `.gpuTraceDocument`, ignored otherwise.
    func capture(
        _ enabled: Bool = true,
        target: CaptureTarget = .device,
        destination: MTLCaptureDestination = .developerTools,
        outputURL: URL? = nil
    ) -> some View {
        environment(\.renderViewCapture, RenderViewCaptureConfiguration(enabled: enabled, target: target, destination: destination, outputURL: outputURL))
    }
}

// MARK: - Callback plumbing

/// Identity-stable holder for a callback passed down the SwiftUI environment.
///
/// A closure stored directly in an `@Entry` cannot be compared, so SwiftUI treats the environment value as changed on
/// every update and invalidates every reader. A box created once per modifier instance (`@State`) keeps the
/// environment value's identity — and therefore its equality — stable while its contents are refreshed in place.
/// See #380.
@MainActor
internal final class CallbackBox<Value>: Equatable {
    var action: ((Value) -> Void)?

    func callAsFunction(_ value: Value) {
        action?(value)
    }

    nonisolated static func == (lhs: CallbackBox<Value>, rhs: CallbackBox<Value>) -> Bool {
        lhs === rhs
    }
}

/// Publishes `action` into the environment through an identity-stable ``CallbackBox``.
internal struct CallbackModifier<Value>: ViewModifier {
    var keyPath: WritableKeyPath<EnvironmentValues, CallbackBox<Value>?>
    var action: (Value) -> Void

    @State
    private var box = CallbackBox<Value>()

    func body(content: Content) -> some View {
        // Refreshing the box in place is deliberate: the box is not observable, so this does not invalidate anything,
        // and the environment value stays equal across updates.
        box.action = action
        return content.environment(keyPath, box)
    }
}

public extension View {
    func onDrawableSizeChange(perform action: @escaping (CGSize) -> Void) -> some View {
        modifier(CallbackModifier(keyPath: \.drawableSizeChange, action: action))
    }

    /// Registers a callback that is called every frame with the latest frame timing statistics.
    ///
    /// Use this to feed a ``FrameTimingView`` or log frame performance data.
    ///
    /// ```swift
    /// @State var statistics: FrameTimingStatistics?
    ///
    /// RenderView { context, size in
    ///     // ...
    /// }
    /// .onFrameTimingChange { statistics = $0 }
    /// ```
    func onFrameTimingChange(perform action: @escaping (FrameTimingStatistics) -> Void) -> some View {
        modifier(CallbackModifier(keyPath: \.frameTimingChange, action: action))
    }
}

// MARK: - RenderView

/// A SwiftUI view that hosts Metal rendering using MetalSprockets elements.
///
/// `RenderView` bridges SwiftUI and Metal, calling your content closure every frame
/// to build and execute the render graph.
///
/// ## Overview
///
/// Create a `RenderView` and return elements from the content closure:
///
/// ```swift
/// struct ContentView: View {
///     var body: some View {
///         RenderView { context, size in
///             try RenderPass {
///                 try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///                     Draw { encoder in
///                         // Issue draw commands
///                     }
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Context and Size
///
/// The content closure receives two parameters:
/// - `context`: Frame timing information via `context.frameUniforms`
/// - `size`: The current drawable size in pixels
///
/// ```swift
/// RenderView { context, size in
///     let time = context.frameUniforms.time
///     let aspect = Float(size.width / size.height)
///     // Use time and aspect for animations and projections
/// }
/// ```
///
/// ## Configuration
///
/// Use view modifiers to configure Metal settings:
///
/// ```swift
/// RenderView { context, size in
///     // ...
/// }
/// .metalDepthStencilPixelFormat(.depth32Float)
/// .metalColorPixelFormat(.bgra8Unorm_srgb)
/// ```
///
/// ## Topics
///
/// ### Related Types
/// - ``RenderViewContext``
/// - ``FrameUniforms``
public struct RenderView <Content>: View where Content: Element {
    var content: (RenderViewContext, CGSize) throws -> Content
    var colorPixelFormat: MTLPixelFormat?
    var depthStencilPixelFormat: MTLPixelFormat?
    var sampleCount: Int?

    @Environment(\.device)
    var device

    @Environment(\.commandQueue)
    var commandQueue

    /// Creates a render view with the specified content.
    ///
    /// - Parameters:
    ///   - colorPixelFormat: The pixel format of the color render target. When `nil` (the default) the
    ///     value from the environment (``SwiftUI/View/metalColorPixelFormat(_:)``) is used, falling back
    ///     to `MTKView`'s own default.
    ///   - depthStencilPixelFormat: The pixel format of the depth/stencil render target. Required for
    ///     depth testing. When `nil` (the default) the environment value is used.
    ///   - sampleCount: The number of samples used for MSAA. When `nil` (the default) the environment
    ///     value is used.
    ///   - content: A closure that returns the elements to render each frame.
    ///     Receives the render context and drawable size as parameters.
    ///
    /// Values passed here take precedence over the equivalent environment modifiers, so a `RenderView`
    /// that depends on a specific format cannot be broken by an ancestor view.
    public init(
        colorPixelFormat: MTLPixelFormat? = nil,
        depthStencilPixelFormat: MTLPixelFormat? = nil,
        sampleCount: Int? = nil,
        @ElementBuilder content: @escaping (RenderViewContext, CGSize) throws -> Content
    ) {
        self.content = content
        self.colorPixelFormat = colorPixelFormat
        self.depthStencilPixelFormat = depthStencilPixelFormat
        self.sampleCount = sampleCount
    }

    public var body: some View {
        // Device and command queue are resolved lazily inside MetalHostView's update
        // closure rather than here: creating them during body evaluation can happen while
        // a draw callback is in flight, which Metal warns about (#344).
        MetalHostView(
            device: device,
            commandQueue: commandQueue,
            overrides: MTKViewOverrides(
                colorPixelFormat: colorPixelFormat,
                depthStencilPixelFormat: depthStencilPixelFormat,
                sampleCount: sampleCount
            ),
            content: content
        )
    }
}

/// Per-``RenderView`` configuration that wins over the equivalent SwiftUI environment values.
internal struct MTKViewOverrides: Equatable {
    var colorPixelFormat: MTLPixelFormat?
    var depthStencilPixelFormat: MTLPixelFormat?
    var sampleCount: Int?

    /// Returns `environment` with each non-`nil` override applied.
    func applied(to environment: EnvironmentValues) -> EnvironmentValues {
        var environment = environment
        if let colorPixelFormat {
            environment.metalColorPixelFormat = colorPixelFormat
        }
        if let depthStencilPixelFormat {
            environment.metalDepthStencilPixelFormat = depthStencilPixelFormat
        }
        if let sampleCount {
            environment.metalSampleCount = sampleCount
        }
        return environment
    }
}

internal struct MetalHostView <Content>: View where Content: Element {
    var device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var overrides: MTKViewOverrides
    var content: (RenderViewContext, CGSize) throws -> Content

    @Environment(\.self)
    private var environment

    @Environment(\.drawableSizeChange)
    private var drawableSizeChange

    @Environment(\.frameTimingChange)
    private var frameTimingChange

    @Environment(\.shaderStore)
    private var shaderStore

    @Environment(\.renderViewCapture)
    private var captureConfiguration

    /// Holder so we can lazily create the viewModel on first `update` without
    /// re-allocating per body eval. The box itself is allocated per body (cheap
    /// empty class), SwiftUI keeps the first, and the real viewModel is created
    /// at most once per live RenderView identity.
    @State
    private var viewModelBox = ViewModelBox<Content>()

    init(device: MTLDevice?, commandQueue: MTLCommandQueue?, overrides: MTKViewOverrides = MTKViewOverrides(), @ElementBuilder content: @escaping (RenderViewContext, CGSize) throws -> Content) {
        self.device = device
        self.commandQueue = commandQueue
        self.overrides = overrides
        self.content = content
    }

    var body: some View {
        PlatformAdaptorView<MTKView> {
            MTKView()
        }
        update: { view in
            let device = viewModelBox.device(preferring: device)
            let commandQueue = viewModelBox.commandQueue(preferring: commandQueue, device: device)
            let viewModel: RenderViewViewModel<Content>
            if let existing = viewModelBox.value {
                viewModel = existing
            } else {
                viewModel = RenderViewViewModel(device: device, commandQueue: commandQueue, content: content)
                viewModelBox.value = viewModel
            }
            #if os(macOS)
            view.layer?.isOpaque = false
            #else
            view.layer.isOpaque = false
            #endif
            view.device = device
            view.delegate = viewModel
            view.configure(from: overrides.applied(to: environment))
            viewModel.device = device
            viewModel.commandQueue = commandQueue
            viewModel.content = content
            viewModel.drawableSizeChange = drawableSizeChange.map { box in { box($0) } }
            viewModel.frameTimingChange = frameTimingChange.map { box in { box($0) } }
            if viewModel.captureConfiguration != captureConfiguration {
                logger?.info("RenderView: capture configuration changed to \(String(describing: captureConfiguration))")
            }
            viewModel.captureConfiguration = captureConfiguration
            viewModel.shaderStore = shaderStore
            viewModel.diagnostics = RenderViewDiagnostics(environment: environment)
        }
        dismantle: { view in
            // Stop the display link and drop the delegate before SwiftUI releases the representable, so no draw
            // callback can arrive after the view model is gone. See #301.
            view.isPaused = true
            view.delegate = nil
        }
        .onDisappear {
            viewModelBox.value = nil
        }
    }
}

/// Cheap holder class for lazy viewModel, device and command queue creation in `MetalHostView`.
///
/// Internal rather than private so the caching behaviour that #337 depends on can be tested directly.
internal final class ViewModelBox<Content: Element> {
    var value: RenderViewViewModel<Content>?
    private var cachedDevice: MTLDevice?
    private var cachedCommandQueue: MTLCommandQueue?

    func device(preferring provided: MTLDevice?) -> MTLDevice {
        if let provided {
            return provided
        }
        if let cachedDevice {
            return cachedDevice
        }
        let device = _MTLCreateSystemDefaultDevice()
        cachedDevice = device
        return device
    }

    func commandQueue(preferring provided: MTLCommandQueue?, device: MTLDevice) -> MTLCommandQueue {
        if let provided {
            return provided
        }
        if let cachedCommandQueue {
            return cachedCommandQueue
        }
        let commandQueue = device.makeCommandQueue().orFatalError(.resourceCreationFailure("Failed to create command queue."))
        cachedCommandQueue = commandQueue
        return commandQueue
    }
}

@Observable
internal class RenderViewViewModel <Content>: NSObject, MTKViewDelegate where Content: Element {
    @ObservationIgnored
    var device: MTLDevice

    @ObservationIgnored
    var commandQueue: MTLCommandQueue

    @ObservationIgnored
    var content: (RenderViewContext, CGSize) throws -> Content

    var lastError: Error?

    /// Lazily created on first use. See #337 — keeping `init` cheap means
    /// SwiftUI's per-body churn of unused RenderViewViewModel instances
    /// doesn't pay for a `FrameRenderer` (and its `System`) each time.
    @ObservationIgnored
    private var _frameRenderer: FrameRenderer?
    @ObservationIgnored
    var frameRenderer: FrameRenderer {
        if let renderer = _frameRenderer {
            return renderer
        }
        let renderer = FrameRenderer()
        _frameRenderer = renderer
        return renderer
    }

    @ObservationIgnored
    var drawableSizeChange: ((CGSize) -> Void)?

    @ObservationIgnored
    var frameTimingChange: ((FrameTimingStatistics) -> Void)?

    @ObservationIgnored
    var captureConfiguration: RenderViewCaptureConfiguration?

    /// Ambient shader store from the SwiftUI environment, if any. When `nil`,
    /// the view model uses its private ``fallbackShaderStore`` so that shaders
    /// compiled inside this RenderView die with it.
    @ObservationIgnored
    var shaderStore: ShaderStore?

    /// Lazily created private store used when no ``ShaderStore`` is provided in
    /// the SwiftUI environment. Lifetime is tied to this view model so shaders
    /// cached here are freed when the RenderView goes away.
    @ObservationIgnored
    private let fallbackShaderStore = ShaderStore()

    /// Lazily created on first use (see #337).
    @ObservationIgnored
    private var _signpostID: OSSignpostID?
    @ObservationIgnored
    var signpostID: OSSignpostID? {
        if let id = _signpostID {
            return id
        }
        let id = signposter?.makeSignpostID()
        _signpostID = id
        return id
    }

    @ObservationIgnored
    var timingState = FrameTimingState()

    /// The zero-based index of the next frame to be produced.
    var frame: Int { timingState.frame }

    var currentDrawableSize: CGSize = .zero

    @ObservationIgnored
    var frameTimingTracker = FrameTimingTracker()

    @ObservationIgnored
    var currentSampleCount: Int = 1

    /// Diagnostics settings resolved from the SwiftUI environment and the process environment (#269).
    @ObservationIgnored
    var diagnostics = RenderViewDiagnostics(environment: EnvironmentValues())

    init(device: MTLDevice, commandQueue: MTLCommandQueue, content: @escaping (RenderViewContext, CGSize) throws -> Content) {
        self.device = device
        self.commandQueue = commandQueue
        self.content = content
        super.init()
        RenderViewViewModelAllocationTracker.shared.recordAllocation()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSizeChange?(size)
        frameRenderer.invalidateSetup()
        self.currentDrawableSize = size
    }

    func draw(in view: MTKView) {
        // MTKView only calls mtkView(_:drawableSizeWillChange:) when the size *changes*. If the
        // view was already sized before the delegate was attached (e.g. under a .toolbar layout
        // pass) we would keep rendering at .zero until the next resize. Re-sync defensively.
        if currentDrawableSize != view.drawableSize {
            currentDrawableSize = view.drawableSize
            drawableSizeChange?(view.drawableSize)
            frameRenderer.invalidateSetup()
        }

        // An MSAA toggle only shows up on the drawable's texture, not on any value MTKView reports.
        let actualSampleCount = view.currentRenderPassDescriptor?.colorAttachments[0].texture?.sampleCount ?? 1
        if sampleCountChanged(current: currentSampleCount, observed: actualSampleCount) {
            currentSampleCount = actualSampleCount
            frameRenderer.invalidateSetup()
        }

        do {
            let currentFrame = timingState.frame
            let threadInfo = Thread.isMainThread ? "main thread" : "thread \(pthread_mach_thread_np(pthread_self()))"
            logger?.verbose?.info("Enter draw callback (frame #\(currentFrame), \(threadInfo))")
            defer {
                logger?.verbose?.info("Exit draw callback (frame #\(currentFrame))")
            }
            try withIntervalSignpost(signposter, name: "RenderViewViewModel.draw()", id: signpostID) {
                let currentDrawable = try view.currentDrawable.orThrow(.resourceCreationFailure("No drawable available"))
                defer {
                    currentDrawable.present()
                    timingState.commit()
                }
                let currentRenderPassDescriptor = try view.currentRenderPassDescriptor.orThrow(.resourceCreationFailure("No render pass descriptor available"))

                let currentTime: CFTimeInterval = CACurrentMediaTime()
                let frameUniforms = timingState.advance(
                    now: currentTime,
                    viewportSize: [UInt32(view.drawableSize.width), UInt32(view.drawableSize.height)]
                )
                frameTimingTracker.lastGPUTime = frameRenderer.lastGPUTime
                let frameTimingStatistics = frameTimingTracker.recordFrame(timestamp: currentTime)
                let context = RenderViewContext(frameUniforms: frameUniforms, frameTimingStatistics: frameTimingStatistics)
                frameTimingChange?(frameTimingStatistics)

                let t0 = CACurrentMediaTime()
                let userContent = try self.content(context, currentDrawableSize)
                let rootElement = try buildRenderViewRootElement(
                    content: userContent,
                    captureConfiguration: self.captureConfiguration,
                    device: device,
                    commandQueue: commandQueue,
                    shaderStore: shaderStore ?? fallbackShaderStore,
                    renderPassDescriptor: currentRenderPassDescriptor,
                    currentDrawable: currentDrawable,
                    drawableSize: view.drawableSize
                ) { [frameRenderer] commandBuffer in
                    frameRenderer.lastGPUTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
                }
                let contentDuration = CACurrentMediaTime() - t0

                do {
                    let timings = try frameRenderer.renderFrame(root: rootElement)

                    if diagnostics.logFrame {
                        let contentMs = contentDuration * 1_000
                        let updateMs = timings.update * 1_000
                        let setupMs = timings.setup * 1_000
                        let workloadMs = timings.workload * 1_000
                        let totalMs = (contentDuration + timings.total) * 1_000
                        logger?.info("RenderView.draw: content=\(contentMs.formatted(.number.precision(.fractionLength(1))))ms update=\(updateMs.formatted(.number.precision(.fractionLength(1))))ms setup=\(setupMs.formatted(.number.precision(.fractionLength(1))))ms workload=\(workloadMs.formatted(.number.precision(.fractionLength(1))))ms total=\(totalMs.formatted(.number.precision(.fractionLength(1))))ms fps=\(frameTimingStatistics.currentFPS.formatted(.number.precision(.fractionLength(1))))")
                    }
                } catch {
                    handle(error: error)
                }
            }
        } catch {
            handle(error: error)
        }
    }

    @MainActor
    func handle(error: Error) {
        logger?.error("Error when drawing frame #\(self.timingState.frame): \(error)")
        if diagnostics.fatalErrorOnError {
            fatalError("Error when drawing #\(self.timingState.frame): \(error)")
        }
        lastError = error
    }
}

// MARK: - Allocation tracking

/// Tracks `RenderViewViewModel` allocations to catch regressions of per-frame churn
/// (see issues #298 / #299). Intentionally always-on; cost is one atomic increment
/// and a dictionary lookup per allocation.
internal final class RenderViewViewModelAllocationTracker: @unchecked Sendable {
    static let shared = RenderViewViewModelAllocationTracker()

    /// First warn after this many allocations. 1 is normal, 2 can happen across
    /// disappear/reappear, 3+ suggests per-body churn has regressed.
    private let warnThreshold = 3
    /// After the first warning, warn again every `warnInterval` additional allocations.
    private let warnInterval = 10

    private let lock = OSAllocatedUnfairLock(initialState: [String: Int]())

    func recordAllocation() {
        let count = lock.withLock { counts -> Int in
            let next = (counts["RenderViewViewModel"] ?? 0) + 1
            counts["RenderViewViewModel"] = next
            return next
        }
        if count == warnThreshold || (count > warnThreshold && (count - warnThreshold).isMultiple(of: warnInterval)) {
            logger?.warning("RenderViewViewModel has been allocated \(count) times. This may indicate per-frame allocation churn (regression of #298). See #299/#337.")
        }
    }

    /// Current allocation count. Intended for tests/diagnostics.
    var allocationCount: Int {
        lock.withLock { $0["RenderViewViewModel"] ?? 0 }
    }
}

/// Process-wide defaults for ``RenderView`` diagnostics.
///
/// These are the fallbacks used when a view has not set the equivalent environment value with
/// ``SwiftUI/View/renderViewLogFrame(_:)`` or ``SwiftUI/View/renderViewFatalErrorOnError(_:)``.
public enum RenderViewDebugging {
    public static var logFrame: Bool {
        SystemEnvironment.current.renderViewLogFrameEnabled
    }

    public static var fatalErrorOnCatch: Bool {
        SystemEnvironment.current.fatalErrorOnThrow
    }
}

// MARK: - RenderViewContext

/// Context information passed to the render view's content closure each frame.
///
/// Access frame timing and other per-frame information through this type.
///
/// ## Example
///
/// ```swift
/// RenderView { context, size in
///     let time = context.frameUniforms.time
///     let rotation = time * 0.5  // Rotate half a radian per second
///     // Use rotation in your rendering...
/// }
/// ```
public struct RenderViewContext {
    /// Per-frame timing and viewport information.
    public private(set) var frameUniforms: FrameUniforms

    /// Frame timing statistics computed over a rolling window.
    public private(set) var frameTimingStatistics: FrameTimingStatistics
}

// MARK: - FrameUniforms

/// Per-frame timing and viewport information.
///
/// This struct contains values that change each frame, useful for animations
/// and time-based effects.
///
/// ## Properties
///
/// - `index`: The zero-based frame number
/// - `time`: Elapsed time in seconds since rendering started
/// - `deltaTime`: Time in seconds since the previous frame
/// - `viewportSize`: The drawable size in pixels
///
/// ## Example
///
/// Pass frame uniforms to shaders:
///
/// ```swift
/// Draw { encoder in
///     var uniforms = context.frameUniforms
///     encoder.setFragmentBytes(&uniforms.time, length: MemoryLayout<Float>.stride, index: 0)
/// }
/// ```
public struct FrameUniforms: Equatable, Sendable {
    /// The zero-based frame number, incrementing each frame.
    public var index: UInt32

    /// Elapsed time in seconds since rendering started.
    public var time: Float

    /// Time in seconds since the previous frame (useful for frame-rate independent animation).
    public var deltaTime: Float

    /// The drawable size in pixels as `[width, height]`.
    public var viewportSize: SIMD2<UInt32>

    /// Creates frame uniforms with the specified values.
    public init(index: UInt32, time: Float, deltaTime: Float, viewportSize: SIMD2<UInt32>) {
        self.index = index
        self.time = time
        self.deltaTime = deltaTime
        self.viewportSize = viewportSize
    }
}
