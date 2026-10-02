import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import os
import Testing

@MainActor
@Suite("Metal 4 core element contracts", .requiresMetal4)
struct CoreContractTests {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    kernel void write_value(device uint *output [[buffer(0)]], constant uint &value [[buffer(1)]], uint index [[thread_position_in_grid]]) {
        output[index] = value;
    }
    vertex float4 fullscreen(uint id [[vertex_id]]) {
        const float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};
        return float4(positions[id], 0, 1);
    }
    fragment float4 solid(constant float4 &color [[buffer(0)]]) { return color; }
    """

    private struct Fixture {
        let device: any MTLDevice
        let context: MetalContext
        let library: any MTLLibrary
        let kernel: ComputeKernel
        let vertex: VertexShader
        let fragment: FragmentShader
    }

    private func fixture() throws -> Fixture {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(source: Self.source, options: nil)
        return Fixture(
            device: device,
            context: try MetalContext(device: device),
            library: library,
            kernel: try ComputeKernel(library: library, name: "write_value"),
            vertex: try VertexShader(library: library, name: "fullscreen"),
            fragment: try FragmentShader(library: library, name: "solid")
        )
    }

    private func target(_ device: any MTLDevice, format: MTLPixelFormat = .bgra8Unorm) throws -> (any MTLTexture, MTL4RenderPassDescriptor) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: 4, height: 4, mipmapped: false)
        descriptor.usage = .renderTarget
        descriptor.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        return (texture, pass)
    }

    private func pixel(_ texture: any MTLTexture) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&bytes, bytesPerRow: texture.width * texture.pixelFormat.bytesPerPixel, from: MTLRegionMake2D(1, 1, 1, 1), mipmapLevel: 0)
        return bytes
    }

    @Test(.timeLimit(.minutes(1)))
    func pipelineElementsCompileInSetupOnceAndDispatchWithScopedParameters() async throws {
        let fixture = try fixture()
        let output = try #require(fixture.device.makeBuffer(length: 8 * 4, options: .storageModeShared))
        let system = System()
        func frame(_ value: UInt32) throws -> some Element {
            try ComputePass {
                try ComputePipeline(computeKernel: fixture.kernel) {
                    try ComputeDispatch(threadsPerGrid: MTLSize(width: 8, height: 1, depth: 1))
                        .parameter("value", value: value)
                }
                .parameter("output", buffer: output)
            }
        }
        for value in [UInt32(7), 8, 9] {
            let submission = try await fixture.context.run(frame(value), system: system)
            #expect(try await submission.waitForResult().outcome == .completed)
            let values = output.contents().bindMemory(to: UInt32.self, capacity: 8)
            #expect((0..<8).allSatisfy { values[$0] == value })
        }
        #expect(fixture.context.pipelines.compilationCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func siblingParameterScopesAreIsolatedAndInnerOverridesOuter() async throws {
        let fixture = try fixture()
        let first = try #require(fixture.device.makeBuffer(length: 4, options: .storageModeShared))
        let second = try #require(fixture.device.makeBuffer(length: 4, options: .storageModeShared))
        let content = try ComputePass {
            try ComputePipeline(computeKernel: fixture.kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1))
                    .parameter("output", buffer: first)
                    .parameter("value", value: UInt32(111))
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1))
                    .parameter("output", buffer: second)
            }
            .parameter("value", value: UInt32(222))
        }
        let submission = try await fixture.context.run(content, system: System())
        #expect(try await submission.waitForResult().outcome == .completed)
        #expect(first.contents().load(as: UInt32.self) == 111)
        #expect(second.contents().load(as: UInt32.self) == 222)
    }

    @Test(.timeLimit(.minutes(1)))
    func renderPipelinesFollowPassFormatsAndRecompileOnlyWhenTheyChange() async throws {
        let fixture = try fixture()
        let system = System()
        let (bgra, bgraPass) = try target(fixture.device)
        let (rgba, rgbaPass) = try target(fixture.device, format: .rgba8Unorm)
        func frame(_ pass: MTL4RenderPassDescriptor, color: SIMD4<Float>) throws -> some Element {
            try RenderPass {
                try RenderPipeline(vertexShader: fixture.vertex, fragmentShader: fixture.fragment) {
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                        .parameter("color", value: color)
                }
            }.renderPassDescriptor(pass)
        }
        for _ in 0..<2 {
            let submission = try await fixture.context.run(frame(bgraPass, color: [0, 0, 1, 1]), system: system)
            #expect(try await submission.waitForResult().outcome == .completed)
        }
        #expect(fixture.context.pipelines.compilationCount == 1)
        #expect(pixel(bgra) == [255, 0, 0, 255])
        let submission = try await fixture.context.run(frame(rgbaPass, color: [0, 0, 1, 1]), system: system)
        #expect(try await submission.waitForResult().outcome == .completed)
        #expect(fixture.context.pipelines.compilationCount == 2)
        #expect(pixel(rgba) == [0, 0, 255, 255])
    }

    @Test(.timeLimit(.minutes(1)))
    func descriptorModifiersApplyToACopyAndNeverLeakToSiblings() async throws {
        let fixture = try fixture()
        let (first, firstPass) = try target(fixture.device)
        let (second, secondPass) = try target(fixture.device)
        firstPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        secondPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        let content = try Group {
            try RenderPass {}
                .renderPassDescriptorModifier { $0.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 1, blue: 0, alpha: 1) }
                .renderPassDescriptor(firstPass)
            try RenderPass {}.renderPassDescriptor(secondPass)
        }
        let submission = try await fixture.context.run(content, system: System())
        #expect(try await submission.waitForResult().outcome == .completed)
        #expect(pixel(first) == [0, 255, 0, 255])
        #expect(pixel(second) == [0, 0, 0, 255])
        // The caller's descriptor is never mutated.
        #expect(firstPass.colorAttachments[0].clearColor.green == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func computeCommandsResourceDeclarationsAndBarriersComposeInTrees() async throws {
        let fixture = try fixture()
        let source = try #require(fixture.device.makeBuffer(length: 16, options: .storageModeShared))
        let destination = try #require(fixture.device.makeBuffer(length: 16, options: .storageModeShared))
        let content = try ComputePass {
            ComputeCommand { $0.fill(buffer: source, range: 0..<16, value: 0x33) }
            EncoderBarrier(after: .blit, before: .blit)
            ComputeCommand { $0.copy(sourceBuffer: source, sourceOffset: 0, destinationBuffer: destination, destinationOffset: 0, size: 16) }
        }
        .useResources([source, destination])
        let recording = try fixture.context.submit(content, system: System())
        #expect(fixture.context.residencySet.containsAllocation(source))
        #expect(fixture.context.residencySet.containsAllocation(destination))
        #expect(try await fixture.context.awaitResult(recording).outcome == .completed)
        #expect(UnsafeRawBufferPointer(start: destination.contents(), count: 16).allSatisfy { $0 == 0x33 })
    }

    @Test(.timeLimit(.minutes(1)))
    func resultCallbacksFromTheTreeFireOnceAfterCommitNotification() async throws {
        let fixture = try fixture()
        let events = OSAllocatedUnfairLock<[String]>(initialState: [])
        fixture.context.onSubmissionCommitted { _, _ in events.withLock { $0.append("committed") } }
        let content = try ComputePass {
            ComputeCommand { _ in }
        }
        .onSubmissionTerminated { result in events.withLock { $0.append("terminated \(result.outcome == .completed)") } }
        let submission = try fixture.context.submit(content, system: System())
        _ = try await fixture.context.awaitResult(submission)
        try await fixture.context.drain()
        #expect(events.withLock { $0 } == ["committed", "terminated true"])
    }

    @Test(.timeLimit(.minutes(1)))
    func indirectDispatchAndIndexedVertexBuffersComposeInTrees() async throws {
        let fixture = try fixture()
        let library = try await fixture.device.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;
        struct VertexIn { float2 position [[attribute(0)]]; float4 color [[attribute(1)]]; };
        struct VertexOut { float4 position [[position]]; float4 color; };
        vertex VertexOut streams(VertexIn input [[stage_in]]) { return { float4(input.position, 0, 1), input.color }; }
        fragment float4 passthrough(VertexOut input [[stage_in]]) { return input.color; }
        """, options: nil)
        let layout = MTLVertexDescriptor()
        layout.attributes[0].format = .float2
        layout.attributes[0].bufferIndex = 0
        layout.attributes[1].format = .float4
        layout.attributes[1].bufferIndex = 5
        layout.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride
        layout.layouts[5].stride = MemoryLayout<SIMD4<Float>>.stride
        let positions: [SIMD2<Float>] = [[-1, -1], [3, -1], [-1, 3]]
        let colors = [SIMD4<Float>](repeating: [1, 0, 0, 1], count: 3)
        let positionBuffer = try #require(fixture.device.makeBuffer(bytes: positions, length: MemoryLayout<SIMD2<Float>>.stride * 3, options: .storageModeShared))
        let colorBuffer = try #require(fixture.device.makeBuffer(bytes: colors, length: MemoryLayout<SIMD4<Float>>.stride * 3, options: .storageModeShared))
        let output = try #require(fixture.device.makeBuffer(length: 64 * 4, options: .storageModeShared))
        var arguments = MTLDispatchThreadgroupsIndirectArguments(threadgroupsPerGrid: (4, 1, 1))
        let indirect = try #require(fixture.device.makeBuffer(bytes: &arguments, length: MemoryLayout<MTLDispatchThreadgroupsIndirectArguments>.size, options: .storageModeShared))
        let (texture, pass) = try target(fixture.device)
        let vertex = try VertexShader(library: library, name: "streams")
        let fragment = try FragmentShader(library: library, name: "passthrough")
        let content = try Group {
            try ComputePass {
                try ComputePipeline(label: "indirect", computeKernel: fixture.kernel) {
                    try ComputeDispatch(indirectBuffer: indirect, indirectBufferOffset: 0, threadsPerThreadgroup: MTLSize(width: 16, height: 1, depth: 1))
                }
                .parameter("output", buffer: output)
                .parameter("value", value: UInt32(42))
            }.barrierAfterPass(after: .dispatch, beforeQueueStages: .fragment)
            try RenderPass {
                try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                }.vertexDescriptor(layout)
                .vertexBuffer(positionBuffer, index: 0)
                .vertexBuffer(colorBuffer, index: 5)
            }.renderPassDescriptor(pass)
        }
        let submission = try await fixture.context.run(content, system: System())
        #expect(try await submission.waitForResult().outcome == .completed)
        let values = output.contents().bindMemory(to: UInt32.self, capacity: 64)
        #expect((0..<64).allSatisfy { values[$0] == 42 })
        #expect(pixel(texture) == [0, 0, 255, 255])
    }

    @Test
    func candidateElementsReportMissingContextAndMisplacement() throws {
        #expect(throws: MetalSprocketsError.self) {
            try System().render(root: try ComputePass { ComputeCommand { _ in } })
        }
        let fixture = try fixture()
        #expect(throws: MetalSprocketsError.self) {
            try fixture.context.submit(try ComputeDispatch(threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1)), system: System())
        }
        #expect(throws: MetalSprocketsError.self) {
            try fixture.context.submit(try ComputePass { try ComputeDispatch(threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1)) }, system: System())
        }
        #expect(fixture.context.inFlightCount == 0)
    }
}

private extension MTLPixelFormat {
    var bytesPerPixel: Int { 4 }
}
