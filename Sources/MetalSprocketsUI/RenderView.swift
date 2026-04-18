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
    var drawableSizeChange: ((CGSize) -> Void)?

    @Entry
    var frameTimingChange: ((FrameTimingStatistics) -> Void)?

    @Entry
    internal var renderViewCapture: RenderViewCaptureConfiguration?
}

// MARK: - RenderViewCaptureConfiguration

internal struct RenderViewCaptureConfiguration: Equatable {
    var enabled: Bool
    var target: CaptureTarget
    var destination: MTLCaptureDestination
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
    func capture(
        _ enabled: Bool = true,
        target: CaptureTarget = .device,
        destination: MTLCaptureDestination = .developerTools
    ) -> some View {
        environment(\.renderViewCapture, RenderViewCaptureConfiguration(enabled: enabled, target: target, destination: destination))
    }
}

public extension View {
    func onDrawableSizeChange(perform action: @escaping (CGSize) -> Void) -> some View {
        environment(\.drawableSizeChange, action)
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
        environment(\.frameTimingChange, action)
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

    @Environment(\.device)
    var device

    @Environment(\.commandQueue)
    var commandQueue

    /// Creates a render view with the specified content.
    ///
    /// - Parameter content: A closure that returns the elements to render each frame.
    ///   Receives the render context and drawable size as parameters.
    public init(@ElementBuilder content: @escaping (RenderViewContext, CGSize) throws -> Content) {
        self.content = content
    }

    public var body: some View {
        let device = device ?? _MTLCreateSystemDefaultDevice()
        let commandQueue = commandQueue ?? device.makeCommandQueue().orFatalError(.resourceCreationFailure("Failed to create command queue."))
        RenderViewHelper(device: device, commandQueue: commandQueue, content: content)
    }
}

internal struct RenderViewHelper <Content>: View where Content: Element {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    var content: (RenderViewContext, CGSize) throws -> Content

    @Environment(\.self)
    private var environment

    @Environment(\.drawableSizeChange)
    private var drawableSizeChange

    @Environment(\.frameTimingChange)
    private var frameTimingChange

    @Environment(\.renderViewCapture)
    private var captureConfiguration

    /// Holder so we can lazily create the viewModel on first `update` without
    /// re-allocating per body eval. The box itself is allocated per body (cheap
    /// empty class), SwiftUI keeps the first, and the real viewModel is created
    /// at most once per live RenderView identity.
    @State
    private var viewModelBox = ViewModelBox<Content>()

    init(device: MTLDevice, commandQueue: MTLCommandQueue, @ElementBuilder content: @escaping (RenderViewContext, CGSize) throws -> Content) {
        self.device = device
        self.commandQueue = commandQueue
        self.content = content
    }

    var body: some View {
        ViewAdaptor<MTKView> {
            MTKView()
        }
        update: { view in
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
            view.configure(from: environment)
            viewModel.device = device
            viewModel.commandQueue = commandQueue
            viewModel.content = content
            viewModel.drawableSizeChange = drawableSizeChange
            viewModel.frameTimingChange = frameTimingChange
            viewModel.captureConfiguration = captureConfiguration
        }
        .onDisappear {
            viewModelBox.value = nil
        }
        //        .modifier(RenderViewDebugViewModifier<Content>())
    }
}

/// Cheap holder class for lazy viewModel creation in `RenderViewHelper`.
private final class ViewModelBox<Content: Element> {
    var value: RenderViewViewModel<Content>?
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
    /// doesn't pay for a `System()` each time.
    @ObservationIgnored
    private var _system: System?
    @ObservationIgnored
    var system: System {
        if let s = _system {
            return s
        }
        let s = System()
        _system = s
        return s
    }

    @ObservationIgnored
    var drawableSizeChange: ((CGSize) -> Void)?

    @ObservationIgnored
    var frameTimingChange: ((FrameTimingStatistics) -> Void)?

    @ObservationIgnored
    var captureConfiguration: RenderViewCaptureConfiguration?

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

    // Frame timing
    @ObservationIgnored
    var frameTimingTracker = FrameTimingTracker()

    /// GPU execution time from the most recently completed command buffer.
    /// Written asynchronously from the command buffer completion handler.
    @ObservationIgnored
    nonisolated(unsafe) var lastGPUTime: TimeInterval?

    @ObservationIgnored
    var currentSampleCount: Int = 1

    init(device: MTLDevice, commandQueue: MTLCommandQueue, content: @escaping (RenderViewContext, CGSize) throws -> Content) {
        self.device = device
        self.commandQueue = commandQueue
        self.content = content
        super.init()
        RenderViewViewModelAllocationTracker.shared.recordAllocation()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSizeChange?(size)
        // Mark all nodes as needing setup when drawable size changes
        system.markAllNodesNeedingSetup()
        self.currentDrawableSize = size
    }

    func draw(in view: MTKView) {
        // Check if sample count changed (MSAA toggle) by examining the actual texture
        let actualSampleCount = view.currentRenderPassDescriptor?.colorAttachments[0].texture?.sampleCount ?? 1
        if sampleCountChanged(current: currentSampleCount, observed: actualSampleCount) {
            currentSampleCount = actualSampleCount
            // Mark all nodes as needing setup when sample count changes (MSAA toggle)
            system.markAllNodesNeedingSetup()
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

                // Update context
                let currentTime: CFTimeInterval = CACurrentMediaTime()
                let frameUniforms = timingState.advance(
                    now: currentTime,
                    viewportSize: [UInt32(view.drawableSize.width), UInt32(view.drawableSize.height)]
                )
                frameTimingTracker.lastGPUTime = lastGPUTime
                let frameTimingStatistics = frameTimingTracker.recordFrame(timestamp: currentTime)
                let context = RenderViewContext(frameUniforms: frameUniforms, frameTimingStatistics: frameTimingStatistics)
                frameTimingChange?(frameTimingStatistics)

                // Return the element produced by the content builder
                let t0 = CACurrentMediaTime()
                let userContent = try self.content(context, currentDrawableSize)
                let rootElement = try buildRenderViewRootElement(
                    content: userContent,
                    captureConfiguration: self.captureConfiguration,
                    device: device,
                    commandQueue: commandQueue,
                    renderPassDescriptor: currentRenderPassDescriptor,
                    currentDrawable: currentDrawable,
                    drawableSize: view.drawableSize
                ) { [weak self] commandBuffer in
                    let gpuTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
                    self?.lastGPUTime = gpuTime
                }
                let t1 = CACurrentMediaTime()

                do {
                    try system.update(root: rootElement)
                    let t2 = CACurrentMediaTime()
                    // Process setup immediately after update
                    // Only nodes that need setup will be processed
                    try system.processSetup()
                    let t3 = CACurrentMediaTime()
                    try system.processWorkload()
                    let t4 = CACurrentMediaTime()

                    if RenderViewDebugging.logFrame {
                        let contentMs = (t1 - t0) * 1_000
                        let updateMs = (t2 - t1) * 1_000
                        let setupMs = (t3 - t2) * 1_000
                        let workloadMs = (t4 - t3) * 1_000
                        let totalMs = (t4 - t0) * 1_000
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
        if RenderViewDebugging.fatalErrorOnCatch {
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

public struct RenderViewDebugging {
    public static var logFrame: Bool {
        ProcessInfo.processInfo.renderViewLogFrameEnabled
    }

    public static var fatalErrorOnCatch: Bool {
        ProcessInfo.processInfo.fatalErrorOnThrow
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
