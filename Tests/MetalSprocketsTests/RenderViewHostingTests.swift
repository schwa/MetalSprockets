import CoreGraphics
import Metal
import MetalKit
@testable import MetalSprockets
@testable import MetalSprocketsUI
import SwiftUI
import Testing
import ViewInspector

@MainActor
@Suite("RenderView hosting")
struct RenderViewHostingTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn { float2 position [[attribute(0)]]; };

    [[vertex]] float4 vertex_main(const VertexIn in [[stage_in]]) {
        return float4(in.position, 0, 1);
    }

    [[fragment]] float4 fragment_main() {
        return float4(0, 1, 0, 1);
    }
    """

    private func triangleView() throws -> some View {
        let vertexShader = try VertexShader(source: Self.source)
        let fragmentShader = try FragmentShader(source: Self.source)
        return RenderView { _, _ in
            try RenderPass {
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                    Draw { encoder in
                        let vertices: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                        encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                }
                .vertexDescriptor(vertexShader.inferredVertexDescriptor())
            }
        }
        .metalDepthStencilPixelFormat(.depth32Float)
    }

    @Test func `hosting a RenderView builds and configures its MTKView`() throws {
        let view = try triangleView()
        ViewHosting.host(view: view, size: CGSize(width: 64, height: 64))
        defer { ViewHosting.expel() }

        // Hosting instantiates the representable, which is what makes and configures the MTKView.
        #expect(RenderViewViewModelAllocationTracker.shared.allocationCount > 0)
    }

    @Test func `an attached shader store is visible in the environment`() throws {
        let store = ShaderStore()
        let view = try triangleView().shaderStore(store)
        #expect(try view.inspect().environment(\.shaderStore) === store)
    }

    @Test func `a supplied device and command queue are used instead of the defaults`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())

        // Supplying both means the lazy fallbacks are never consulted.
        let box = ViewModelBox<EmptyElement>()
        #expect(box.device(preferring: device) === device)
        #expect(box.commandQueue(preferring: commandQueue, device: device) === commandQueue)
    }

    @Test func `the lazily made device and command queue are cached`() throws {
        let box = ViewModelBox<EmptyElement>()

        let device = box.device(preferring: nil)
        #expect(box.device(preferring: nil) === device)

        let commandQueue = box.commandQueue(preferring: nil, device: device)
        #expect(box.commandQueue(preferring: nil, device: device) === commandQueue)
    }

    @Test func `changing the capture configuration is reported`() throws {
        let view = try triangleView().capture(true, target: .commandQueue, destination: .developerTools)
        ViewHosting.host(view: view, size: CGSize(width: 64, height: 64))
        defer { ViewHosting.expel() }

        #expect(try view.inspect().environment(\.renderViewCapture)?.enabled == true)
    }
}
