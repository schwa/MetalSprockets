import GoldenImage
import Metal
@testable import MetalSprockets
import Testing

// swiftlint:disable identical_operands
// Equal operands are the point: separately built draws must compare equal.

// Closure-free draws compare by their arguments, so unchanged draws compare equal between frames (#522).
struct DataDrawTests {
    @Test func `data draws compare by value`() throws {
        #expect(Draw(.triangle, vertexCount: 3) == Draw(.triangle, vertexCount: 3))
        #expect(Draw(.triangle, vertexCount: 3) != Draw(.triangle, vertexCount: 6))
        #expect(Draw(.triangle, vertexCount: 3) != Draw(.triangle, vertexCount: 3, instanceCount: 2))
        #expect(isEqual(Draw(.triangle, vertexCount: 3), Draw(.triangle, vertexCount: 3)))
        let closure = Draw { _ in }
        #expect(closure != closure)
    }

    @Test func `indexed and indirect draws compare buffers by identity`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let buffer = try #require(device.makeBuffer(length: 64))
        let other = try #require(device.makeBuffer(length: 64))
        #expect(Draw(primitiveType: .triangle, indexBuffer: buffer, indexType: .uint16, indexCount: 3) == Draw(primitiveType: .triangle, indexBuffer: buffer, indexType: .uint16, indexCount: 3))
        #expect(Draw(primitiveType: .triangle, indexBuffer: buffer, indexType: .uint16, indexCount: 3) != Draw(primitiveType: .triangle, indexBuffer: other, indexType: .uint16, indexCount: 3))
        #expect(Draw(primitiveType: .triangle, indirectBuffer: buffer) == Draw(primitiveType: .triangle, indirectBuffer: buffer))
        #expect(Draw(primitiveType: .triangle, indirectBuffer: buffer) != Draw(primitiveType: .triangle, indirectBuffer: buffer, indirectBufferOffset: 16))
    }

    @Test(.requiresMetal4)
    @MainActor
    func `a data draw renders like the closure draw`() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct VertexIn { float2 position [[attribute(0)]]; };
        struct VertexOut { float4 position [[position]]; };
        [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
            VertexOut out;
            out.position = float4(in.position, 0.0, 1.0);
            return out;
        }
        [[fragment]] float4 fragment_main(VertexOut in [[stage_in]], constant float4 &color [[buffer(0)]]) {
            return color;
        }
        """
        let renderPass = try RenderPass {
            let vertexShader = try VertexShader(source: source)
            let fragmentShader = try FragmentShader(source: source)
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw(.triangle, vertexCount: 3)
                    .vertexValues(([[0, 0.75], [-0.75, -0.75], [0.75, -0.75]] as [SIMD2<Float>]), index: 0)
                    .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
            }
            .vertexDescriptor(vertexShader.inferredVertexDescriptor())
        }
        let texture = try OffscreenRenderer(size: CGSize(width: 1_600, height: 1_200)).render(renderPass)
        try Golden.verify(try texture.cgImage, named: "RedTriangle")
    }
}
