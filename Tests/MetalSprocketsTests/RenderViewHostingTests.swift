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
}
