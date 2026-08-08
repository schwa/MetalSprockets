import CoreGraphics
import Metal
@testable import MetalSprockets
import simd
import Testing

@MainActor
@Suite("Golden image pipelines")
struct GoldenPipelineTests {
    /// A diagonal edge, so anti-aliasing is visible, plus a function-constant-selected tint.
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    constant bool useWarmTint [[function_constant(0)]];

    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main() {
        return useWarmTint ? float4(1, 0.5, 0, 1) : float4(0, 0.5, 1, 1);
    }
    """

    private static let triangle: [SIMD2<Float>] = [[-0.9, -0.8], [0.9, -0.8], [0.9, 0.8]]

    private func tiltedTriangle(warmTint: Bool) throws -> some Element {
        var constants = FunctionConstants()
        constants["useWarmTint"] = .bool(warmTint)
        let library = try ShaderLibrary(source: Self.source)
        let vertexShader = try library.function(type: VertexShader.self, named: "vertex_main", constants: constants)
        let fragmentShader = try library.function(type: FragmentShader.self, named: "fragment_main", constants: constants)

        let pipeline = try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
            Draw { encoder in
                let vertices = Self.triangle
                encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * vertices.count, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
            }
        }
        .vertexDescriptor(vertexShader.inferredVertexDescriptor())

        return try RenderPass {
            pipeline
        }
    }

    @Test func `an unsmoothed diagonal edge is aliased`() throws {
        try Golden.verify(try tiltedTriangle(warmTint: false), named: "AliasedDiagonal")
    }

    @Test func `a function constant selects the warm tint`() throws {
        try Golden.verify(try tiltedTriangle(warmTint: true), named: "WarmTintDiagonal")
    }

    // An MSAA golden belongs here too, but .msaa(sampleCount:) currently produces an image identical to the
    // un-antialiased one. See #354.
}
