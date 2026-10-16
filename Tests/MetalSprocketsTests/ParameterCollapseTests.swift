import Metal
@testable import MetalSprockets
import simd
import Testing

// Parameter scoping on Metal 4, mostly checked on the GPU. Chained parameter modifiers collapse into one node (#54,
// restored in RFC 0006).
@MainActor
@Suite("Parameter modifier scoping")
struct ParameterCollapseTests {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct Uniforms { float4x4 transform; float4 tint; };
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
        VertexOut out;
        out.position = float4(positions[id], 0, 1);
        return out;
    }
    [[fragment]] float4 color_main(constant float4 &color [[buffer(0)]]) { return color; }
    [[fragment]] float4 uniforms_main(constant Uniforms &uniforms [[buffer(0)]]) {
        return uniforms.transform * uniforms.tint;
    }
    """

    private func centerPixel(fragment: String, _ bind: (Draw) -> some Element) throws -> [UInt8] {
        let library = try ShaderLibrary(source: Self.source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: library.function(type: VertexShader.self, named: "vertex_main"), fragmentShader: library.function(type: FragmentShader.self, named: fragment)) {
                bind(Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) })
            }
        }
        let texture = try OffscreenRenderer(size: CGSize(width: 8, height: 8)).render(pass).texture
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&pixel, bytesPerRow: 8 * 4, from: MTLRegionMake2D(4, 4, 1, 1), mipmapLevel: 0)
        return pixel
    }

    @Test func `a chain of parameter modifiers produces a single node`() throws {
        let element = EmptyElement()
            .vertexValues([SIMD2<Float>(0, 0)], index: 0)
            .parameter("a", value: SIMD4<Float>(1, 0, 0, 1))
            .parameter("b", value: simd_float4x4(diagonal: [1, 1, 1, 1]))
        let system = System()
        try system.update(root: element)
        #expect(system.nodes.values.filter { $0.element is any CollapsibleWorkloadModifier }.count == 1)
        #expect(system.nodes.values.contains { $0.element is EmptyElement })
    }

    @Test func `a mixed chain of workload modifiers produces a single node`() throws {
        let element = EmptyElement()
            .parameter("a", value: SIMD4<Float>(1, 0, 0, 1))
            .viewport(MTLViewport(originX: 0, originY: 0, width: 1, height: 1, znear: 0, zfar: 1))
            .depthBias(0.5)
            .parameter("b", value: SIMD4<Float>(0, 1, 0, 1))
            .onSubmissionCommitted { _ in }
        let system = System()
        try system.update(root: element)
        #expect(system.nodes.values.filter { $0.element is any CollapsibleWorkloadModifier }.count == 1)
    }

    // Collapsed draw state is written on the outer node; a write nearer the content still wins.
    @Test(.requiresMetal4) func `collapsed draw state keeps the nearest write`() throws {
        var seen: DepthBias?
        let system = System()
        try system.update(root: EmptyElement().onWorkloadEnter { seen = $0.depthBias }.depthBias(0.25).parameter("x", value: SIMD4<Float>(0, 0, 0, 0)).depthBias(0.75))
        try system.processWorkload()
        #expect(seen?.bias == 0.25)
    }

    @Test(.requiresMetal4) func `the binding nearest the content wins for a repeated name in the same stage`() throws {
        let pixel = try centerPixel(fragment: "color_main") {
            $0.parameter("color", functionType: .fragment, value: SIMD4<Float>(1, 0, 0, 1))
                .parameter("color", functionType: .fragment, value: SIMD4<Float>(0, 1, 0, 1))
        }
        // BGRA: red, the modifier nearest the Draw.
        #expect(pixel == [0, 0, 255, 255])
    }

    @Test(.requiresMetal4) func `an inner scope overrides an outer one without affecting siblings`() throws {
        let library = try ShaderLibrary(source: Self.source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: library.function(type: VertexShader.self, named: "vertex_main"), fragmentShader: library.function(type: FragmentShader.self, named: "color_main")) {
                Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                    .parameter("color", value: SIMD4<Float>(0, 0, 1, 1))
                // A sibling that draws nothing: it must still see the outer value, not the first Draw's.
                Draw { _ in }
            }
            .parameter("color", value: SIMD4<Float>(0, 1, 0, 1))
        }
        let texture = try OffscreenRenderer(size: CGSize(width: 8, height: 8)).render(pass).texture
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&pixel, bytesPerRow: 8 * 4, from: MTLRegionMake2D(4, 4, 1, 1), mipmapLevel: 0)
        #expect(pixel == [255, 0, 0, 255])
    }

    @Test(.requiresMetal4) func `bitwise-copyable structs bind as single values`() throws {
        struct Uniforms: BitwiseCopyable {
            var transform: simd_float4x4
            var tint: SIMD4<Float>
        }
        let pixel = try centerPixel(fragment: "uniforms_main") {
            $0.parameter("uniforms", value: Uniforms(transform: matrix_identity_float4x4, tint: [0, 1, 0, 1]))
        }
        #expect(pixel == [0, 255, 0, 255])
    }

    // Regression for #460: POD structs that do NOT statically declare BitwiseCopyable (e.g. C/Metal header structs
    // imported through a clang module) must still bind. The parameter APIs check POD-ness at runtime, not compile time.
    @Test(.requiresMetal4) func `POD structs without a BitwiseCopyable conformance bind as single values`() throws {
        struct Uniforms {
            var transform: simd_float4x4
            var tint: SIMD4<Float>
        }
        let pixel = try centerPixel(fragment: "uniforms_main") {
            $0.parameter("uniforms", value: Uniforms(transform: matrix_identity_float4x4, tint: [0, 1, 0, 1]))
        }
        #expect(pixel == [0, 255, 0, 255])
    }
}
