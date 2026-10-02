// Embedded Metal source in multi-line string literals uses continuation alignment the rule can't account for.
// swiftlint:disable indentation_width
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("Metal 4 argument tables", .requiresMetal4)
struct ArgumentBindingTests {
    private static let computeSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct Pair { uint first; uint second; };
    kernel void sparse(device uint *output [[buffer(0)]],
                       constant Pair &pair [[buffer(5)]],
                       constant uint *values [[buffer(3)]],
                       texture2d<float, access::read> image [[texture(4)]],
                       uint index [[thread_position_in_grid]]) {
        output[index] = pair.first + pair.second + values[index] + uint(image.read(uint2(0, 0)).r * 255.0);
    }
    kernel void simple(device uint *output [[buffer(0)]], uint index [[thread_position_in_grid]]) {
        output[index] = 1;
    }
    kernel void arraySample(device uint *output [[buffer(0)]],
                            array<texture2d<float, access::read>, 3> images [[texture(0)]],
                            uint index [[thread_position_in_grid]]) {
        output[index] = uint(images[index].read(uint2(0, 0)).r * 255.0);
    }
    """

    private static let renderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexIn { float2 position [[attribute(0)]]; float4 color [[attribute(1)]]; };
    struct VertexOut { float4 position [[position]]; float4 color; };
    vertex VertexOut vertex_main(VertexIn input [[stage_in]], constant float &scale [[buffer(7)]]) {
        return { float4(input.position * scale, 0, 1), input.color };
    }
    fragment float4 fragment_main(VertexOut input [[stage_in]], constant float &scale [[buffer(2)]]) {
        return input.color * scale;
    }
    """

