import Foundation
import Metal
import MetalFX
import Testing

@Suite("Metal 4 SDK probes", .enabled(if: ProcessInfo.processInfo.environment["METALSPROCKETS_METAL4_PROBES"] == "1"))
struct Metal4SDKProbeTests {
    @Test(.timeLimit(.minutes(1)))
    func copyBarriersArgumentTablesAndFeedback() async throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            Issue.record("Metal 4 probes require OS 26 or later")
            return
        }
        let device = try #require(MTLCreateSystemDefaultDevice())
        try #require(device.supportsFamily(.metal4))
        let queue = try device.makeMTL4CommandQueue(descriptor: MTL4CommandQueueDescriptor())
        let commandBuffer = try #require(device.makeCommandBuffer())
        let allocator = try device.makeCommandAllocator(descriptor: MTL4CommandAllocatorDescriptor())
        let event = try #require(device.makeSharedEvent())
        let buffers = try (0..<4).map { _ in
            try #require(device.makeBuffer(length: 256, options: .storageModeShared))
        }
        let residency = try device.makeResidencySet(descriptor: MTLResidencySetDescriptor())
        residency.addAllocations(buffers)
        residency.commit()
        queue.addResidencySet(residency)
        let compiler = try device.makeCompiler(descriptor: MTL4CompilerDescriptor())
        let library = try await device.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;
        kernel void increment(device const uint *input [[buffer(0)]], device uint *output [[buffer(1)]], uint index [[thread_position_in_grid]]) {
            output[index] = input[index] + 1;
        }
        """, options: nil)
        let function = MTL4LibraryFunctionDescriptor()
        function.library = library
        function.name = "increment"
        let descriptor = MTL4ComputePipelineDescriptor()
        descriptor.computeFunctionDescriptor = function
        let pipeline = try await compiler.makeComputePipelineState(descriptor: descriptor)
        let tableDescriptor = MTL4ArgumentTableDescriptor()
        tableDescriptor.maxBufferBindCount = 2
        tableDescriptor.initializeBindings = true
        let table = try device.makeArgumentTable(descriptor: tableDescriptor)

        for frameIndex in 1...12 {
            allocator.reset()
            commandBuffer.beginCommandBuffer(allocator: allocator)
            let producer = try #require(commandBuffer.makeComputeCommandEncoder())
            producer.fill(buffer: buffers[0], range: 0..<256, value: UInt8(frameIndex))
            if !frameIndex.isMultiple(of: 2) {
                producer.barrier(afterStages: .blit, beforeQueueStages: .dispatch, visibilityOptions: .device)
            }
            producer.endEncoding()

            if frameIndex.isMultiple(of: 2) {
                commandBuffer.endCommandBuffer()
                queue.commit([commandBuffer])
                commandBuffer.beginCommandBuffer(allocator: allocator)
            }

            let consumer = try #require(commandBuffer.makeComputeCommandEncoder())
            if frameIndex.isMultiple(of: 2) {
                consumer.barrier(afterQueueStages: .blit, beforeStages: .dispatch, visibilityOptions: .device)
            }
            consumer.setComputePipelineState(pipeline)
            table.setAddress(buffers[0].gpuAddress, index: 0)
            table.setAddress(buffers[1].gpuAddress, index: 1)
            consumer.setArgumentTable(table)
            consumer.dispatchThreads(threadsPerGrid: MTLSize(width: 64, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
            table.setAddress(buffers[2].gpuAddress, index: 1)
            consumer.setArgumentTable(table)
            consumer.dispatchThreads(threadsPerGrid: MTLSize(width: 64, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
            consumer.barrier(afterEncoderStages: .dispatch, beforeEncoderStages: .blit, visibilityOptions: .device)
            consumer.copy(sourceBuffer: buffers[1], sourceOffset: 0, destinationBuffer: buffers[3], destinationOffset: 0, size: 256)
            consumer.endEncoding()
            commandBuffer.endCommandBuffer()

            let feedback = await withCheckedContinuation { continuation in
                let options = MTL4CommitOptions()
                options.addFeedbackHandler { feedback in
                    continuation.resume(returning: (feedback.gpuStartTime, feedback.gpuEndTime, feedback.error?.localizedDescription))
                }
                queue.commit([commandBuffer], options: options)
                queue.signalEvent(event, value: UInt64(frameIndex))
            }
            await event.valueSignaled(UInt64(frameIndex))
            #expect(feedback.2 == nil)
            #expect(feedback.0 > 0)
            #expect(feedback.1 >= feedback.0)
            let expected = UInt32(frameIndex) * 0x01010101 + 1
            for buffer in buffers.dropFirst() {
                let values = buffer.contents().bindMemory(to: UInt32.self, capacity: 64)
                for index in 0..<64 {
                    #expect(values[index] == expected)
                }
            }
        }
    }

    @Test
    func metalFXCapabilities() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            Issue.record("Metal 4 probes require OS 26 or later")
            return
        }
        let device = try #require(MTLCreateSystemDefaultDevice())
        #expect(MTLFXSpatialScalerDescriptor.supportsMetal4FX(device))
        #if !os(visionOS)
        #expect(MTLFXTemporalScalerDescriptor.supportsMetal4FX(device))
        #endif
    }
}
