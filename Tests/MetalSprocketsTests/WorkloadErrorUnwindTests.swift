import MetalKit
@testable import MetalSprockets
import simd
import Testing

private struct WorkloadTestError: Error {}

@Test
@MainActor
func testErrorThrownInsideRenderPassPropagates() throws {
    let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) {
        return float4(1, 0, 0, 1);
    }
    """

    let vertexShader = try VertexShader(source: source)
    let fragmentShader = try FragmentShader(source: source)
    let renderPass = try RenderPass {
        try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
            Draw { _ in
                throw WorkloadTestError()
            }
        }
        .vertexDescriptor(vertexShader.inferredVertexDescriptor())
    }
    let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
    #expect(throws: WorkloadTestError.self) {
        _ = try offscreenRenderer.render(renderPass)
    }
}
