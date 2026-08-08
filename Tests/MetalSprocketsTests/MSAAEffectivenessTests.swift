import CoreGraphics
import MetalKit
@testable import MetalSprockets
import MetalSprocketsSupport
import simd
import Testing

@Suite("MSAA effectiveness")
@MainActor
struct MSAAEffectivenessTests {
    static let source = """
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
        return float4(1.0, 0.0, 0.0, 1.0);
    }
    """

    /// A triangle with a strongly diagonal edge, so aliasing is obvious.
    static func triangle(scale: Float) -> [SIMD2<Float>] {
        [[0, 0.9 * scale], [-0.9 * scale, -0.9 * scale], [0.9 * scale, -0.5 * scale]]
    }

    static func makePass(scale: Float, sampleCount: Int?) throws -> some Element {
        let vertexShader = try VertexShader(source: source)
        let fragmentShader = try FragmentShader(source: source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    let vertices = triangle(scale: scale)
                    encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * vertices.count, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
                }
            }
            .vertexDescriptor(vertexShader.inferredVertexDescriptor())
        }
        guard let sampleCount else {
            return AnyElement(pass)
        }
        return AnyElement(pass.msaa(sampleCount: sampleCount))
    }

    static func render(scale: Float, sampleCount: Int?, renderer: OffscreenRenderer? = nil) throws -> [UInt8] {
        let renderer = try renderer ?? OffscreenRenderer(size: CGSize(width: 256, height: 256))
        let rendering = try renderer.render(makePass(scale: scale, sampleCount: sampleCount))
        let image = try rendering.cgImage
        let data = try #require(image.dataProvider?.data) as Data
        return [UInt8](data)
    }

    /// Counts pixels that are neither fully background nor fully triangle colour.
    static func partialCoverageCount(_ pixels: [UInt8]) -> Int {
        stride(from: 0, to: pixels.count, by: 4).count { index in
            let red = pixels[index + 2]
            return red > 8 && red < 240
        }
    }

    @Test("MSAA actually anti-aliases")
    func testMSAADiffersFromAliased() throws {
        let aliased = try Self.render(scale: 1, sampleCount: nil)
        let multisampled = try Self.render(scale: 1, sampleCount: 4)
        #expect(aliased.count == multisampled.count)
        #expect(aliased != multisampled)
        // Anti-aliased edges produce partially-covered pixels; a hard aliased edge has almost none.
        #expect(Self.partialCoverageCount(multisampled) > Self.partialCoverageCount(aliased) * 10)
    }

    @Test("MSAA keeps working after the first frame")
    func testMSAASecondFrameUpdates() throws {
        let renderer = try OffscreenRenderer(size: CGSize(width: 256, height: 256))
        let frame1 = try Self.render(scale: 1, sampleCount: 4, renderer: renderer)
        let frame2 = try Self.render(scale: 0.4, sampleCount: 4, renderer: renderer)
        #expect(frame1 != frame2)
    }

    @Test("A misplaced msaa modifier is reported")
    func testMisplacedMSAAThrows() throws {
        let vertexShader = try VertexShader(source: Self.source)
        let fragmentShader = try FragmentShader(source: Self.source)
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        #expect(throws: MetalSprocketsError.self) {
            let pass = try RenderPass {
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                    Draw { encoder in
                        let vertices = Self.triangle(scale: 1)
                        encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * vertices.count, index: 0)
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
                    }
                }
                .msaa(sampleCount: 4)
                .vertexDescriptor(vertexShader.inferredVertexDescriptor())
            }
            _ = try renderer.render(pass)
        }
    }
}
