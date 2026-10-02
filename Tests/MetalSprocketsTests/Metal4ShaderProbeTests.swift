import Foundation
import Metal
@testable import MetalSprockets
import MetalSupport
import Testing

@Suite("Metal 4 shader probes", .enabled(if: ProcessInfo.processInfo.environment["METALSPROCKETS_METAL4_PROBES"] == "1"))
struct Metal4ShaderProbeTests {
    @Test
    func libraryIdentitySpecializationAndVisibleFunctions() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            Issue.record("Metal 4 probes require OS 26 or later")
            return
        }
        let device = try #require(MTLCreateSystemDefaultDevice())
        try #require(device.supportsFamily(.metal4))
        try #require(device.supportsFunctionPointers)
        let queue = try device.makeMTL4CommandQueue(descriptor: MTL4CommandQueueDescriptor())
        let compiler = try device.makeCompiler(descriptor: MTL4CompilerDescriptor())
        let event = try #require(device.makeSharedEvent())
        var submissionIdentifier: UInt64 = 0

        for libraryOffset in [10, 100] {
            let library = try device.makeLibrary(source: """
            #include <metal_stdlib>
            using namespace metal;
            constant uint addedValue [[function_constant(0)]];
            constant uint transformOffset [[function_constant(1)]];
            using Transform = uint(uint);
            [[visible]] uint transform(uint value) { return value + \(libraryOffset) + transformOffset; }
            kernel void evaluate(device uint *output [[buffer(0)]], visible_function_table<Transform> functions [[buffer(1)]], uint index [[thread_position_in_grid]]) {
                output[index] = functions[0](index) + functions[1](index) + addedValue;
            }
            struct VertexInput { float2 position [[attribute(0)]]; };
            vertex float4 vertex_main(VertexInput input [[stage_in]]) {
                return float4(input.position, 0, 1);
            }
            """, options: nil)
            let metadata = try #require(library.makeFunction(name: "evaluate"))
            #expect(metadata.functionType == .kernel)
            let declared = metadata.functionConstantInfos
            #expect(declared["addedValue"]?.index == 0)
            #expect(declared["addedValue"]?.dataType == .uint)
            let vertexMetadata = try #require(library.makeFunction(name: "vertex_main"))
            let vertexDescriptor = try #require(vertexMetadata.inferredVertexDescriptor())
            #expect(vertexDescriptor.attributes[0].format == .float2)

            for bias in [UInt32(3), UInt32(7)] {
                var constants = FunctionConstants()
                constants["addedValue"] = .uint32(bias)
                let kernel = try ComputeKernel(library: library, name: "evaluate", constants: constants)
                let specialized = try kernel.reference.makeFunctionDescriptor()
                var visibleConstants = FunctionConstants()
                visibleConstants["transformOffset"] = .uint32(11)
                let firstVisible = try VisibleFunction(library: library, name: "transform", constants: visibleConstants, specializedName: "transformEleven")
                visibleConstants["transformOffset"] = .uint32(19)
                let secondVisible = try VisibleFunction(library: library, name: "transform", constants: visibleConstants, specializedName: "transformNineteen")
                let linking = MTL4StaticLinkingDescriptor()
                linking.functionDescriptors = try [firstVisible, secondVisible].map { try $0.reference.makeFunctionDescriptor() }
                let descriptor = MTL4ComputePipelineDescriptor()
                descriptor.computeFunctionDescriptor = specialized
                descriptor.staticLinkingDescriptor = linking
                let options = MTL4PipelineOptions()
                options.shaderReflection = .bindingInfo
                descriptor.options = options
                let pipeline = try compiler.makeComputePipelineState(descriptor: descriptor)
                let reflection = try #require(pipeline.reflection)
                #expect(reflection.bindings.contains { $0.name == "output" && $0.index == 0 })
                #expect(reflection.bindings.contains { $0.name == "functions" && $0.index == 1 })

                let visibleDescriptor = MTLVisibleFunctionTableDescriptor()
                visibleDescriptor.functionCount = 2
                let visibleTable = try #require(pipeline.makeVisibleFunctionTable(descriptor: visibleDescriptor))
                let firstHandle = try #require(pipeline.functionHandle(withName: "transformEleven"))
                let secondHandle = try #require(pipeline.functionHandle(withName: "transformNineteen"))
                visibleTable.setFunction(firstHandle, index: 0)
                visibleTable.setFunction(secondHandle, index: 1)
                let output = try #require(device.makeBuffer(length: 32 * MemoryLayout<UInt32>.stride, options: .storageModeShared))
                let tableDescriptor = MTL4ArgumentTableDescriptor()
                tableDescriptor.maxBufferBindCount = 2
                let table = try device.makeArgumentTable(descriptor: tableDescriptor)
                table.setAddress(output.gpuAddress, index: 0)
                table.setResource(visibleTable.gpuResourceID, bufferIndex: 1)
                let residency = try device.makeResidencySet(descriptor: MTLResidencySetDescriptor())
                residency.addAllocations([output, visibleTable])
                residency.commit()

                let allocator = try device.makeCommandAllocator(descriptor: MTL4CommandAllocatorDescriptor())
                let commandBuffer = try #require(device.makeCommandBuffer())
                commandBuffer.beginCommandBuffer(allocator: allocator)
                commandBuffer.useResidencySet(residency)
                let encoder = try #require(commandBuffer.makeComputeCommandEncoder())
                encoder.setComputePipelineState(pipeline)
                encoder.setArgumentTable(table)
                encoder.dispatchThreads(threadsPerGrid: MTLSize(width: 32, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
                encoder.endEncoding()
                commandBuffer.endCommandBuffer()
                queue.commit([commandBuffer])
                submissionIdentifier += 1
                queue.signalEvent(event, value: submissionIdentifier)
                try #require(event.wait(untilSignaledValue: submissionIdentifier, timeoutMS: 5_000))
                let result = output.contents().bindMemory(to: UInt32.self, capacity: 32)
                for index in 0..<32 {
                    #expect(result[index] == UInt32(2 * (index + libraryOffset)) + 30 + bias)
                }
            }
        }
    }
}
