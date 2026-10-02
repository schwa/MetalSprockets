import Metal
@testable import MetalSprockets
import Testing

@MainActor
@Suite("Metal 4 compiler pipeline cache", .requiresMetal4)
struct PipelineCacheTests {
    private static func source(offset: Int) -> String {
        """
        #include <metal_stdlib>
        using namespace metal;
        constant uint addend [[function_constant(0)]];
        kernel void evaluate(device uint *output [[buffer(0)]], constant uint &base [[buffer(1)]], uint index [[thread_position_in_grid]]) {
            output[index] = base + addend + \(offset);
        }
        struct VertexIn { float2 position [[attribute(0)]]; };
        vertex float4 vertex_main(VertexIn input [[stage_in]], constant float4 &offset [[buffer(1)]]) { return float4(input.position, 0, 1) + offset; }
        fragment float4 fragment_main(constant float4 &color [[buffer(0)]]) { return color; }
        """
    }

    private func kernel(_ library: any MTLLibrary, addend: UInt32) throws -> ComputeKernel {
        var constants = FunctionConstants()
        constants["addend"] = .uint32(addend)
        return try ComputeKernel(library: library, name: "evaluate", constants: constants)
    }

    @Test
    func computePipelinesAreCompiledOnceAndCarryReflection() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try device.makeLibrary(source: Self.source(offset: 0), options: nil)
        let first = try context.pipelines.computePipeline(kernel: kernel(library, addend: 1))
        let again = try context.pipelines.computePipeline(kernel: kernel(library, addend: 1))
        #expect(first.state === again.state)
        #expect(context.pipelines.compilationCount == 1)
        #expect(first.bindings.index(of: "output", stage: .kernel) == 0)
        #expect(first.bindings.index(of: "base", stage: .kernel) == 1)
        let changed = try context.pipelines.computePipeline(kernel: kernel(library, addend: 2))
        #expect(changed.state !== first.state)
        #expect(context.pipelines.compilationCount == 2)
    }

    @Test
    func sameNamedFunctionsFromDifferentLibrariesDoNotAlias() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let firstLibrary = try device.makeLibrary(source: Self.source(offset: 0), options: nil)
        let secondLibrary = try device.makeLibrary(source: Self.source(offset: 0), options: nil)
        let first = try context.pipelines.computePipeline(kernel: kernel(firstLibrary, addend: 1))
        let second = try context.pipelines.computePipeline(kernel: kernel(secondLibrary, addend: 1))
        #expect(first.state !== second.state)
        #expect(context.pipelines.compilationCount == 2)
    }

    @Test
    func renderPipelineIdentityCoversAttachmentsSampleCountAndVertexLayout() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try device.makeLibrary(source: Self.source(offset: 0), options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        let layout = try #require(vertex.inferredVertexDescriptor())
        func configuration(color: MTLPixelFormat = .bgra8Unorm, depth: MTLPixelFormat = .depth32Float, samples: Int = 1, vertexDescriptor: MTLVertexDescriptor? = layout) -> RenderPipelineConfiguration {
            RenderPipelineConfiguration(vertex: vertex, fragment: fragment, colorPixelFormats: [color], depthPixelFormat: depth, rasterSampleCount: samples, vertexDescriptor: vertexDescriptor)
        }
        let base = try context.pipelines.renderPipeline(configuration())
        #expect(try context.pipelines.renderPipeline(configuration()).state === base.state)
        #expect(base.bindings.index(of: "offset", stage: .vertex) == 1)
        #expect(base.bindings.index(of: "color", stage: .fragment) == 0)
        #expect(base.bindings.index(of: "color", stage: .vertex) == nil)
        #expect(context.pipelines.compilationCount == 1)
        _ = try context.pipelines.renderPipeline(configuration(color: .rgba16Float))
        _ = try context.pipelines.renderPipeline(configuration(samples: 4))
        _ = try context.pipelines.renderPipeline(configuration(depth: .invalid))
        let otherLayout = try #require(layout.copy() as? MTLVertexDescriptor)
        otherLayout.layouts[0].stride = 16
        _ = try context.pipelines.renderPipeline(configuration(vertexDescriptor: otherLayout))
        #expect(context.pipelines.compilationCount == 5)
        // An equal but distinct vertex descriptor must still hit the cache.
        let equalLayout = try #require(layout.copy() as? MTLVertexDescriptor)
        _ = try context.pipelines.renderPipeline(configuration(vertexDescriptor: equalLayout))
        #expect(context.pipelines.compilationCount == 5)
    }

    @Test
    func mismatchedDevicesAreRejectedBeforeCompilation() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        #expect(context.pipelines.compilationCount == 0)
        #expect(throws: (any Error).self) {
            try PipelineCache.validateDevice(expected: ObjectIdentifier(device), actual: ObjectIdentifier(context), label: "test")
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func compiledComputePipelineProducesSpecializedOutput() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try await device.makeLibrary(source: Self.source(offset: 100), options: nil)
        let pipeline = try context.pipelines.computePipeline(kernel: kernel(library, addend: 5))
        let output = try #require(device.makeBuffer(length: 16 * 4, options: .storageModeShared))
        let tableDescriptor = MTL4ArgumentTableDescriptor()
        tableDescriptor.maxBufferBindCount = 2
        let table = try device.makeArgumentTable(descriptor: tableDescriptor)
        let recording = try context.submit { scope in
            try scope.retainAllocation(output)
            let base = try scope.scratch(UInt32(1_000))
            table.setAddress(output.gpuAddress, index: try #require(pipeline.bindings.index(of: "output", stage: .kernel)))
            table.setAddress(base.gpuAddress, index: try #require(pipeline.bindings.index(of: "base", stage: .kernel)))
            try scope.withComputeEncoder { encoder in
                encoder.setComputePipelineState(pipeline.state)
                encoder.setArgumentTable(table)
                encoder.dispatchThreads(threadsPerGrid: MTLSize(width: 16, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 1, depth: 1))
            }
        }
        let submission = recording
        #expect(try await context.awaitResult(submission).outcome == .completed)
        let values = output.contents().bindMemory(to: UInt32.self, capacity: 16)
        #expect((0..<16).allSatisfy { values[$0] == 1_105 })
    }
}
