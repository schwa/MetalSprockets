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

    @Test func `two groups are equal when their labels match`() throws {
        let a = try #require(EmptyElement().debugGroup("Scene") as? DebugGroupModifier<EmptyElement>)
        let same = try #require(EmptyElement().debugGroup("Scene") as? DebugGroupModifier<EmptyElement>)
        let different = try #require(EmptyElement().debugGroup("Overlay") as? DebugGroupModifier<EmptyElement>)

        #expect(a == same)
        #expect(a != different)
    }

    @Test func `a debug group works on a blit encoder`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let buffer = try #require(device.makeBuffer(length: 16, options: .storageModeShared))

        try BlitPass {
            Blit { encoder in
                encoder.fill(buffer: buffer, range: 0..<16, value: 0x42)
            }
            .debugGroup("Fill")
        }
        .run()

        // The group must not disturb the work it wraps.
        let contents = buffer.contents().bindMemory(to: UInt8.self, capacity: 16)
        for index in 0..<16 {
            #expect(contents[index] == 0x42)
        }
    }

    @Test func `using the modifier with no command buffer throws`() throws {
        let system = System()
        try system.update(root: EmptyElement().debugGroup("Label"))
        #expect(throws: (any Error).self) {
            try system.processWorkload()
        }
    }
}
