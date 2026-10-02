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

    @Test("A threadgroups dispatch with no explicit threadgroup size picks one automatically", .requiresMetal4)
    func testAutomaticThreadgroupSizeForThreadgroupsDispatch() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                // No threadsPerThreadgroup given. A threadgroups-per-grid dispatch has no grid size to derive one
                // from, so the automatic sizing falls back on the pipeline state's own limits.
                try ComputeDispatch(threadgroups: MTLSize(width: 1, height: 1, depth: 1))
                    .parameter("out", buffer: buffer)
            }
        }
        .run()

        // One threadgroup ran, so at least the first element was written.
        let contents = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        #expect(contents[0] == 1)
    }

    @Test(.requiresMetal4)
    func testComputePassDispatchesKernel() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(
                    threadgroups: MTLSize(width: count / 8, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
                )
                    .parameter("out", buffer: buffer)
            }
        }
        .run()

        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for i in 0..<count {
            #expect(ptr[i] == UInt32(i + 1))
        }
    }

    @Test(.requiresMetal4)
    func testComputePassIndirectDispatch() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))
        var arguments = MTLDispatchThreadgroupsIndirectArguments(threadgroupsPerGrid: (UInt32(count / 8), 1, 1))
        let indirectBuffer = try #require(device.makeBuffer(bytes: &arguments, length: MemoryLayout<MTLDispatchThreadgroupsIndirectArguments>.stride, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(
                    indirectBuffer: indirectBuffer,
                    threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
                )
                    .parameter("out", buffer: buffer)
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
    @Test(.requiresMetal4)
    func testAutomaticThreadsPerThreadgroup() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: count, height: 1, depth: 1))
                    .parameter("out", buffer: buffer)
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

    @Test(.requiresMetal4)
    func testComputePassLabel() throws {
        // Construct succeeds with a label; actual label is applied during workloadEnter.
        let element = try ComputePass(label: "MyPass") {
            EmptyElement()
        }
        // Ensure execution path runs without throwing when content is empty.
        // Requires the device/queue/commandBuffer that Element.run() supplies.
        try element.run()
    }

    // #452: an acceleration structure binds as a shader parameter and a kernel can trace rays against it.
    @Test(.requiresMetal4)
    func accelerationStructureBindsAsAParameter() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let triangle: [SIMD3<Float>] = [[-1, -1, 0], [1, -1, 0], [0, 1, 0]]
        let vertices = try #require(device.makeBuffer(bytes: triangle, length: MemoryLayout<SIMD3<Float>>.stride * 3, options: .storageModeShared))
        let geometry = MTLAccelerationStructureTriangleGeometryDescriptor()
        geometry.vertexBuffer = vertices
        geometry.vertexStride = MemoryLayout<SIMD3<Float>>.stride
        geometry.triangleCount = 1
        let descriptor = MTLPrimitiveAccelerationStructureDescriptor()
        descriptor.geometryDescriptors = [geometry]
        let sizes = device.accelerationStructureSizes(descriptor: descriptor)
        let accelerationStructure = try #require(device.makeAccelerationStructure(size: sizes.accelerationStructureSize))
        let scratch = try #require(device.makeBuffer(length: sizes.buildScratchBufferSize, options: .storageModePrivate))
        // Built on a plain Metal queue; the Metal 4 submission only reads it.
        let commandBuffer = try #require(device.makeCommandQueue()?.makeCommandBuffer())
        let encoder = try #require(commandBuffer.makeAccelerationStructureCommandEncoder())
        encoder.build(accelerationStructure: accelerationStructure, descriptor: descriptor, scratchBuffer: scratch, scratchBufferOffset: 0)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let kernel = try ComputeKernel(source: """
        #include <metal_stdlib>
        #include <metal_raytracing>
        using namespace metal;
        using namespace raytracing;
        kernel void trace(primitive_acceleration_structure scene [[buffer(0)]], device uint *out [[buffer(1)]], uint tid [[thread_position_in_grid]]) {
            ray r;
            r.origin = float3(tid == 0 ? 0.0 : 5.0, 0, -1);
            r.direction = float3(0, 0, 1);
            r.min_distance = 0;
            r.max_distance = 10;
            intersector<triangle_data> intersector;
            out[tid] = intersector.intersect(r, scene).type == intersection_type::triangle ? 1 : 2;
        }
        """)
        let output = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * 2, options: .storageModeShared))
        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 2, height: 1, depth: 1))
                    .parameter("scene", accelerationStructure: accelerationStructure)
                    .parameter("out", buffer: output)
            }
        }
        .run()
        let results = output.contents().bindMemory(to: UInt32.self, capacity: 2)
        #expect(results[0] == 1)
        #expect(results[1] == 2)
    }
}
