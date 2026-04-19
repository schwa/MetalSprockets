import Metal
@testable import MetalSprockets
import Testing

/// Smoke tests that exercise the `if let label { ... .label = label }` paths
/// in the various pipeline/pass elements. They render real triangles off-screen
/// to make sure the label is applied during setup/workload without errors.
@MainActor
@Suite("Labeled Pipeline Tests")
struct LabeledPipelineTests {
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

    kernel void noop_kernel(uint tid [[thread_position_in_grid]]) {}
    """

    @Test("RenderPass and RenderPipeline with labels render successfully")
    func labeledRenderPassAndPipeline() throws {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        let pass = try RenderPass(label: "MyPass") {
            try RenderPipeline(label: "MyPipeline", vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        _ = try renderer.render(pass)
    }

    @Test("ComputePass with a label runs without error")
    func labeledComputePass() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let kernel = try ComputeKernel(source: Self.source)

        try ComputePass(label: "MyComputePass") {
            try ComputePipeline(label: "MyPipeline", computeKernel: kernel) {
                EmptyElement()
            }
        }
        .environment(\.device, device)
        .run()
    }
}
