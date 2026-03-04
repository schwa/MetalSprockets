import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsSupport
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
    var content: (RenderViewContext, CGSize) throws -> Content

    @Environment(\.self)
    private var environment

    @Environment(\.drawableSizeChange)
    private var drawableSizeChange

    @Environment(\.frameTimingChange)
    private var frameTimingChange

    @State
    private var viewModel: RenderViewViewModel<Content>

    init(device: MTLDevice, commandQueue: MTLCommandQueue, @ElementBuilder content: @escaping (RenderViewContext, CGSize) throws -> Content) {
        do {
            self.device = device
            self.viewModel = try RenderViewViewModel(device: device, commandQueue: commandQueue, content: content)
            self.content = content
        }
        catch {
            preconditionFailure("Failed to create RenderView.ViewModel: \(error)")
        }
    }

    var body: some View {
        ViewAdaptor<MTKView> {
            MTKView()
        }
        update: { view in
            #if os(macOS)
            view.layer?.isOpaque = false
            #else
            view.layer.isOpaque = false
            #endif
            view.device = device
            view.delegate = viewModel
            view.configure(from: environment)
            viewModel.content = content
            viewModel.drawableSizeChange = drawableSizeChange
            viewModel.frameTimingChange = frameTimingChange
        }
        //        .modifier(RenderViewDebugViewModifier<Content>())
        .environment(viewModel)
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

    @ObservationIgnored
    var system: System

    @ObservationIgnored
    var drawableSizeChange: ((CGSize) -> Void)?

    @ObservationIgnored
    var frameTimingChange: ((FrameTimingStatistics) -> Void)?

    @ObservationIgnored
    var signpostID = signposter?.makeSignpostID()

    var frame: Int = 0
    var firstFrameTime: CFTimeInterval = .zero
    var frameTime: CFTimeInterval = .zero

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

    init(device: MTLDevice, commandQueue: MTLCommandQueue, content: @escaping (RenderViewContext, CGSize) throws -> Content) throws {
        self.device = device
        self.content = content
        self.commandQueue = commandQueue
        self.system = System()
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
        if actualSampleCount != currentSampleCount {
            currentSampleCount = actualSampleCount
            // Mark all nodes as needing setup when sample count changes (MSAA toggle)
            system.markAllNodesNeedingSetup()
        }

        do {
            let currentFrame = self.frame
            let threadInfo = Thread.isMainThread ? "main thread" : "thread \(pthread_mach_thread_np(pthread_self()))"
            logger?.verbose?.info("Enter draw callback (frame #\(currentFrame), \(threadInfo))")
            defer {
                logger?.verbose?.info("Exit draw callback (frame #\(currentFrame))")
            }
            try withIntervalSignpost(signposter, name: "RenderViewViewModel.draw()", id: signpostID) {
                let currentDrawable = try view.currentDrawable.orThrow(.resourceCreationFailure("No drawable available"))
                defer {
                    currentDrawable.present()
                    frame += 1
                }
                let currentRenderPassDescriptor = try view.currentRenderPassDescriptor.orThrow(.resourceCreationFailure("No render pass descriptor available"))

                // Update context
                let currentTime: CFTimeInterval = CACurrentMediaTime()
                if firstFrameTime == 0 {
                    firstFrameTime = currentTime
                }
                let lastFrameTime = frameTime
                frameTime = currentTime - firstFrameTime
                let deltaTime = frameTime - lastFrameTime
                let frameUniforms = FrameUniforms(index: UInt32(frame), time: Float(frameTime), deltaTime: Float(deltaTime), viewportSize: [UInt32(view.drawableSize.width), UInt32(view.drawableSize.height)])
                frameTimingTracker.lastGPUTime = lastGPUTime
                let frameTimingStatistics = frameTimingTracker.recordFrame(timestamp: currentTime)
                let context = RenderViewContext(frameUniforms: frameUniforms, frameTimingStatistics: frameTimingStatistics)
                frameTimingChange?(frameTimingStatistics)

                // Return the element produced by the content builder
                let t0 = CACurrentMediaTime()
                nonisolated(unsafe) let viewModel = self
                let rootElement = try CommandBufferElement(completion: .commit) {
                    try Group {
                        try self.content(context, currentDrawableSize)
                    }
                    .onCommandBufferCompleted { commandBuffer in
                        let gpuTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
                        viewModel.lastGPUTime = gpuTime
                    }
                }
                .environment(\.device, device)
                .environment(\.commandQueue, commandQueue)
                .environment(\.renderPassDescriptor, currentRenderPassDescriptor)
                .environment(\.renderPipelineDescriptor, MTLRenderPipelineDescriptor())
                .environment(\.currentDrawable, currentDrawable)
                .environment(\.drawableSize, view.drawableSize)
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
                        let contentMs = (t1 - t0) * 1000
                        let updateMs = (t2 - t1) * 1000
                        let setupMs = (t3 - t2) * 1000
                        let workloadMs = (t4 - t3) * 1000
                        let totalMs = (t4 - t0) * 1000
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
        logger?.error("Error when drawing frame #\(self.frame): \(error)")
        if RenderViewDebugging.fatalErrorOnCatch {
            fatalError("Error when drawing #\(self.frame): \(error)")
        }
        lastError = error
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

    internal init(frameUniforms: FrameUniforms, frameTimingStatistics: FrameTimingStatistics) {
        self.frameUniforms = frameUniforms
        self.frameTimingStatistics = frameTimingStatistics
    }
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
