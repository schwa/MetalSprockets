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
