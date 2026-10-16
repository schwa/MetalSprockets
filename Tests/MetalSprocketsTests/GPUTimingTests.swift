import CoreGraphics
import Metal
@testable import MetalSprockets
import os
import Testing

@MainActor
@Suite("gpuTimed and onGPUTimings", .requiresMetal4)
struct GPUTimingTests {
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

    private final class Collected: Sendable {
        private let state = OSAllocatedUnfairLock<[[GPUTiming]]>(initialState: [])
        var batches: [[GPUTiming]] { state.withLock { $0 } }
        func append(_ timings: [GPUTiming]) { state.withLock { $0.append(timings) } }
    }

    private func pipeline(@ElementBuilder _ content: () throws -> some Element) throws -> some Element {
        let library = try device.makeLibrary(source: Self.source, options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        return try RenderPipeline(vertexShader: vertex, fragmentShader: fragment, content: content)
    }

    private func triangle() -> some Element {
        Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
    }

    private func renderer() throws -> OffscreenRenderer {
        try OffscreenRenderer(size: CGSize(width: 256, height: 256), device: device)
    }

    @Test(.timeLimit(.minutes(1)))
    func `a render pass reports its interval`() throws {
        let collected = Collected()
        let content = try RenderPass {
            try pipeline { triangle() }
        }
        .gpuTimed("pass")
        .onGPUTimings { collected.append($0) }
        _ = try renderer().render(content)

        #expect(collected.batches.count == 1)
        let timings = try #require(collected.batches.first)
        #expect(timings.map(\.label) == ["pass"])
        #expect(timings.allSatisfy { $0.duration > 0 })
    }

    @Test(.timeLimit(.minutes(1)))
    func `gpuTimed inside a pass reports nothing`() throws {
        let collected = Collected()
        let content = try RenderPass {
            try pipeline {
                triangle().gpuTimed("draw")
            }
            .gpuTimed("pipeline")
        }
        .gpuTimed("pass")
        .onGPUTimings { collected.append($0) }
        _ = try renderer().render(content)
        #expect(collected.batches.first?.map(\.label) == ["pass"])
    }

    @Test(.timeLimit(.minutes(1)))
    func `a compute pass reports its interval and nested timings on the same pass share timestamps`() throws {
        let collected = Collected()
        let library = try device.makeLibrary(source: Self.source, options: nil)
        let kernel = try ComputeKernel(library: library, name: "spin")
        let output = try #require(device.makeBuffer(length: 4 * 65_536, options: .storageModeShared))
        let content = try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 65_536, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
                    .parameter("output", buffer: output)
                    .gpuTimed("dispatch")
            }
        }
        .gpuTimed("inner")
        .gpuTimed("outer")
        .onGPUTimings { collected.append($0) }
        _ = try renderer().render(content)

        // Both end on the same compute encoder back to back, where Metal keeps only the first precise timestamp.
        let timings = try #require(collected.batches.first)
        #expect(timings.map(\.label) == ["outer", "inner"])
        #expect(timings.allSatisfy { $0.duration > 0 })
        #expect(timings[0].startTimestamp == timings[1].startTimestamp && timings[0].endTimestamp == timings[1].endTimestamp)
    }

    @Test(.timeLimit(.minutes(1)))
    func `a timing above several passes spans from the first to the last`() throws {
        let collected = Collected()
        let content = try Group {
            try RenderPass { try pipeline { triangle() } }.gpuTimed("first")
            try RenderPass { try pipeline { triangle() } }.gpuTimed("second")
        }
        .gpuTimed("both")
        .onGPUTimings { collected.append($0) }
        _ = try renderer().render(content)

        let timings = try #require(collected.batches.first)
        #expect(timings.map(\.label) == ["both", "first", "second"])
        let both = timings[0], first = timings[1], second = timings[2]
        #expect(both.startTimestamp <= first.startTimestamp)
        #expect(both.endTimestamp >= second.endTimestamp)
        #expect(first.endTimestamp <= second.endTimestamp)
    }

    @Test(.timeLimit(.minutes(1)))
    func `more timings than one heap holds lease extra heaps and pool them across frames`() throws {
        let collected = Collected()
        let count = GPUTimingHeapPool.heapCapacity / 2 + 1 // Two slots each, so this needs two heaps.
        let renderer = try renderer()
        func frame() throws -> some Element {
            try ForEach(Array(0..<count), id: \.self) { index in
                try RenderPass { try pipeline { triangle() } }.gpuTimed("pass \(index)")
            }
            .onGPUTimings { collected.append($0) }
        }
        for _ in 0..<3 {
            _ = try renderer.render(try frame())
        }
        #expect(collected.batches.count == 3)
        for batch in collected.batches {
            #expect(batch.map(\.label) == (0..<count).map { "pass \($0)" })
            #expect(batch.allSatisfy { $0.duration > 0 })
        }
    }

    // Metal allows only 32 counter heaps per process, so a leaked heap per frame fails within 32 frames.
    @Test(.timeLimit(.minutes(1)))
    func `heaps are returned to the pool so many frames do not exhaust them`() throws {
        let collected = Collected()
        let renderer = try renderer()
        for _ in 0..<100 {
            _ = try renderer.render(try RenderPass { try pipeline { triangle() } }.gpuTimed("pass").onGPUTimings { collected.append($0) })
        }
        #expect(collected.batches.count == 100)
        #expect(collected.batches.allSatisfy { $0.map(\.label) == ["pass"] })
    }

    @Test(.timeLimit(.minutes(1)))
    func `gpuTimed without onGPUTimings does nothing`() throws {
        let content = try RenderPass {
            try pipeline { triangle().gpuTimed("orphan") }
        }
        .gpuTimed("pass")
        _ = try renderer().render(content)
    }

    @Test(.timeLimit(.minutes(1)))
    func `a timing that encodes no pass is left out`() throws {
        let collected = Collected()
        let content = try Group {
            EmptyElement().gpuTimed("nothing")
            try RenderPass { try pipeline { triangle() } }.gpuTimed("pass")
        }
        .onGPUTimings { collected.append($0) }
        _ = try renderer().render(content)
        #expect(collected.batches.first?.map(\.label) == ["pass"])
    }
}
