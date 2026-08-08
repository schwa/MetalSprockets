// Embedded Metal source in multi-line string literals uses continuation alignment the rule can't account for.
// swiftlint:disable indentation_width
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("MeshRenderPipeline Tests")
struct MeshRenderPipelineTests {
    // A minimal mesh shader that emits a single triangle covering the viewport.
    // Requires Apple GPU Family 7+ (M1/A14 and newer).
    static let meshSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
    };

    using TriMesh = metal::mesh<VertexOut, void, 3, 1, metal::topology::triangle>;

    [[mesh]]
    void mesh_main(TriMesh output,
                   uint tid [[thread_position_in_threadgroup]]) {
        if (tid == 0) {
            output.set_primitive_count(1);
            output.set_index(0, 0);
            output.set_index(1, 1);
            output.set_index(2, 2);

            VertexOut v0; v0.position = float4( 0.0,  0.75, 0.0, 1.0);
            VertexOut v1; v1.position = float4(-0.75, -0.75, 0.0, 1.0);
            VertexOut v2; v2.position = float4( 0.75, -0.75, 0.0, 1.0);
            output.set_vertex(0, v0);
            output.set_vertex(1, v1);
            output.set_vertex(2, v2);
        }
    }

    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) {
        return float4(0.0, 1.0, 0.0, 1.0);
    }
    """

    /// Object stage feeds a scale to the mesh stage, and the fragment stage takes a bound colour.
    static let objectMeshSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
    };

    struct Payload {
        float scale;
    };

    using TriMesh = metal::mesh<VertexOut, void, 3, 1, metal::topology::triangle>;

    [[object]]
    void object_main(object_data Payload &payload [[payload]],
                     mesh_grid_properties properties,
                     constant float &scale [[buffer(0)]]) {
        payload.scale = scale;
        properties.set_threadgroups_per_grid(uint3(1, 1, 1));
    }

    [[mesh]]
    void mesh_main(TriMesh output,
                   const object_data Payload &payload [[payload]],
                   uint tid [[thread_position_in_threadgroup]]) {
        if (tid == 0) {
            output.set_primitive_count(1);
            output.set_index(0, 0);
            output.set_index(1, 1);
            output.set_index(2, 2);

            float s = payload.scale;
            VertexOut v0; v0.position = float4( 0.0,  0.75 * s, 0.0, 1.0);
            VertexOut v1; v1.position = float4(-0.75 * s, -0.75 * s, 0.0, 1.0);
            VertexOut v2; v2.position = float4( 0.75 * s, -0.75 * s, 0.0, 1.0);
            output.set_vertex(0, v0);
            output.set_vertex(1, v1);
            output.set_vertex(2, v2);
        }
    }

    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]], constant float4 &tint [[buffer(0)]]) {
        return tint;
    }
    """

    private func meshShadersSupported() throws -> Bool {
        let device = try #require(MTLCreateSystemDefaultDevice())
        return device.supportsFamily(.apple7)
    }

    /// Shaders built once, so repeated renders reuse the same `MTLFunction` identities. The pipeline cache is keyed
    /// on those identities, so rebuilding the library every time would miss the cache.
    private struct Shaders {
        var object: ObjectShader
        var mesh: MeshShader
        var fragment: FragmentShader
    }

    private func makeShaders() throws -> Shaders {
        let library = try ShaderLibrary(source: Self.objectMeshSource)
        return Shaders(
            object: try library.function(type: ObjectShader.self, named: "object_main"),
            mesh: try library.function(type: MeshShader.self, named: "mesh_main"),
            fragment: try library.function(type: FragmentShader.self, named: "fragment_main")
        )
    }

    private func objectMeshPass(scale: Float, tint: SIMD4<Float>, depthCompare: Bool, shaders: Shaders? = nil) throws -> some Element {
        let shaders = try shaders ?? makeShaders()
        let objectShader = shaders.object
        let meshShader = shaders.mesh
        let fragmentShader = shaders.fragment

        let pipeline = try MeshRenderPipeline(label: "object+mesh", objectShader: objectShader, meshShader: meshShader, fragmentShader: fragmentShader) {
            Draw { encoder in
                encoder.drawMeshThreadgroups(
                    MTLSize(width: 1, height: 1, depth: 1),
                    threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1),
                    threadsPerMeshThreadgroup: MTLSize(width: 3, height: 1, depth: 1)
                )
            }
            .parameter("scale", functionType: .object, value: scale)
            .parameter("tint", functionType: .fragment, value: tint)
        }

        return try RenderPass {
            if depthCompare {
                pipeline.depthCompare(function: .less, enabled: true)
            }
            else {
                pipeline
            }
        }
    }

    @Test("An object shader feeds the mesh stage")
    func testObjectAndMeshShaders() throws {
        guard try meshShadersSupported() else {
            return
        }
        try Golden.verify(try objectMeshPass(scale: 1, tint: [0, 1, 0, 1], depthCompare: false), named: "MeshTriangle", size: CGSize(width: 128, height: 128))
    }

    @Test("Parameters bound to the object stage reach the mesh stage")
    func testObjectStageParameter() throws {
        guard try meshShadersSupported() else {
            return
        }
        try Golden.verify(try objectMeshPass(scale: 0.5, tint: [1, 0, 1, 1], depthCompare: false), named: "MeshTriangleHalfScale", size: CGSize(width: 128, height: 128))
    }

    @Test("A depth-tested mesh pipeline builds its depth stencil state")
    func testMeshPipelineWithDepthStencil() throws {
        guard try meshShadersSupported() else {
            return
        }
        try Golden.verify(try objectMeshPass(scale: 1, tint: [0, 1, 0, 1], depthCompare: true), named: "MeshTriangle", size: CGSize(width: 128, height: 128))
    }

    @Test("Rendering the same mesh pipeline twice reuses the cached pipeline state")
    func testMeshPipelineCacheHit() throws {
        guard try meshShadersSupported() else {
            return
        }
        // The same shader instances both times, so the cache key matches and the second setup takes the hit path.
        let shaders = try makeShaders()
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(try objectMeshPass(scale: 1, tint: [0, 1, 0, 1], depthCompare: true, shaders: shaders))
        _ = try renderer.render(try objectMeshPass(scale: 1, tint: [0, 1, 0, 1], depthCompare: true, shaders: shaders))
    }

    @Test("A mesh pipeline picks up linked functions from the environment")
    func testMeshPipelineLinkedFunctions() throws {
        guard try meshShadersSupported() else {
            return
        }
        let shaders = try makeShaders()
        let linked = MTLLinkedFunctions()
        linked.functions = []

        let pass = try objectMeshPass(scale: 1, tint: [0, 1, 0, 1], depthCompare: false, shaders: shaders)
            .environment(\.linkedFunctions, linked)
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("Mesh-shader-only pipeline renders")
    func testMeshRenderPipelineWithoutObjectShader() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else {
            return  // Mesh shaders unsupported on this device; skip.
        }
        let library = try ShaderLibrary(source: Self.meshSource)
        let meshShader = try library.function(type: MeshShader.self, named: "mesh_main")
        let fragment = try library.function(type: FragmentShader.self, named: "fragment_main")

        let renderPass = try RenderPass {
            try MeshRenderPipeline(label: "test", meshShader: meshShader, fragmentShader: fragment) {
                Draw { encoder in
                    encoder.drawMeshThreadgroups(
                        MTLSize(width: 1, height: 1, depth: 1),
                        threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1),
                        threadsPerMeshThreadgroup: MTLSize(width: 3, height: 1, depth: 1)
                    )
                }
            }
        }

        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        let rendering = try renderer.render(renderPass)
        #expect(rendering.texture.width == 64)
    }

    // MeshRenderPipeline.requiresSetup now always returns true; rebuild decisions
    // live inside setupEnter's per-node cache (see #327 / #333).
    @Test("requiresSetup is always true")
    func testRequiresSetup() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }
        let library = try ShaderLibrary(source: Self.meshSource)
        let meshShader = try library.function(type: MeshShader.self, named: "mesh_main")
        let fragment = try library.function(type: FragmentShader.self, named: "fragment_main")

        let a = try MeshRenderPipeline(meshShader: meshShader, fragmentShader: fragment) {
            EmptyElement()
        }
        let b = try MeshRenderPipeline(meshShader: meshShader, fragmentShader: fragment) {
            EmptyElement()
        }
        #expect(a.requiresSetup(comparedTo: b) == true)
    }
}
