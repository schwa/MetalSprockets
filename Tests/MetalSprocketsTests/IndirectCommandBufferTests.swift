import Metal
@testable import MetalSprockets
import Testing

// #576: indirect command buffers encoded on the CPU or by a kernel, executed inside a RenderPipeline.
@MainActor
@Suite(.requiresMetal4)
struct IndirectCommandBufferTests {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }
    [[fragment]] float4 fragment_main(constant float4 &color [[buffer(0)]]) { return color; }
    struct Commands { command_buffer buffer; };
    [[kernel]] void encode_draws(device Commands &commands [[buffer(0)]], device MTLIndirectCommandBufferExecutionRange &range [[buffer(1)]], uint index [[thread_position_in_grid]]) {
        render_command command(commands.buffer, index);
        command.draw_primitives(primitive_type::triangle, 0, 6, 1, 0);
        range.location = 0;
        range.length = 1;
    }
    """

    private let device: any MTLDevice
    private let library: any MTLLibrary
    private let vertices: any MTLBuffer

    init() throws {
        device = try #require(MTLCreateSystemDefaultDevice())
        library = try device.makeLibrary(source: Self.source, options: nil)
        let quad: [SIMD2<Float>] = [[-1, -1], [1, -1], [-1, 1], [-1, 1], [1, -1], [1, 1]]
        vertices = try #require(device.makeBuffer(bytes: quad, length: MemoryLayout<SIMD2<Float>>.stride * quad.count, options: .storageModeShared))
    }

    private func scene(_ draw: Draw) throws -> some Element {
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        return try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
            draw
                .vertexBuffer(vertices, index: 0)
                .parameter("color", value: SIMD4<Float>(0, 1, 0, 1))
        }
        .vertexDescriptor(vertex.inferredVertexDescriptor())
        .supportsIndirectCommandBuffers()
    }

    private func centerPixel(_ texture: any MTLTexture) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&bytes, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(texture.width / 2, texture.height / 2, 1, 1), mipmapLevel: 0)
        return bytes
    }

    @Test(.timeLimit(.minutes(1)))
    func commandsEncodedOnTheCPUDraw() async throws {
        let commands = try device.makeRenderIndirectCommandBuffer(commandTypes: .draw, maxCommandCount: 2, options: .storageModeShared)
        commands.indirectRenderCommandAt(0).reset()
        commands.indirectRenderCommandAt(1).drawPrimitives(.triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1, baseInstance: 0)
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm)
        #expect(centerPixel(try await renderer.render(scene(Draw(indirectCommandBuffer: commands, range: 1 ..< 2))).texture) == [0, 255, 0, 255])
        #expect(centerPixel(try await renderer.render(scene(Draw(indirectCommandBuffer: commands, range: 0 ..< 1))).texture) == [0, 0, 0, 255])
        await #expect(throws: (any Error).self) {
            _ = try await renderer.render(scene(Draw(indirectCommandBuffer: commands, range: 1 ..< 3)))
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func commandsEncodedByAKernelDrawTheRangeTheKernelWrote() async throws {
        let commands = try device.makeRenderIndirectCommandBuffer(commandTypes: .draw, maxCommandCount: 1)
        let range = try #require(device.makeBuffer(length: MemoryLayout<MTLIndirectCommandBufferExecutionRange>.size, options: .storageModePrivate))
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm)
        let encode = try ComputePass {
            try ComputePipeline(computeKernel: ComputeKernel(library: library, name: "encode_draws")) {
                try ComputeDispatch(threadgroups: MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
                    .parameter("commands", indirectCommandBuffer: commands)
                    .parameter("range", buffer: range)
            }
        }
        let result = try await renderer.runner.run(encode)
        #expect(result.outcome == .completed)
        #expect(centerPixel(try await renderer.render(scene(Draw(indirectCommandBuffer: commands, rangeBuffer: range))).texture) == [0, 255, 0, 255])
    }
}