    private func texture(_ device: any MTLDevice, value: UInt8) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 1, height: 1, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        var byte = value
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &byte, bytesPerRow: 1)
        return texture
    }

    @Test(arguments: ["Cube", nil] as [String?])
    func argumentTableLabelsIncludeThePipelineAndStage(_ label: String?) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try device.makeLibrary(source: Self.computeSource, options: nil)
        let pipeline = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "simple"), label: label)
        let reflection = try #require(pipeline.state.reflection)
        let stages: [MTLFunctionType] = [.vertex, .fragment, .kernel, .object, .mesh]
        let names = ["Vertex", "Fragment", "Compute", "Object", "Mesh"]
        let bindings = PipelineBindings(stages.map { ($0, reflection.bindings) })
        let submission = try context.submit { scope in
            let tables = try ParameterSet().makeTables(for: bindings, stages: stages, pipelineLabel: label, scope: scope)
            for (stage, name) in zip(stages, names) {
                #expect(tables[stage]?.label == "\(label ?? "MetalSprockets"): \(name) Arguments")
            }
            #expect(Set(tables.values.map(ObjectIdentifier.init)).count == stages.count)
        }
        #expect(try context.waitForResult(submission).outcome == .completed)
    }

    @Test
    func tablesAreSizedFromSparseReflectedSlots() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try device.makeLibrary(source: Self.computeSource, options: nil)
        let pipeline = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "sparse"))
        let sizes = pipeline.bindings.tableSizes(stage: .kernel)
        #expect(sizes.buffers == 6)
        #expect(sizes.textures == 5)
        #expect(sizes.samplers == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func namedBuffersValuesArraysAndTexturesReachSparseSlots() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try await device.makeLibrary(source: Self.computeSource, options: nil)
        let pipeline = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "sparse"))
        let output = try #require(device.makeBuffer(length: 4 * 4, options: .storageModeShared))
        let image = try texture(device, value: 2)
        var parameters = ParameterSet()
        parameters.set("output", buffer: output)
        parameters.set("pair", value: SIMD2<UInt32>(100, 20))
        parameters.set("values", values: [UInt32(1), 2, 3, 4])
        parameters.set("image", texture: image)
        let recording = try context.submit { scope in
            let tables = try parameters.makeTables(for: pipeline.bindings, stages: [.kernel], scope: scope)
            try scope.withComputeEncoder { encoder in
                encoder.setComputePipelineState(pipeline.state)
                encoder.setArgumentTable(tables[.kernel])
                encoder.dispatchThreads(threadsPerGrid: MTLSize(width: 4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 4, height: 1, depth: 1))
            }
        }
        #expect(context.residencySet.containsAllocation(output))
        #expect(context.residencySet.containsAllocation(image))
        #expect(try await context.awaitResult(recording).outcome == .completed)
        let results = output.contents().bindMemory(to: UInt32.self, capacity: 4)
        #expect((0..<4).map { results[$0] } == [123, 124, 125, 126])
    }

    @Test
    func textureArrayReservesEverySlotAndReflectsArrayLength() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try device.makeLibrary(source: Self.computeSource, options: nil)
        let pipeline = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "arraySample"))
        let sizes = pipeline.bindings.tableSizes(stage: .kernel)
        #expect(sizes.textures == 3)
        let binding = try #require(pipeline.bindings.binding(named: "images", stage: .kernel))
        #expect(binding.arrayLength == 3)
    }

    @Test(.timeLimit(.minutes(1)))
    func namedTextureArrayFillsConsecutiveSlots() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try await device.makeLibrary(source: Self.computeSource, options: nil)
        let pipeline = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "arraySample"))
        let output = try #require(device.makeBuffer(length: 4 * 3, options: .storageModeShared))
        let images = try [UInt8(10), 20, 30].map { try texture(device, value: $0) }
        var parameters = ParameterSet()
        parameters.set("output", buffer: output)
        parameters.set("images", textures: images)
        let recording = try context.submit { scope in
            let tables = try parameters.makeTables(for: pipeline.bindings, stages: [.kernel], scope: scope)
            try scope.withComputeEncoder { encoder in
                encoder.setComputePipelineState(pipeline.state)
                encoder.setArgumentTable(tables[.kernel])
                encoder.dispatchThreads(threadsPerGrid: MTLSize(width: 3, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 3, height: 1, depth: 1))
            }
        }
        for image in images {
            #expect(context.residencySet.containsAllocation(image))
        }
        #expect(try await context.awaitResult(recording).outcome == .completed)
        let results = output.contents().bindMemory(to: UInt32.self, capacity: 3)
        #expect((0..<3).map { results[$0] } == [10, 20, 30])
    }

    @Test
    func textureArrayRejectsMoreTexturesThanTheShaderHolds() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try device.makeLibrary(source: Self.computeSource, options: nil)
        let pipeline = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "arraySample"))
        let output = try #require(device.makeBuffer(length: 4 * 3, options: .storageModeShared))
        let images = try [UInt8(1), 2, 3, 4].map { try texture(device, value: $0) }
        var parameters = ParameterSet()
        parameters.set("output", buffer: output)
        parameters.set("images", textures: images)
        #expect(throws: ParameterSet.Failure.textureArrayTooLong(name: "images", count: 4, capacity: 3)) {
            _ = try context.submit { scope in
                _ = try parameters.makeTables(for: pipeline.bindings, stages: [.kernel], scope: scope)
            }
        }
        #expect(context.inFlightCount == 0)
    }

    @Test
    func diagnosticsDistinguishMissingKindRangeAndOptionalInputs() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try device.makeLibrary(source: Self.computeSource, options: nil)
        let pipeline = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "simple"))
        let output = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        func tables(_ parameters: ParameterSet) throws {
            let recording = try context.submit { scope in
                _ = try parameters.makeTables(for: pipeline.bindings, stages: [.kernel], scope: scope)
            }
            try context.waitForResult(recording)
            try context.retireCompletedSubmissions()
        }
        var missing = ParameterSet()
        missing.set("output", buffer: output)
        missing.set("absent", value: UInt32(1))
        #expect(throws: ParameterSet.Failure.missingBinding("absent")) { try tables(missing) }
        var optional = ParameterSet()
        optional.set("output", buffer: output)
        optional.set("absent", value: UInt32(1), isOptional: true)
        try tables(optional)
        var wrongKind = ParameterSet()
        wrongKind.set("output", texture: try texture(device, value: 1))
        #expect(throws: ParameterSet.Failure.kindMismatch(name: "output", expected: .buffer)) { try tables(wrongKind) }
        var outOfRange = ParameterSet()
        outOfRange.set("output", buffer: output, offset: 64)
        #expect(throws: ParameterSet.Failure.offsetOutOfRange(name: "output", offset: 64, length: 16)) { try tables(outOfRange) }
        var badVertexIndex = ParameterSet()
        badVertexIndex.setVertexBuffer(output, layoutIndex: 31)
        #expect(throws: ParameterSet.Failure.invalidVertexBufferIndex(31)) { try tables(badVertexIndex) }
        #expect(context.inFlightCount == 0)
    }

    @Test
    func everyBindingCallProducesFreshTablesSoStateCannotLeak() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try device.makeLibrary(source: Self.computeSource, options: nil)
        let pipeline = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "sparse"))
        var parameters = ParameterSet()
        parameters.set("image", texture: nil)
        let recording = try context.submit { scope in
            let first = try parameters.makeTables(for: pipeline.bindings, stages: [.kernel], scope: scope)
            let second = try parameters.makeTables(for: pipeline.bindings, stages: [.kernel], scope: scope)
            #expect(first[.kernel] !== second[.kernel])
        }
        try context.waitForResult(recording)
        try context.retireCompletedSubmissions()
    }

    @Test(.timeLimit(.minutes(1)))
    func stageFilteringAndIndexedVertexStreamsRender() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try await device.makeLibrary(source: Self.renderSource, options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        let layout = MTLVertexDescriptor()
        layout.attributes[0].format = .float2
        layout.attributes[0].bufferIndex = 0
        layout.attributes[1].format = .float4
        layout.attributes[1].bufferIndex = 3
        layout.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride
        layout.layouts[3].stride = MemoryLayout<SIMD4<Float>>.stride
        let pipeline = try context.pipelines.renderPipeline(RenderPipelineConfiguration(vertex: vertex, fragment: fragment, colorPixelFormats: [.rgba8Unorm], vertexDescriptor: layout))
        let positions: [SIMD2<Float>] = [[-1, -1], [3, -1], [-1, 3]]
        let colors = [SIMD4<Float>](repeating: [1, 0.5, 0.25, 1], count: 3)
        let positionBuffer = try #require(device.makeBuffer(bytes: positions, length: MemoryLayout<SIMD2<Float>>.stride * 3, options: .storageModeShared))
        let colorBuffer = try #require(device.makeBuffer(bytes: colors, length: MemoryLayout<SIMD4<Float>>.stride * 3, options: .storageModeShared))
        let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 8, height: 8, mipmapped: false)
        targetDescriptor.usage = .renderTarget
        targetDescriptor.storageMode = .shared
        let target = try #require(device.makeTexture(descriptor: targetDescriptor))
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        var parameters = ParameterSet()
        // The same name binds to different slots and values per stage.
        parameters.set("scale", value: Float(1), stages: [.vertex])
        parameters.set("scale", value: Float(0.5), stages: [.fragment])
        parameters.setVertexBuffer(positionBuffer, layoutIndex: 0)
        parameters.setVertexBuffer(colorBuffer, layoutIndex: 3)
        let recording = try context.submit { scope in
            try scope.retainAllocation(target)
            let tables = try parameters.makeTables(for: pipeline.bindings, stages: [.vertex, .fragment], scope: scope)
            try scope.withRenderEncoder(descriptor: pass) { encoder in
                encoder.setRenderPipelineState(pipeline.state)
                encoder.setArgumentTable(tables[.vertex], stages: .vertex)
                encoder.setArgumentTable(tables[.fragment], stages: .fragment)
                encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            }
        }
        #expect(try await context.awaitResult(recording).outcome == .completed)
        var pixel = [UInt8](repeating: 0, count: 4)
        target.getBytes(&pixel, bytesPerRow: 32, from: MTLRegionMake2D(4, 4, 1, 1), mipmapLevel: 0)
        #expect(abs(Int(pixel[0]) - 128) <= 1)
        #expect(abs(Int(pixel[1]) - 64) <= 1)
        #expect(abs(Int(pixel[2]) - 32) <= 1)
    }
}
