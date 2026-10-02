import Metal
@testable import MetalSprockets
import simd
import Testing

@Suite("FunctionTypes")
struct FunctionTypesTests {
    @Test func `an empty set holds no function types`() {
        #expect(FunctionTypes().isEmpty)
        #expect(FunctionTypes().functionTypes.isEmpty)
    }

    @Test(arguments: [MTLFunctionType.vertex, .fragment, .kernel, .object, .mesh, .visible, .intersection])
    func `a single function type round-trips`(functionType: MTLFunctionType) {
        #expect(FunctionTypes(functionType).functionTypes == [functionType])
    }

    @Test func `nil means no function types`() {
        #expect(FunctionTypes(nil as MTLFunctionType?).isEmpty)
    }

    @Test func `function types come back in pipeline order`() {
        #expect(FunctionTypes([.fragment, .vertex]).functionTypes == [.vertex, .fragment])
        #expect(FunctionTypes.meshRender.functionTypes == [.object, .mesh, .fragment])
    }

    @Test func `render is vertex plus fragment`() {
        #expect(FunctionTypes.render == [.vertex, .fragment])
    }

    @Test func `set algebra works`() {
        #expect(FunctionTypes.render.contains(.vertex))
        #expect(FunctionTypes.render.subtracting(.vertex) == .fragment)
        #expect(FunctionTypes.render.union(.kernel).functionTypes.count == 3)
    }
}

@MainActor
@Suite("Multi-stage parameter binding")
struct MultiStageParameterTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]], constant float4 &tint [[buffer(1)]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0) * tint.w;
        return out;
    }

    [[fragment]] float4 fragment_main(constant float4 &tint [[buffer(0)]]) {
        return tint;
    }
    """

    @Test(.requiresMetal4) func `a parameter present in both stages binds to both`() throws {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
                .parameter("tint", functionTypes: .render, value: SIMD4<Float>(1, 0, 0, 1))
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        _ = try renderer.render(pass)
    }

    /// Renders with `tint` bound per stage and returns the center pixel (BGRA).
    private func centerPixel(_ bind: (Draw) -> some Element) throws -> [UInt8] {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                bind(Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) })
                    .vertexValues(([[-1, -1], [3, -1], [-1, 3]] as [SIMD2<Float>]), index: 0)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
        let texture = try OffscreenRenderer(size: CGSize(width: 8, height: 8)).render(pass).texture
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&pixel, bytesPerRow: 8 * 4, from: MTLRegionMake2D(4, 4, 1, 1), mipmapLevel: 0)
        return pixel
    }

    @Test(.requiresMetal4) func `a render-stage set reaches both stages`() throws {
        // The vertex stage needs tint.w == 1 to keep the triangle; the fragment stage outputs tint.
        #expect(try centerPixel { $0.parameter("tint", functionTypes: .render, value: SIMD4<Float>(1, 0, 0, 1)) } == [0, 0, 255, 255])
    }

    @Test(.requiresMetal4) func `single-stage overloads bind only their stage`() throws {
        // The same name, different values per stage: green only if each filter reaches exactly its own stage.
        let pixel = try centerPixel {
            $0.parameter("tint", functionType: .vertex, value: SIMD4<Float>(0, 0, 0, 1))
                .parameter("tint", functionType: .fragment, value: SIMD4<Float>(0, 1, 0, 1))
        }
        #expect(pixel == [0, 255, 0, 255])
    }
}
