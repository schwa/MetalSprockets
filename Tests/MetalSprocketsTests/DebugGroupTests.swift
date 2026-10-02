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

    @Test(.requiresMetal4) func `a debug group around a draw renders`() throws {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
                .debugGroup("Triangle")
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        _ = try renderer.render(pass)
    }

    @Test(.requiresMetal4) func `a debug group can wrap a whole pass via the command buffer`() throws {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
        .debugGroup("Scene")
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        _ = try renderer.render(pass)
    }

    @Test(.requiresMetal4) func `a debug group works on a compute encoder`() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.computeSource)
        let count = 4
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(
                    threadgroups: MTLSize(width: 1, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: count, height: 1, depth: 1)
                )
                    .parameter("out", buffer: buffer)
                .debugGroup("Dispatch")
            }
        }
        .run()
    }

    @Test(.requiresMetal4) func `the modifier carries its label`() throws {
        let element = EmptyElement().debugGroup("Label")
        let modifier = try #require(element as? DebugGroupModifier<EmptyElement>)
        #expect(modifier.label == "Label")
    }

    @Test(.requiresMetal4) func `two groups are equal when their labels match`() throws {
        let a = try #require(EmptyElement().debugGroup("Scene") as? DebugGroupModifier<EmptyElement>)
        let same = try #require(EmptyElement().debugGroup("Scene") as? DebugGroupModifier<EmptyElement>)
        let different = try #require(EmptyElement().debugGroup("Overlay") as? DebugGroupModifier<EmptyElement>)

        #expect(a == same)
        #expect(a != different)
    }

    @Test(.requiresMetal4) func `a debug group works around a pipeline-free compute command`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let buffer = try #require(device.makeBuffer(length: 16, options: .storageModeShared))

        try ComputePass {
            ComputeCommand { encoder in
                encoder.fill(buffer: buffer, range: 0..<16, value: 0x42)
            }
            .debugGroup("Fill")
        }
        .useComputeResources([buffer], usage: .write)
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
