import CoreGraphics
import Foundation
import Metal
@testable import MetalSprockets
@testable import MetalSprocketsUI
import Synchronization
import Testing

@MainActor
@Suite("RenderView render thread (#560)", .requiresMetal4)
struct RenderThreadTests {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    [[vertex]] float4 vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(0, 0.5), float2(-0.5, -0.5), float2(0.5, -0.5) };
        return float4(positions[id], 0, 1);
    }
    [[fragment]] float4 fragment_main() { return float4(1, 0, 0, 1); }
    """

    @Test(.timeLimit(.minutes(1)))
    func `frames run on the render thread and report back on the main thread`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeMTL4CommandQueue())
        let view = MetalLayerView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: device)
        view.enableSetNeedsDisplay = true
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = 4
        view.drawableSize = CGSize(width: 64, height: 64)
        view.renderThread = RenderThread()

        let contentThreads = Mutex<[Bool]>([])
        let vertexShader = try VertexShader(source: Self.source)
        let fragmentShader = try FragmentShader(source: Self.source)
        nonisolated(unsafe) let shaders = (vertexShader, fragmentShader)
        let viewModel = RenderViewViewModel(device: device, commandQueue: commandQueue, rendersOffMainThread: true) { @Sendable _, _ in
            contentThreads.withLock { $0.append(Thread.isMainThread) }
            return try RenderPass {
                try RenderPipeline(vertexShader: shaders.0, fragmentShader: shaders.1) {
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                }
            }
        }
        var timingCallbacksOnMain: [Bool] = []
        var sizes: [CGSize] = []
        viewModel.frameTimingChange = { _ in timingCallbacksOnMain.append(Thread.isMainThread) }
        viewModel.drawableSizeChange = { sizes.append($0) }
        view.delegate = viewModel

        let frameCount = 10
        for _ in 0..<frameCount {
            view.draw()
        }
        // Waits for the render thread to finish its queue, then for main-thread callbacks it scheduled.
        await withCheckedContinuation { continuation in
            view.renderThread?.perform {
                DispatchQueue.main.async { continuation.resume() }
            }
        }

        #expect(viewModel.lastError == nil)
        #expect(contentThreads.withLock { $0 } == Array(repeating: false, count: frameCount))
        #expect(!timingCallbacksOnMain.isEmpty)
        // #expect cannot infer a key path root here.
        // swiftlint:disable:next prefer_key_path
        #expect(timingCallbacksOnMain.allSatisfy { $0 })
        #expect(sizes == [CGSize(width: 64, height: 64)])

        view.drawableSize = CGSize(width: 96, height: 48)
        view.draw()
        await withCheckedContinuation { continuation in
            view.renderThread?.perform {
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        #expect(viewModel.lastError == nil)
        #expect(sizes == [CGSize(width: 64, height: 64), CGSize(width: 96, height: 48)])

        view.tearDown()
    }
}
