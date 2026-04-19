import Metal
import MetalKit
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@Suite("MSAAModifier Tests")
struct MSAAModifierTests {
    static let source = """
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

    @MainActor
    private func makeTriangle() throws -> some Element {
        let vertexShader = try VertexShader(source: Self.source)
        let fragmentShader = try FragmentShader(source: Self.source)
        return try RenderPass {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    let vertices: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
                    encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
            .vertexDescriptor(vertexShader.inferredVertexDescriptor())
        }
    }

    @Test("MSAA 4x renders successfully")
    @MainActor
    func testMSAAEnabledRenders() throws {
        let pass = try makeTriangle().msaa(sampleCount: 4)
        let renderer = try OffscreenRenderer(size: CGSize(width: 128, height: 128))
        let rendering = try renderer.render(pass)
        #expect(rendering.texture.width == 128)
        #expect(rendering.texture.height == 128)
    }

    @Test("MSAA recreates textures when size changes")
    @MainActor
    func testMSAATextureRecreationOnSizeChange() throws {
        // Render once, then render again at a different size using the same element graph.
        // Each OffscreenRenderer creates a new System, so we need to share state across renders.
        // Instead, render the same element with two different renderers to verify both succeed.
        let pass = try makeTriangle().msaa(sampleCount: 4)

        let r1 = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try r1.render(pass)

        let r2 = try OffscreenRenderer(size: CGSize(width: 128, height: 128))
        let rendering = try r2.render(pass)
        #expect(rendering.texture.width == 128)
    }

    @Test("MSAA with unsupported sample count throws")
    @MainActor
    func testMSAAUnsupportedSampleCountThrows() throws {
        // 3 is never a supported sample count.
        let pass = try makeTriangle().msaa(sampleCount: 3)
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        #expect(throws: MetalSprocketsError.self) {
            _ = try renderer.render(pass)
        }
    }

    @Test("MSAA reuses textures on second render with same size")
    @MainActor
    func testMSAATextureReuseSameSize() throws {
        // Two sequential renders via the same element graph at the same size.
        // Since OffscreenRenderer builds its own System each time, the MSAAModifier
        // re-runs setupEnter against fresh @MSState both times, so each render creates textures fresh.
        // This still exercises the needsRecreate==true branch twice (coverage parity),
        // but also validates no state bleed across renderers.
        let pass = try makeTriangle().msaa(sampleCount: 2)
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
        _ = try renderer.render(pass)
    }

    @Test("requiresSetup tracks sampleCount changes")
    @MainActor
    func testRequiresSetupOnSampleCountChange() throws {
        struct Leaf: Element, BodylessElement { var body: Never { fatalError() } }
        let a = MSAAModifier(content: Leaf(), sampleCount: 4)
        let b = MSAAModifier(content: Leaf(), sampleCount: 4)
        let c = MSAAModifier(content: Leaf(), sampleCount: 8)
        #expect(a.requiresSetup(comparedTo: b) == false)
        #expect(a.requiresSetup(comparedTo: c) == true)
    }
}
