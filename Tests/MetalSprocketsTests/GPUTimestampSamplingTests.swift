import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import os
import Testing

private final class SampleCollector: Sendable {
    private let samples = OSAllocatedUnfairLock<[GPUCounterSample]>(initialState: [])
    var values: [GPUCounterSample] { samples.withLock { $0 } }
    func append(_ sample: GPUCounterSample) { samples.withLock { $0.append(sample) } }
    func clear() { samples.withLock { $0.removeAll() } }
}

@MainActor
@Suite("Metal 4 GPU counters", .requiresMetal4)
struct GPUTimestampSamplingTests {
    private let device = MTLCreateSystemDefaultDevice()!

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
        VertexOut out;
        out.position = float4(positions[id], 0, 1);
        return out;
    }
    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) {
        float value = 0;
        for (int index = 0; index < 256; index++) { value += sin(in.position.x * 0.01 + index); }
        return float4(value * 0.001, 0, 0, 1);
    }
    kernel void spin(device float *output [[buffer(0)]], uint id [[thread_position_in_grid]]) {
        float value = 0;
        for (int index = 0; index < 4096; index++) { value += sin(float(id + index)); }
        output[id] = value;
    }
    """

    private func renderScene() throws -> some Element {
        let library = try device.makeLibrary(source: Self.source, options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        return try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
        }
    }

    @Test(.timeLimit(.minutes(1)), .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Counter sampling unavailable on CI runners"))
    func renderPassReportsPassAndVertexIntervalsButNoFragmentInterval() async throws {
        let collector = SampleCollector()
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 512, height: 512))
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = renderer.colorTexture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let result = try await renderer.runner.run(try RenderPass { try renderScene() }.renderPassDescriptor(pass).gpuCounters(label: "Main") { collector.append($0) })
        #expect(result.outcome == .completed)
        let sample = try #require(collector.values.first)
        #expect(collector.values.count == 1)
        #expect(sample.label == "Main")
        #expect(sample.endTimestamp > sample.startTimestamp)
        let duration = try #require(sample.duration)
        #expect(duration > 0)
        // The pass runs inside the submission, so it cannot take longer than the whole command buffer.
        if let submission = result.gpuDuration {
            #expect(duration <= submission * 1.05 + 0.0001)
        }
        let vertex = try #require(sample.vertex)
        #expect(vertex.startTimestamp == sample.startTimestamp)
        #expect(vertex.endTimestamp <= sample.endTimestamp)
        #expect(sample.fragment == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func computePassReportsEncoderInterval() async throws {
        let collector = SampleCollector()
        let library = try await device.makeLibrary(source: Self.source, options: nil)
        let kernel = try ComputeKernel(library: library, name: "spin")
        let output = try #require(device.makeBuffer(length: 4 * 65_536, options: .storageModeShared))
        let content = try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 65_536, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
                    .parameter("output", buffer: output)
            }
        }
        .gpuCounters { collector.append($0) }
        let result = try await FrameRunner(device: device).run(content)
        #expect(result.outcome == .completed)
        let sample = try #require(collector.values.first)
        #expect(try #require(sample.duration) > 0)
        #expect(sample.vertex == nil)
        #expect(sample.fragment == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func heapsAreReusedAfterCompletionAndDistinctWhileInFlight() async throws {
        let collector = SampleCollector()
        let context = try MetalContext(device: device)
        let system = System()
        let library = try await device.makeLibrary(source: Self.source, options: nil)
        let kernel = try ComputeKernel(library: library, name: "spin")
        let output = try #require(device.makeBuffer(length: 4 * 1_024, options: .storageModeShared))
        var heapIdentities: [ObjectIdentifier] = []
        let content = try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 1_024, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
                    .parameter("output", buffer: output)
            }
        }
        .onWorkloadEnter { environment in
            let request = try #require(environment.timestampRequest)
            heapIdentities.append(ObjectIdentifier(request.heap.heap))
        }
        .gpuCounters { collector.append($0) }
        for _ in 0..<4 {
            _ = try await context.awaitResult(try context.submit(content, system: system))
        }
        let sampler = try #require(system.nodes.values.compactMap { $0.cache(GPUCountersCache.self) { GPUCountersCache() }.sampler }.first)
        #expect(sampler.heapCount == 1)
        #expect(collector.values.count == 4)
        try #require(heapIdentities.count == 4)
        #expect(Set(heapIdentities).count == 1)

        let gate = try #require(device.makeSharedEvent())
        context.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        let first = try context.submit(content, system: system)
        let second = try context.submit(content, system: system)
        #expect(first.resolvedResult == nil)
        #expect(second.resolvedResult == nil)
        try #require(heapIdentities.count == 6)
        #expect(heapIdentities[4] == heapIdentities[0])
        #expect(heapIdentities[4] != heapIdentities[5])
        #expect(sampler.heapCount == 2)
        gate.signaledValue = 1
        _ = try await context.awaitResult(first)
        _ = try await context.awaitResult(second)
        #expect(sampler.heapCount == 2)
        #expect(collector.values.count == 6)
        // GPU timestamps measure time, not heap identity.
        #expect(collector.values.allSatisfy { $0.startTimestamp > 0 && $0.endTimestamp >= $0.startTimestamp })
    }

    @Test(.timeLimit(.minutes(1)))
    func failedEncodingAndUnsampledTreesReportNothing() async throws {
        let collector = SampleCollector()
        let context = try MetalContext(device: device)
        enum Failure: Error { case expected }
        let system = System()
        let library = try await device.makeLibrary(source: Self.source, options: nil)
        let kernel = try ComputeKernel(library: library, name: "spin")
        let output = try #require(device.makeBuffer(length: 4 * 64, options: .storageModeShared))
        let content = try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 64, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
                    .parameter("output", buffer: output)
            }
        }
        .gpuCounters { collector.append($0) }
        #expect(throws: Failure.expected) {
            try context.submit { scope in
                let root = RecordingRoot(content: content, scope: scope, context: context, commandBuffer: try scope.commandBuffer())
                try system.render(root: root)
                throw Failure.expected
            }
        }
        #expect(collector.values.isEmpty)
        _ = try await context.awaitResult(try context.submit(content, system: system))
        let sampler = try #require(system.nodes.values.compactMap { $0.cache(GPUCountersCache.self) { GPUCountersCache() }.sampler }.first)
        #expect(sampler.heapCount == 1)
        #expect(collector.values.count == 1)
        collector.clear()
        // No pass under the modifier: nothing claims the heap, so nothing is reported.
        _ = try await context.awaitResult(try context.submit(EmptyElement().gpuCounters { collector.append($0) }, system: System()))
        #expect(collector.values.isEmpty)
    }

    @Test
    func invalidTimestampsProduceNilIntervalsNotZero() throws {
        let sampler = try TimestampSampler(device: device)
        #expect(sampler.interval(0, 100) == nil)
        #expect(sampler.interval(100, 0) == nil)
        #expect(sampler.interval(200, 100) == nil)
        let valid = try #require(sampler.interval(100, 100 + sampler.ticksPerSecond / 1_000))
        #expect(abs(try #require(valid.duration) - 0.001) < 1e-6)
    }
}
