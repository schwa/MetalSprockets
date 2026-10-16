import CoreGraphics
import Metal
import MetalSprockets
import os
import Testing

// #447: client-owned counter heaps written from raw encoder closures, using only public API.
@MainActor
@Suite("Custom counter-heap timestamps", .requiresMetal4)
struct CustomCounterHeapTests {
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

    private final class Resolved: Sendable {
        private let state = OSAllocatedUnfairLock<(timestamps: [UInt64], gpuDuration: TimeInterval?)?>(initialState: nil)
        var value: (timestamps: [UInt64], gpuDuration: TimeInterval?)? { state.withLock { $0 } }
        func set(_ timestamps: [UInt64], _ gpuDuration: TimeInterval?) { state.withLock { $0 = (timestamps, gpuDuration) } }
    }

    private func makeHeap(count: Int) throws -> any MTL4CounterHeap {
        let descriptor = MTL4CounterHeapDescriptor()
        descriptor.type = .timestamp
        descriptor.count = count
        let heap = try device.makeCounterHeap(descriptor: descriptor)
        heap.invalidateCounterRange(0..<count)
        return heap
    }

    nonisolated private static func timestamps(_ heap: any MTL4CounterHeap, count: Int) throws -> [UInt64] {
        guard let data = try heap.resolveCounterRange(0..<count) else {
            return []
        }
        return data.withUnsafeBytes { $0.bindMemory(to: MTL4TimestampHeapEntry.self).map(\.timestamp) }
    }

    private func checkTimestamps(_ timestamps: [UInt64], count: Int, gpuDuration: TimeInterval?) throws {
        try #require(timestamps.count == count)
        #expect(timestamps.allSatisfy { $0 != 0 }, "\(timestamps)")
        #expect(zip(timestamps, timestamps.dropFirst()).allSatisfy { $0 <= $1 }, "\(timestamps)")
        let frequency = device.queryTimestampFrequency()
        try #require(frequency > 0)
        let span = Double(timestamps[count - 1] - timestamps[0]) / Double(frequency)
        #expect(span > 0)
        if let gpuDuration {
            #expect(span <= gpuDuration * 1.05 + 0.0001)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func `render pass timestamps from RenderCommand and Draw closures resolve in order`() throws {
        let count = 4
        let heap = try makeHeap(count: count)
        nonisolated(unsafe) let callbackHeap = heap
        let resolved = Resolved()
        let library = try device.makeLibrary(source: Self.source, options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        let content = try RenderPass {
            RenderCommand { $0.writeTimestamp(granularity: .precise, after: .vertex, counterHeap: heap, index: 0) }
            try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
                Draw { encoder in
                    encoder.writeTimestamp(granularity: .precise, after: .vertex, counterHeap: heap, index: 1)
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                    encoder.writeTimestamp(granularity: .precise, after: .fragment, counterHeap: heap, index: 2)
                }
            }
            RenderCommand { $0.writeTimestamp(granularity: .precise, after: .fragment, counterHeap: heap, index: 3) }
        }
        .onCommandBufferCompleted { result in
            resolved.set((try? Self.timestamps(callbackHeap, count: count)) ?? [], result.gpuDuration)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 512, height: 512), device: device)
        _ = try renderer.render(content)
        let value = try #require(resolved.value)
        try checkTimestamps(value.timestamps, count: count, gpuDuration: value.gpuDuration)
    }

    @Test(.timeLimit(.minutes(1)))
    func `compute pass timestamps from ComputeCommand closures bracket a dispatch`() throws {
        let count = 2
        let heap = try makeHeap(count: count)
        nonisolated(unsafe) let callbackHeap = heap
        let resolved = Resolved()
        let library = try device.makeLibrary(source: Self.source, options: nil)
        let kernel = try ComputeKernel(library: library, name: "spin")
        let output = try #require(device.makeBuffer(length: 4 * 65_536, options: .storageModeShared))
        let content = try ComputePass {
            ComputeCommand { $0.writeTimestamp(granularity: .precise, counterHeap: heap, index: 0) }
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 65_536, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
                    .parameter("output", buffer: output)
            }
            ComputeCommand { $0.writeTimestamp(granularity: .precise, counterHeap: heap, index: 1) }
        }
        .onCommandBufferCompleted { result in
            resolved.set((try? Self.timestamps(callbackHeap, count: count)) ?? [], result.gpuDuration)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 16, height: 16), device: device)
        _ = try renderer.render(content)
        let value = try #require(resolved.value)
        try checkTimestamps(value.timestamps, count: count, gpuDuration: value.gpuDuration)
    }
}
