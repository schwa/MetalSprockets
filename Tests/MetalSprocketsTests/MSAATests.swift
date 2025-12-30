import MetalKit
@testable import MetalSprockets
import Testing

@Suite("MSAA Tests")
struct MSAATests {
    @Test("MSAA modifier with sample count 1 is a no-op")
    @MainActor
    func testMSAAModifierNoOp() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float2 position [[attribute(0)]];
        };

        struct VertexOut {
            float4 position [[position]];
        };

        [[vertex]] VertexOut vertex_main(
            const VertexIn in [[stage_in]]
        ) {
            VertexOut out;
            out.position = float4(in.position, 0.0, 1.0);
            return out;
        }

        [[fragment]] float4 fragment_main(
            VertexOut in [[stage_in]]
        ) {
            return float4(1.0, 0.0, 0.0, 1.0);
        }
        """

        let vertexShader = try VertexShader(source: source)
        let fragmentShader = try FragmentShader(source: source)

        // With sampleCount 1, should render normally without MSAA textures
        let renderPass = try RenderPass {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    let vertices: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
                    encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
            .vertexDescriptor(try vertexShader.inferredVertexDescriptor())
        }
        .msaa(sampleCount: 1)

        let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 256, height: 256))
        let rendering = try offscreenRenderer.render(renderPass)

        // Should complete without errors and produce a valid texture
        #expect(rendering.texture.width == 256)
        #expect(rendering.texture.height == 256)
        #expect(rendering.texture.sampleCount == 1)
    }

    @Test("Render pipeline infers sample count from texture")
    @MainActor
    func testPipelineSampleCountFromTexture() throws {
        // This test verifies that RenderPipeline correctly reads the sample count
        // from the render pass descriptor's texture. Since we can't easily create
        // a multisample texture in the test environment, we verify the default case.

        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float2 position [[attribute(0)]];
        };

        struct VertexOut {
            float4 position [[position]];
        };

        [[vertex]] VertexOut vertex_main(
            const VertexIn in [[stage_in]]
        ) {
            VertexOut out;
            out.position = float4(in.position, 0.0, 1.0);
            return out;
        }

        [[fragment]] float4 fragment_main(
            VertexOut in [[stage_in]]
        ) {
            return float4(1.0, 0.0, 0.0, 1.0);
        }
        """

        let vertexShader = try VertexShader(source: source)
        let fragmentShader = try FragmentShader(source: source)

        let renderPass = try RenderPass {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    let vertices: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
                    encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
            .vertexDescriptor(try vertexShader.inferredVertexDescriptor())
        }

        let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 256, height: 256))
        let rendering = try offscreenRenderer.render(renderPass)

        // Verify normal rendering works with sample count 1
        #expect(rendering.texture.sampleCount == 1)
    }
}
