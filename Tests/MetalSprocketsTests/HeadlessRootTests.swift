import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import MetalSupport
import Testing

@MainActor
@Suite("Metal 4 headless roots", .requiresMetal4)
struct HeadlessRootTests {
    private enum InjectedFailure: Error {
        case encoding
    }

    private struct Throwing: Element, WorkloadElement {
        typealias Body = Never
        func workloadEnter(_ node: Node) throws { throw InjectedFailure.encoding }
        nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
    }

    // The same shader and scene as the legacy RedTriangle golden test, so the candidate must match its reference.
    private static let triangleSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }
    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]], constant float4 &color [[buffer(0)]]) {
        return color;
    }
    """

    private static let kernelSource = """
    #include <metal_stdlib>
    using namespace metal;
    kernel void add_kernel(device float *out [[buffer(0)]], constant float &offset [[buffer(1)]], uint tid [[thread_position_in_grid]]) {
        out[tid] = float(tid) + offset;
    }
    """

    private func triangle(device: any MTLDevice, library providedLibrary: (any MTLLibrary)? = nil, color: SIMD4<Float> = [1, 0, 0, 1]) throws -> some Element {
        let library = try providedLibrary ?? device.makeLibrary(source: Self.triangleSource, options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        let vertices: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
        let buffer = try #require(device.makeBuffer(bytes: vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, options: .storageModeShared))
        return try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                .parameter("color", value: color)
        }.vertexDescriptor(vertex.inferredVertexDescriptor())
        .vertexBuffer(buffer, index: 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func offscreenRenderMatchesTheLegacyGoldenAndReportsTiming() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 1_600, height: 1_200), device: device)
        let rendering = try await renderer.render(triangle(device: device))
        try Golden.verify(try rendering.cgImage, named: "RedTriangle")
        let duration = try #require(rendering.gpuTime)
        #expect(duration >= 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func repeatedRendersReuseTheTreeAndPipelines() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 32, height: 32), device: device)
        let library = try await device.makeLibrary(source: Self.triangleSource, options: nil)
        for color in [SIMD4<Float>(1, 0, 0, 1), [0, 1, 0, 1], [0, 0, 1, 1]] {
            let rendering = try await renderer.render(triangle(device: device, library: library, color: color))
            var pixel = [UInt8](repeating: 0, count: 4)
            rendering.texture.getBytes(&pixel, bytesPerRow: 32 * 4, from: MTLRegionMake2D(16, 16, 1, 1), mipmapLevel: 0)
            #expect(pixel == [UInt8(color.z * 255), UInt8(color.y * 255), UInt8(color.x * 255), 255])
        }
        #expect(renderer.runner.context.pipelines.compilationCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func resizeRecreatesAttachmentsWithoutLeakingResidency() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 32, height: 32), device: device)
        let first = try await renderer.render(triangle(device: device))
        try renderer.resize(to: CGSize(width: 64, height: 48))
        let second = try await renderer.render(triangle(device: device))
        #expect(first.texture.width == 32)
        #expect(second.texture.width == 64)
        #expect(second.texture.height == 48)
        #expect(renderer.runner.context.residentAllocationCount == 0)
        #expect(throws: MetalSprocketsError.self) { try renderer.resize(to: CGSize(width: 0, height: 10)) }
    }

    @Test(.timeLimit(.minutes(1)))
    func runnerComputesRepeatedlyAndRecoversFromErrors() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let runner = try FrameRunner(device: device)
        let kernel = try ComputeKernel(library: await device.makeLibrary(source: Self.kernelSource, options: nil), name: "add_kernel")
        let buffer = try #require(device.makeBuffer(length: 8 * 4, options: .storageModeShared))
        func content(offset: Float, failing: Bool = false) throws -> some Element {
            try ComputePass {
                try ComputePipeline(computeKernel: kernel) {
                    try ComputeDispatch(threadsPerGrid: MTLSize(width: 8, height: 1, depth: 1))
                    if failing {
                        Throwing()
                    }
                }
                .parameter("out", buffer: buffer)
                .parameter("offset", value: offset)
            }
        }
        for offset in [Float(10), 20] {
            let result = try await runner.run(content(offset: offset))
            #expect(result.outcome == .completed)
            let values = buffer.contents().bindMemory(to: Float.self, capacity: 8)
            #expect((0..<8).allSatisfy { values[$0] == Float($0) + offset })
        }
        await #expect(throws: InjectedFailure.encoding) { try await runner.run(content(offset: 30, failing: true)) }
        #expect(runner.context.inFlightCount == 0)
        #expect(try await runner.run(content(offset: 40)).outcome == .completed)
        #expect(buffer.contents().load(as: Float.self) == 40)
        // A one-shot run uses its own fresh runner.
        #expect(try await FrameRunner.runOnce(content(offset: 50), device: device).outcome == .completed)
        #expect(buffer.contents().load(as: Float.self) == 50)
    }

    @Test
    func runnerUsesAnInjectedQueueAndValidatesItsDevice() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try device.makeMTL4CommandQueue(descriptor: MTL4CommandQueueDescriptor())
        let runner = try FrameRunner(device: device, commandQueue: queue)
        #expect(runner.context.commandQueue === queue)
        #expect(runner.device === device)
    }

    @Test(.timeLimit(.minutes(1)))
    func teardownWithOutstandingWorkKeepsResourcesUntilCompletion() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        var runner: FrameRunner? = try FrameRunner(device: device)
        let gate = try #require(device.makeSharedEvent())
        try #require(runner).context.waitForEvent(gate, value: 1)
        let completion = try #require(runner).context.completionEvent
        let buffer = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        let submission = try await #require(runner).submit(try ComputePass {
            ComputeCommand { $0.fill(buffer: buffer, range: 0..<16, value: 9) }
        }.useResources([buffer]))
        let weakRunner = WeakBox(try #require(runner))
        runner = nil
        #expect(weakRunner.wrappedValue == nil)
        gate.signaledValue = 1
        await completion.valueSignaled(submission.identifier)
        #expect(try await submission.waitForResult().outcome == .completed)
        #expect(UnsafeRawBufferPointer(start: buffer.contents(), count: 16).allSatisfy { $0 == 9 })
    }
}
