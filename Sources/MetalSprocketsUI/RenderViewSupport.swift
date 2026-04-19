import CoreGraphics
import Metal
import MetalSprockets
import MetalSprocketsSupport
import MetalSupport
import QuartzCore

// MARK: - FrameTimingState

/// The mutable timing state maintained across frames by `RenderView`.
///
/// Isolated from `RenderViewViewModel` so the timing math can be unit-tested
/// without an MTKView or an active draw loop.
internal struct FrameTimingState: Equatable {
    /// The absolute host time (`CACurrentMediaTime`) of the first advance.
    /// Stays `0` until the first frame is recorded.
    var firstFrameTime: CFTimeInterval = 0

    /// The time of the previous advance, expressed as seconds since `firstFrameTime`.
    var frameTime: CFTimeInterval = 0

    /// The zero-based index of the next frame to be produced.
    var frame: Int = 0

    /// Advances timing state by one frame.
    ///
    /// - Parameters:
    ///   - now: The current host time, typically `CACurrentMediaTime()`.
    ///   - viewportSize: The current drawable size in pixels.
    /// - Returns: The ``FrameUniforms`` describing this frame.
    mutating func advance(now: CFTimeInterval, viewportSize: SIMD2<UInt32>) -> FrameUniforms {
        if firstFrameTime == 0 {
            firstFrameTime = now
        }
        let lastFrameTime = frameTime
        frameTime = now - firstFrameTime
        let deltaTime = frameTime - lastFrameTime
        return FrameUniforms(
            index: UInt32(frame),
            time: Float(frameTime),
            deltaTime: Float(deltaTime),
            viewportSize: viewportSize
        )
    }

    /// Call after a frame has been successfully committed.
    mutating func commit() {
        frame += 1
    }
}

// MARK: - Sample-count change detection

/// Returns `true` if `observed` differs from `current`; intended as a signal that
/// the `System` needs to mark nodes as needing setup (MSAA sample count changed).
@inlinable
internal func sampleCountChanged(current: Int, observed: Int) -> Bool {
    current != observed
}

// MARK: - Root element construction

/// Builds the root render element graph used by `RenderView` each frame.
///
/// Extracted out of `RenderViewViewModel.draw(in:)` so the element-tree construction
/// (and its environment wiring) can be unit-tested directly, without a live MTKView.
///
/// - Parameters:
///   - content: The user-supplied element produced by the `RenderView` content closure.
///   - captureConfiguration: Optional GPU-capture configuration from the `View.capture()` modifier.
///   - device: The Metal device to attach to the environment.
///   - commandQueue: The command queue to attach to the environment.
///   - renderPassDescriptor: The current render pass descriptor from the `MTKView`.
///   - currentDrawable: The current drawable from the `MTKView`.
///   - drawableSize: The drawable size.
///   - onCommandBufferCompleted: Invoked when the command buffer completes on the GPU.
internal func buildRenderViewRootElement<Content: Element>( // swiftlint:disable:this function_parameter_count
    content: Content,
    captureConfiguration: RenderViewCaptureConfiguration?,
    device: MTLDevice,
    commandQueue: MTLCommandQueue,
    renderPassDescriptor: MTLRenderPassDescriptor,
    currentDrawable: CAMetalDrawable?,
    drawableSize: CGSize,
    onCommandBufferCompleted: @escaping (MTLCommandBuffer) -> Void
) throws -> some Element {
    try CommandBufferElement(completion: .commit) {
        try Group {
            content
        }
        .onCommandBufferCompleted(onCommandBufferCompleted)
    }
    .capture(
        captureConfiguration?.enabled ?? false,
        target: captureConfiguration?.target ?? .device,
        destination: captureConfiguration?.destination ?? .developerTools
    )
    .environment(\.device, device)
    .environment(\.commandQueue, commandQueue)
    .environment(\.renderPassDescriptor, renderPassDescriptor)
    .environment(\.renderPipelineDescriptor, MTLRenderPipelineDescriptor())
    .environment(\.currentDrawable, currentDrawable)
    .environment(\.drawableSize, drawableSize)
}
