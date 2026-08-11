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
        "GPUCounterSampler resolves a sample for a render pass",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Counter sampling unavailable on CI runners")
    )
    @MainActor
    func gpuCountersModifierReportsSample() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        try #require(GPUCounterSampler(device: device) != nil, "Device does not support stage boundary counter sampling.")

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
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
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
        let fragment = try #require(sample.fragment)
        #expect(vertex.endTimestamp >= vertex.startTimestamp)
        #expect(fragment.endTimestamp >= fragment.startTimestamp)
    }

    @Test(
        "GPUCounterSampler resolves a sample for a compute pass",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Counter sampling unavailable on CI runners")
    )
    @MainActor
    func gpuCountersModifierReportsComputeSample() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        try #require(GPUCounterSampler(device: device) != nil, "Device does not support stage boundary counter sampling.")

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
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        node.environmentValues.computeCommandEncoder!.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(threadsPerGrid: MTLSize(width: count, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1))
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

    @Test(
        "Sampler converts tick deltas to non-negative seconds",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Counter sampling unavailable on CI runners")
    )
    func secondsForTicks() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let sampler = try #require(GPUCounterSampler(device: device))
        if let seconds = sampler.seconds(forTicks: 0) {
            #expect(seconds == 0)
        }
    }
}
