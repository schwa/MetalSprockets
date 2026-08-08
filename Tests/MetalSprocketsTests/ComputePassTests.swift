import Foundation
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite
struct ComputePassTests {
    static let kernelSource = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void fill_kernel(
        device uint *out [[buffer(0)]],
        uint tid [[thread_position_in_grid]]
    ) {
        out[tid] = tid + 1;
    }
    """

    @Test
    func testComputePassDispatchesKernel() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        let encoder = node.environmentValues.computeCommandEncoder!
                        encoder.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(
                    threadgroups: MTLSize(width: count / 8, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
                )
            }
        }
        .run()

        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for i in 0..<count {
            #expect(ptr[i] == UInt32(i + 1))
        }
    }

    @Test
    func testComputePassIndirectDispatch() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))
        var arguments = MTLDispatchThreadgroupsIndirectArguments(threadgroupsPerGrid: (UInt32(count / 8), 1, 1))
        let indirectBuffer = try #require(device.makeBuffer(bytes: &arguments, length: MemoryLayout<MTLDispatchThreadgroupsIndirectArguments>.stride, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        let encoder = node.environmentValues.computeCommandEncoder!
                        encoder.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(
                    indirectBuffer: indirectBuffer,
                    threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
                )
            }
        }
        .run()

        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for i in 0..<count {
            #expect(ptr[i] == UInt32(i + 1))
        }
    }

    @Test
    func testIndirectDispatchRejectsMisalignedOffset() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let buffer = try #require(device.makeBuffer(length: 64, options: .storageModeShared))
        #expect(throws: (any Error).self) {
            _ = try ComputeDispatch(
                indirectBuffer: buffer,
                indirectBufferOffset: 2,
                threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
            )
        }
    }

    // See #328: threadsPerThreadgroup can be omitted and derived from the pipeline state.
    @Test
    func testAutomaticThreadsPerThreadgroup() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        let encoder = node.environmentValues.computeCommandEncoder!
                        encoder.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(threadsPerGrid: MTLSize(width: count, height: 1, depth: 1))
            }
        }
        .run()

        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for i in 0..<count {
            #expect(ptr[i] == UInt32(i + 1))
        }
    }

    @Test
    func testAutomaticThreadsPerThreadgroupRespectsPipelineLimits() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let pipelineState = try device.makeComputePipelineState(function: kernel.function)

        let oneDimensional = ComputeDispatch.automaticThreadsPerThreadgroup(for: pipelineState, gridSize: MTLSize(width: 1_000_000, height: 1, depth: 1))
        #expect(oneDimensional.height == 1)
        #expect(oneDimensional.depth == 1)
        #expect(oneDimensional.width <= pipelineState.maxTotalThreadsPerThreadgroup)

        let twoDimensional = ComputeDispatch.automaticThreadsPerThreadgroup(for: pipelineState, gridSize: MTLSize(width: 1_920, height: 1_080, depth: 1))
        #expect(twoDimensional.width * twoDimensional.height * twoDimensional.depth <= pipelineState.maxTotalThreadsPerThreadgroup)

        let unknownGrid = ComputeDispatch.automaticThreadsPerThreadgroup(for: pipelineState, gridSize: nil)
        #expect(unknownGrid.width * unknownGrid.height * unknownGrid.depth <= pipelineState.maxTotalThreadsPerThreadgroup)
    }

    @Test
    func testComputePassLabel() throws {
        // Construct succeeds with a label; actual label is applied during workloadEnter.
        let element = try ComputePass(label: "MyPass") {
            EmptyElement()
        }
        // Ensure execution path runs without throwing when content is empty.
        // Note: still requires a device/queue/commandBuffer provided by Element.run().
        try element.run()
    }
}
