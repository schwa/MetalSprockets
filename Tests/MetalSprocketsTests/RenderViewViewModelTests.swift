import CoreGraphics
import Metal
import MetalKit
@testable import MetalSprockets
@testable import MetalSprocketsUI
import Testing

@MainActor
@Suite("RenderViewViewModel frame driving")
struct RenderViewViewModelTests {
    struct Failure: Error {
    }

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;

    [[vertex]] float4 vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(0, 0.5), float2(-0.5, -0.5), float2(0.5, -0.5) };
        return float4(positions[id], 0, 1);
    }

    [[fragment]] float4 fragment_main() {
        return float4(1, 0, 0, 1);
    }
    """

    private func makeView(device: MTLDevice) -> MTKView {
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: device)
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.framebufferOnly = false
        view.drawableSize = CGSize(width: 64, height: 64)
        return view
    }

    private func makeViewModel<Content: Element>(device: MTLDevice, content: @escaping (RenderViewContext, CGSize) throws -> Content) throws -> RenderViewViewModel<Content> {
        let commandQueue = try #require(device.makeCommandQueue())
        return RenderViewViewModel(device: device, commandQueue: commandQueue, content: content)
    }

    private func triangle() throws -> some Element {
        let vertexShader = try VertexShader(source: Self.source)
        let fragmentShader = try FragmentShader(source: Self.source)
        return try RenderPass {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
        }
    }

    @Test func `drawing a frame advances the frame counter and reports timing`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var reported: [FrameTimingStatistics] = []
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        viewModel.frameTimingChange = { reported.append($0) }
        view.delegate = viewModel

        #expect(viewModel.frame == 0)
        viewModel.draw(in: view)

        #expect(viewModel.frame == 1)
        #expect(reported.count == 1)
        #expect(viewModel.lastError == nil)
    }

    @Test func `successive frames reuse the system`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        view.delegate = viewModel

        viewModel.draw(in: view)
        let nodeCount = viewModel.frameRenderer.system.nodes.count
        viewModel.draw(in: view)

        #expect(viewModel.frame == 2)
        #expect(viewModel.frameRenderer.system.nodes.count == nodeCount)
        #expect(viewModel.lastError == nil)
    }

    @Test func `the content closure sees the drawable size`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var seenSizes: [CGSize] = []
        let viewModel = try makeViewModel(device: device) { _, size in
            seenSizes.append(size)
            return try triangle()
        }
        view.delegate = viewModel

        viewModel.draw(in: view)

        #expect(seenSizes == [CGSize(width: 64, height: 64)])
    }

    @Test func `a drawable size change marks every node for setup`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var reportedSizes: [CGSize] = []
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        viewModel.drawableSizeChange = { reportedSizes.append($0) }
        view.delegate = viewModel

        viewModel.draw(in: view)
        #expect(viewModel.frameRenderer.system.nodes.values.map(\.needsSetup).contains(true) == false)

        viewModel.mtkView(view, drawableSizeWillChange: CGSize(width: 128, height: 128))

        // The first draw also reports, because the delegate was attached after the view was already sized.
        #expect(reportedSizes == [CGSize(width: 64, height: 64), CGSize(width: 128, height: 128)])
        #expect(viewModel.currentDrawableSize == CGSize(width: 128, height: 128))
        #expect(viewModel.frameRenderer.system.nodes.values.map(\.needsSetup).contains(true))
    }

    @Test func `a size change noticed during draw is resynced`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var reportedSizes: [CGSize] = []
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        viewModel.drawableSizeChange = { reportedSizes.append($0) }
        view.delegate = viewModel

        // The delegate never got a drawableSizeWillChange call, so draw(in:) has to notice the mismatch itself.
        viewModel.draw(in: view)

        #expect(reportedSizes == [CGSize(width: 64, height: 64)])
        #expect(viewModel.currentDrawableSize == CGSize(width: 64, height: 64))
    }

    @Test func `an error thrown by the content closure is captured`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let viewModel: RenderViewViewModel<EmptyElement> = try makeViewModel(device: device) { _, _ in
            throw Failure()
        }
        view.delegate = viewModel

        viewModel.draw(in: view)

        #expect(viewModel.lastError is Failure)
    }

    @Test func `an error thrown during the frame leaves the view model usable`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var shouldThrow = true
        let viewModel = try makeViewModel(device: device) { _, _ -> AnyElement in
            if shouldThrow {
                throw Failure()
            }
            return try AnyElement(triangle())
        }
        view.delegate = viewModel

        viewModel.draw(in: view)
        #expect(viewModel.lastError is Failure)

        shouldThrow = false
        viewModel.draw(in: view)
        #expect(viewModel.frame == 2)
    }

    @Test func `sampleCountChanged reports only real changes`() {
        #expect(sampleCountChanged(current: 1, observed: 4))
        #expect(sampleCountChanged(current: 4, observed: 4) == false)
    }
}
