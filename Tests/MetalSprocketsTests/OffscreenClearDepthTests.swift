import CoreGraphics
import Metal
@testable import MetalSprockets
import Testing

@Suite("OffscreenRenderer clearDepth")
struct OffscreenClearDepthTests {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
        VertexOut out;
        out.position = float4(positions[id], 0.5, 1);
        return out;
    }
    [[fragment]] float4 fragment_main() { return float4(1, 0, 0, 1); }
    """

    /// A full-screen red triangle at depth 0.5 that passes where it is greater than the stored depth (reverse-Z);
    /// returns the center pixel (BGRA).
    private func render(clearDepth: Double?) throws -> [UInt8] {
        let library = try ShaderLibrary(source: Self.source)
        let size = CGSize(width: 8, height: 8)
        let renderer = try clearDepth.map { try OffscreenRenderer(size: size, clearDepth: $0) } ?? OffscreenRenderer(size: size)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: library.function(type: VertexShader.self, named: "vertex_main"), fragmentShader: library.function(type: FragmentShader.self, named: "fragment_main")) {
                Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
            }
            .depthCompare(function: .greater, enabled: true)
        }
        let texture = try renderer.render(pass).texture
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&pixel, bytesPerRow: 8 * 4, from: MTLRegionMake2D(4, 4, 1, 1), mipmapLevel: 0)
        return pixel
    }

    @Test("Clearing depth to 0 lets reverse-Z geometry pass; the default (1) does not", .requiresMetal4)
    func clearDepthSetsTheStartingDepth() throws {
        #expect(try render(clearDepth: 0) == [0, 0, 255, 255])
        #expect(try render(clearDepth: nil) == [0, 0, 0, 255])
    }
}
