import Foundation
import Metal
@testable import MetalSprockets
import simd
import Testing

private final class SampleBox: @unchecked Sendable {
    var sample: GPUCounterSample?
}

@Suite("GPU counters")
struct GPUCountersTests {
    @Test(
        "gpuCounters reports a sample for a render pass",
        .requiresMetal4,
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Counter sampling unavailable on CI runners")
    )
    @MainActor
    func gpuCountersModifierReportsSample() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
        };

        [[vertex]] VertexOut vertex_main(uint id [[vertex_id]]) {
            float2 positions[3] = { float2(0, 0.5), float2(-0.5, -0.5), float2(0.5, -0.5) };
            VertexOut out;
            out.position = float4(positions[id], 0, 1);
            return out;
        }

        [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) {
            return float4(1, 0, 0, 1);
        }
        """

        let vertexShader = try VertexShader(source: source)
        let fragmentShader = try FragmentShader(source: source)

        let box = SampleBox()
        let element = try RenderPass {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
        }
        .gpuCounters(label: "Test") { sample in
            box.sample = sample
        }

        let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try offscreenRenderer.render(element)

        let sample = try #require(box.sample)
        #expect(sample.label == "Test")
        #expect(sample.endTimestamp >= sample.startTimestamp)
        let vertex = try #require(sample.vertex)
        #expect(vertex.endTimestamp >= vertex.startTimestamp)
        // Metal 4 has no start-of-fragment sample, so the fragment interval is not reported (see GPUCounterSample).
        #expect(sample.fragment == nil)
    }

    @Test(
        "gpuCounters reports a sample for a compute pass",
        .requiresMetal4,
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Counter sampling unavailable on CI runners")
    )
    @MainActor
    func gpuCountersModifierReportsComputeSample() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())

        let source = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void fill_kernel(device uint *out [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
            out[tid] = tid;
        }
        """

        let kernel = try ComputeKernel(source: source)
        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        let box = SampleBox()
        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: count, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1))
                    .parameter("out", buffer: buffer)
            }
        }
        .gpuCounters(label: "Compute") { sample in
            box.sample = sample
        }
        .run()

        let sample = try #require(box.sample)
        #expect(sample.label == "Compute")
        #expect(sample.endTimestamp >= sample.startTimestamp)
        #expect(sample.vertex == nil)
        #expect(sample.fragment == nil)
    }

    // Without a dispatch before it, the start timestamp of a compute pass is written late, often after most of the first
    // dispatch has run, so the pass duration is under-reported (#549).
    @Test(
        "gpuCounters reports a stable compute pass duration",
        .requiresMetal4,
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Counter sampling unavailable on CI runners")
    )
    @MainActor
    func gpuCountersComputeDurationIsStable() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void spin_kernel(device float *out [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
            float value = tid;
            for (int index = 0; index < 4000; index++) { value = fma(value, 1.0001, 0.5); }
            out[tid] = value;
        }
        """
        let kernel = try ComputeKernel(source: source)
        let count = 1 << 20
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<Float>.stride * count, options: .storageModePrivate))
        let box = SampleBox()
        var durations: [TimeInterval] = []
        for _ in 0..<8 {
            try ComputePass {
                try ComputePipeline(computeKernel: kernel) {
                    try ForEach(0..<6, id: \.self) { _ in
                        try ComputeDispatch(threadsPerGrid: MTLSize(width: count, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
                            .parameter("out", buffer: buffer)
                    }
                }
            }
            .gpuCounters(label: "Spin") { sample in
                box.sample = sample
            }
            .run()
            durations.append(try #require(box.sample?.duration))
        }
        // The first frame can run longer while the GPU clocks up, so compare with the median.
        let median = durations.sorted()[durations.count / 2]
        #expect(durations.allSatisfy { $0 > median * 0.75 }, "durations: \(durations)")
    }

    @Test(
        "Sampler converts tick deltas to non-negative seconds",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Counter sampling unavailable on CI runners")
    )
    func secondsForTicks() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let sampler = try TimestampSampler(device: device)
        let interval = try #require(sampler.interval(1_000, 1_000))
        #expect(interval.duration == 0)
    }
}
