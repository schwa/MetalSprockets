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

    @Test func `a parameter present in both stages binds to both`() throws {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .parameter("tint", functionTypes: .render, value: SIMD4<Float>(1, 0, 0, 1))
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        _ = try renderer.render(pass)
    }

    @Test func `the modifier records the requested stages`() throws {
        let element = EmptyElement().parameter("tint", functionTypes: .render, value: SIMD4<Float>(1, 0, 0, 1))
        let modifier = try #require(element as? ParameterElementModifier<EmptyElement>)
        #expect(modifier.parameters[name: "tint"]?.functionTypes == .render)
    }

    @Test func `the single-stage overload still targets one stage`() throws {
        let element = EmptyElement().parameter("tint", functionType: .fragment, value: SIMD4<Float>(1, 0, 0, 1))
        let modifier = try #require(element as? ParameterElementModifier<EmptyElement>)
        #expect(modifier.parameters[name: "tint"]?.functionTypes == .fragment)
    }
}
