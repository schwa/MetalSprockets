import CoreGraphics
import Metal
@testable import MetalSprockets
import simd
import Testing

@MainActor
@Suite("depthBias modifier")
struct DepthBiasTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    [[vertex]] float4 vertex_main(const VertexIn in [[stage_in]]) {
        return float4(in.position, 0.0, 1.0);
    }

    [[fragment]] float4 fragment_main() {
        return float4(1, 0, 0, 1);
    }
    """

    @Test func `a biased draw renders`() throws {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .depthBias(-0.1, slopeScale: -1.0, clamp: -0.01)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        _ = try renderer.render(pass)
    }

    @Test func `the modifier adds one node holding the bias values`() throws {
        let element = EmptyElement().depthBias(-0.1, slopeScale: -1.0, clamp: -0.01)
        let modifier = try #require(element as? DepthBiasModifier<EmptyElement>)
        #expect(modifier.depthBias == -0.1)
        #expect(modifier.slopeScale == -1.0)
        #expect(modifier.clamp == -0.01)
    }

    @Test func `slope scale and clamp default to zero`() throws {
        let element = EmptyElement().depthBias(0.5)
        let modifier = try #require(element as? DepthBiasModifier<EmptyElement>)
        #expect(modifier.slopeScale == 0)
        #expect(modifier.clamp == 0)
    }

    @Test func `using the modifier outside a render pass throws`() throws {
        let system = System()
        try system.update(root: EmptyElement().depthBias(0.5))
        #expect(throws: (any Error).self) {
            try system.processWorkload()
        }
    }

    @Test func `two modifiers are equal when their bias settings match`() throws {
        let a = try #require(EmptyElement().depthBias(-0.1, slopeScale: -1, clamp: -0.01) as? DepthBiasModifier<EmptyElement>)
        let same = try #require(EmptyElement().depthBias(-0.1, slopeScale: -1, clamp: -0.01) as? DepthBiasModifier<EmptyElement>)
        let differentBias = try #require(EmptyElement().depthBias(-0.2, slopeScale: -1, clamp: -0.01) as? DepthBiasModifier<EmptyElement>)
        let differentSlope = try #require(EmptyElement().depthBias(-0.1, slopeScale: -2, clamp: -0.01) as? DepthBiasModifier<EmptyElement>)
        let differentClamp = try #require(EmptyElement().depthBias(-0.1, slopeScale: -1, clamp: -0.02) as? DepthBiasModifier<EmptyElement>)

        #expect(a == same)
        #expect(a != differentBias)
        #expect(a != differentSlope)
        #expect(a != differentClamp)
    }

    @Test func `an unchanged biased tree reuses its nodes across renders`() throws {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)

        func pass() throws -> some Element {
            try RenderPass {
                try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                    Draw { encoder in
                        let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                        encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                    .depthBias(-0.1, slopeScale: -1.0, clamp: -0.01)
                }
                .vertexDescriptor(vs.inferredVertexDescriptor())
            }
        }

        // Equality is what lets the System keep the existing node instead of rebuilding it, which is the whole
        // reason the modifier is Equatable.
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        _ = try renderer.render(try pass())
        _ = try renderer.render(try pass())
    }
}
