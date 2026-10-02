import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("Metal 4 encoding scopes", .requiresMetal4)
struct EncodingTests {
    private enum TestFailure: Error {
        case encoding
    }

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    kernel void write_index(device uint *output [[buffer(0)]], constant uint &base [[buffer(1)]], uint index [[thread_position_in_grid]]) {
        output[index] = base + index;
    }
    vertex float4 vertex_main(uint id [[vertex_id]], constant float2 *positions [[buffer(0)]]) {
        return float4(positions[id], 0, 1);
    }
    fragment float4 fragment_main(constant float4 &color [[buffer(0)]]) { return color; }
    """

    private struct Fixture {
        let device: any MTLDevice
        let context: MetalContext
        let library: any MTLLibrary
    }

    private func fixture() throws -> Fixture {
        let device = try #require(MTLCreateSystemDefaultDevice())
        return Fixture(device: device, context: try MetalContext(device: device), library: try device.makeLibrary(source: Self.source, options: nil))
    }

    private func target(_ device: any MTLDevice) throws -> (any MTLTexture, MTL4RenderPassDescriptor) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 8, height: 8, mipmapped: false)
        descriptor.usage = .renderTarget
        descriptor.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        pass.colorAttachments[0].storeAction = .store
        return (texture, pass)
    }

    private func pixel(_ texture: any MTLTexture, x: Int = 4, y: Int = 4) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&bytes, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
        return bytes
    }

    @Test(.timeLimit(.minutes(1)))
    func copyOnlyComputePassNeedsNoPipelineAndRegistersResources() async throws {
        let fixture = try fixture()
        let source = try #require(fixture.device.makeBuffer(length: 64, options: .storageModeShared))
        let destination = try #require(fixture.device.makeBuffer(length: 64, options: .storageModeShared))
        let recording = try fixture.context.submit { scope in
            try scope.withComputePass { pass in
                try pass.fill(source, range: 0..<64, value: 0x2a)
                try pass.barrier(after: .blit, before: .blit)
                try pass.copy(from: source, sourceOffset: 16, to: destination, destinationOffset: 0, size: 32)
            }
        }
        #expect(fixture.context.residencySet.containsAllocation(source))
        #expect(fixture.context.residencySet.containsAllocation(destination))
        #expect(try await fixture.context.awaitResult(recording).outcome == .completed)
        let bytes = UnsafeRawBufferPointer(start: destination.contents(), count: 64)
        #expect(bytes[0..<32].allSatisfy { $0 == 0x2a })
        #expect(bytes[32..<64].allSatisfy { $0 == 0 })
    }

    @Test
    func copyAndFillRangesAreValidated() throws {
        let fixture = try fixture()
        let buffer = try #require(fixture.device.makeBuffer(length: 16, options: .storageModeShared))
        func expectFailure(_ encode: @escaping (ComputePassEncoder) throws -> Void) {
            #expect(throws: EncodingFailure.self) {
                try fixture.context.submit { scope in try scope.withComputePass(encode) }
            }
        }
        expectFailure { try $0.fill(buffer, range: 8..<32, value: 0) }
        expectFailure { try $0.fill(buffer, range: 4..<4, value: 0) }
        expectFailure { try $0.copy(from: buffer, sourceOffset: 12, to: buffer, destinationOffset: 0, size: 8) }
        #expect(fixture.context.inFlightCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func dispatchesBindThePipelineAndParametersIncludingIndirectArguments() async throws {
        let fixture = try fixture()
        let pipeline = try fixture.context.pipelines.computePipeline(kernel: ComputeKernel(library: fixture.library, name: "write_index"))
        let direct = try #require(fixture.device.makeBuffer(length: 100 * 4, options: .storageModeShared))
        let indirectOutput = try #require(fixture.device.makeBuffer(length: 64 * 4, options: .storageModeShared))
        var arguments = MTLDispatchThreadgroupsIndirectArguments(threadgroupsPerGrid: (4, 1, 1))
        let indirect = try #require(fixture.device.makeBuffer(length: 64, options: .storageModeShared))
        (indirect.contents() + 16).copyMemory(from: &arguments, byteCount: MemoryLayout<MTLDispatchThreadgroupsIndirectArguments>.size)
        var directParameters = ParameterSet()
        directParameters.set("output", buffer: direct)
        directParameters.set("base", value: UInt32(10))
        var indirectParameters = ParameterSet()
        indirectParameters.set("output", buffer: indirectOutput)
        indirectParameters.set("base", value: UInt32(500))
        let recording = try fixture.context.submit { scope in
            try scope.withComputePass { pass in
                // A non-uniform grid with an automatically derived threadgroup size.
                try pass.dispatch(pipeline, parameters: directParameters, grid: .threads(MTLSize(width: 100, height: 1, depth: 1)))
                try pass.dispatch(pipeline, parameters: indirectParameters, grid: .indirect(indirect, offset: 16), threadsPerThreadgroup: MTLSize(width: 16, height: 1, depth: 1))
            }
        }
        #expect(fixture.context.residencySet.containsAllocation(indirect))
        #expect(try await fixture.context.awaitResult(recording).outcome == .completed)
        let directValues = direct.contents().bindMemory(to: UInt32.self, capacity: 100)
        #expect((0..<100).allSatisfy { directValues[$0] == UInt32(10 + $0) })
        let indirectValues = indirectOutput.contents().bindMemory(to: UInt32.self, capacity: 64)
        #expect((0..<64).allSatisfy { indirectValues[$0] == UInt32(500 + $0) })
    }

    @Test
    func indirectArgumentsMustBeAlignedAndInRange() throws {
        let fixture = try fixture()
        let pipeline = try fixture.context.pipelines.computePipeline(kernel: ComputeKernel(library: fixture.library, name: "write_index"))
        let indirect = try #require(fixture.device.makeBuffer(length: 16, options: .storageModeShared))
        let output = try #require(fixture.device.makeBuffer(length: 16, options: .storageModeShared))
        var parameters = ParameterSet()
        parameters.set("output", buffer: output)
        parameters.set("base", value: UInt32(0))
        for offset in [2, 8, -4] {
            #expect(throws: EncodingFailure.self) {
                try fixture.context.submit { scope in
                    try scope.withComputePass { try $0.dispatch(pipeline, parameters: parameters, grid: .indirect(indirect, offset: offset)) }
                }
            }
        }
        #expect(fixture.context.inFlightCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func drawsBindPipelineAndSupportIndexedGPUAddresses() async throws {
        let fixture = try fixture()
        let pipeline = try fixture.context.pipelines.renderPipeline(RenderPipelineConfiguration(
            vertex: VertexShader(library: fixture.library, name: "vertex_main"),
            fragment: FragmentShader(library: fixture.library, name: "fragment_main"),
            colorPixelFormats: [.rgba8Unorm]
        ))
        let positions: [SIMD2<Float>] = [[-1, -1], [3, -1], [-1, 3], [0, 0]]
        let positionBuffer = try #require(fixture.device.makeBuffer(bytes: positions, length: MemoryLayout<SIMD2<Float>>.stride * positions.count, options: .storageModeShared))
        let indices: [UInt16] = [9, 9, 0, 1, 2]
        let indexBuffer = try #require(fixture.device.makeBuffer(bytes: indices, length: 10, options: .storageModeShared))
        let (first, firstPass) = try target(fixture.device)
        let (second, secondPass) = try target(fixture.device)
        var red = ParameterSet()
        red.set("positions", buffer: positionBuffer)
        red.set("color", value: SIMD4<Float>(1, 0, 0, 1))
        var green = ParameterSet()
        green.set("positions", buffer: positionBuffer)
        green.set("color", value: SIMD4<Float>(0, 1, 0, 1))
        let recording = try fixture.context.submit { scope in
            try scope.withRenderPass(descriptor: firstPass) { pass in
                // The closure only draws: the framework has already bound pipeline and arguments.
                try pass.draw(pipeline, parameters: red) { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
            }
            try scope.withRenderPass(descriptor: secondPass) { pass in
                // Skip the two leading sentinel indices with a byte offset.
                try pass.drawIndexed(pipeline, parameters: green, primitiveType: .triangle, indices: IndexBuffer(buffer: indexBuffer, type: .uint16, indexCount: 3, offset: 4))
            }
        }
        #expect(fixture.context.residencySet.containsAllocation(first))
        #expect(fixture.context.residencySet.containsAllocation(indexBuffer))
        #expect(try await fixture.context.awaitResult(recording).outcome == .completed)
        #expect(pixel(first) == [255, 0, 0, 255])
        #expect(pixel(second) == [0, 255, 0, 255])
    }

    @Test
    func indexRangesAreValidated() throws {
        let fixture = try fixture()
        let pipeline = try fixture.context.pipelines.renderPipeline(RenderPipelineConfiguration(
            vertex: VertexShader(library: fixture.library, name: "vertex_main"),
            fragment: FragmentShader(library: fixture.library, name: "fragment_main"),
            colorPixelFormats: [.rgba8Unorm]
        ))
        let indexBuffer = try #require(fixture.device.makeBuffer(length: 12, options: .storageModeShared))
        let positions = try #require(fixture.device.makeBuffer(length: 64, options: .storageModeShared))
        var parameters = ParameterSet()
        parameters.set("positions", buffer: positions)
        parameters.set("color", value: SIMD4<Float>(1, 1, 1, 1))
        let (_, descriptor) = try target(fixture.device)
        for (count, type, offset) in [(4, MTLIndexType.uint32, 0), (2, .uint32, 2), (7, .uint16, 0)] {
            #expect(throws: EncodingFailure.self) {
                try fixture.context.submit { scope in
                    try scope.withRenderPass(descriptor: descriptor) { pass in
                        try pass.drawIndexed(pipeline, parameters: parameters, primitiveType: .triangle, indices: IndexBuffer(buffer: indexBuffer, type: type, indexCount: count, offset: offset))
                    }
                }
            }
        }
        #expect(fixture.context.inFlightCount == 0)
    }

    @Test
    func passesRejectNestingEscapeAndUnwindOnErrors() throws {
        let fixture = try fixture()
        let buffer = try #require(fixture.device.makeBuffer(length: 16, options: .storageModeShared))
        #expect(throws: RecordingScope.Failure.nestedEncoder) {
            try fixture.context.submit { scope in
                try scope.withComputePass { _ in try scope.withComputePass { _ in } }
            }
        }
        var escaped: ComputePassEncoder?
        let recording = try fixture.context.submit { scope in
            try scope.withComputePass { escaped = $0 }
        }
        #expect(throws: EncodingFailure.passEnded) { try #require(escaped).fill(buffer, range: 0..<4, value: 1) }
        try fixture.context.waitForResult(recording)
        try fixture.context.retireCompletedSubmissions()
        let (_, descriptor) = try target(fixture.device)
        #expect(throws: TestFailure.encoding) {
            try fixture.context.submit { scope in
                try scope.withRenderPass(descriptor: descriptor) { _ in throw TestFailure.encoding }
            }
        }
        #expect(fixture.context.inFlightCount == 0)
        #expect(fixture.context.completionEvent.signaledValue == recording.identifier)
    }
}
