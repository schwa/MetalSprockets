import CoreGraphics
import Metal
import MetalSprockets
import MetalSprocketsSupport
import MetalSupport
import QuartzCore

// MARK: - FrameTimingState

internal struct FrameTimingState: Equatable {
    var firstFrameTime: CFTimeInterval = 0
    var frameTime: CFTimeInterval = 0
    var frame: Int = 0

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

    mutating func commit() {
        frame += 1
    }
}

// MARK: - Sample-count change detection

@inlinable
internal func sampleCountChanged(current: Int, observed: Int) -> Bool {
    current != observed
}

// MARK: - Root element construction

/// Wraps a frame's content with the view's render target, drawable and timing callback. The root submits the frame.
internal func buildRenderViewRootElement<Content: Element>( // swiftlint:disable:this function_parameter_count
    content: Content,
    captureConfiguration: RenderViewCaptureConfiguration?,
    device: MTLDevice,
    commandQueue: any MTL4CommandQueue,
    shaderStore: ShaderStore,
    renderPassDescriptor: MTL4RenderPassDescriptor,
    currentDrawable: CAMetalDrawable?,
    drawableSize: CGSize,
    onCompleted: @escaping @Sendable (SubmissionResult) -> Void
) throws -> some Element {
    try Group {
        content
    }
    .onCommandBufferCompleted(onCompleted)
    .capture(
        captureConfiguration?.enabled ?? false,
        target: captureConfiguration?.target ?? .device,
        destination: captureConfiguration?.destination ?? .developerTools,
        outputURL: captureConfiguration?.outputURL
    )
    .renderPassDescriptor(renderPassDescriptor)
    .renderPipelineDescriptor(MTL4RenderPipelineDescriptor())
    .currentDrawable(currentDrawable)
    .drawableSize(drawableSize)
    .shaderStore(shaderStore)
}
