import MetalKit
@testable import MetalSprockets
import Testing

@Suite("MSAA Tests")
struct MSAATests {
    @Test("MSAA modifier with sample count 1 is a no-op", .requiresMetal4)
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

        let renderPass = try RenderPass {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.75], [-0.75, -0.75], [0.75, -0.75]] as [SIMD2<Float>]), index: 0)
            }
            .vertexDescriptor(vertexShader.inferredVertexDescriptor())
        }
        .msaa(sampleCount: 1)

        let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 256, height: 256))
        let rendering = try offscreenRenderer.render(renderPass)

        #expect(rendering.texture.width == 256)
        #expect(rendering.texture.height == 256)
        #expect(rendering.texture.sampleCount == 1)
    }

    @Test("Render pipeline infers sample count from texture", .requiresMetal4)
    @MainActor
    func testPipelineSampleCountFromTexture() throws {
        // A multisample texture is impractical to build here, so this only covers the
        // sampleCount == 1 path.

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
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.75], [-0.75, -0.75], [0.75, -0.75]] as [SIMD2<Float>]), index: 0)
            }
            .vertexDescriptor(vertexShader.inferredVertexDescriptor())
        }

        let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 256, height: 256))
        let rendering = try offscreenRenderer.render(renderPass)

        #expect(rendering.texture.sampleCount == 1)
    }
}
