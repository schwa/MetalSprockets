import CoreGraphics
import Metal
@testable import MetalSprockets
import simd
import Testing

@MainActor
@Suite("debugGroup modifier")
struct DebugGroupTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    [[vertex]] float4 vertex_main(const VertexIn in [[stage_in]]) {
        return float4(in.position, 0.0, 1.0);
    }

    [[fragment]] float4 fragment_main() {
        return float4(1, 0, 0, 1);
    }
    """

    static let computeSource = """
    #include <metal_stdlib>
    using namespace metal;

    [[kernel]] void kernel_main(device uint *out [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
        out[tid] = tid;
    }
    """

    @Test func `a debug group around a draw renders`() throws {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .debugGroup("Triangle")
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        _ = try renderer.render(pass)
    }

    @Test func `a debug group can wrap a whole pass via the command buffer`() throws {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
        .debugGroup("Scene")
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        _ = try renderer.render(pass)
    }

    @Test func `a debug group works on a compute encoder`() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.computeSource)
        let count = 4
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        node.environmentValues.computeCommandEncoder!.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(
                    threadgroups: MTLSize(width: 1, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: count, height: 1, depth: 1)
                )
                .debugGroup("Dispatch")
            }
        }
        .run()
    }

    @Test func `the modifier carries its label`() throws {
        let element = EmptyElement().debugGroup("Label")
        let modifier = try #require(element as? DebugGroupModifier<EmptyElement>)
        #expect(modifier.label == "Label")
    }

    @Test func `using the modifier with no command buffer throws`() throws {
        let system = System()
        try system.update(root: EmptyElement().debugGroup("Label"))
        #expect(throws: (any Error).self) {
            try system.processWorkload()
        }
    }
}
