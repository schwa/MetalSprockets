import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

/// Records its position in the compute pass log, standing in for any command element.
private struct FillMarker: Element, WorkloadElement {
    typealias Body = Never
    let buffer: any MTLBuffer
    let value: UInt8

    func workloadEnter(_ node: Node) throws {
        let pass = try node.environmentValues.computePassEncoder.orThrow(.missingEnvironment("computePassEncoder"))
        try pass.fill(buffer, range: 0..<4, value: value)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

@MainActor
@Suite("Metal 4 barriers", .requiresMetal4)
struct BarrierTests {
    private func buffer(_ device: any MTLDevice) throws -> any MTLBuffer {
        try #require(device.makeBuffer(length: 64, options: .storageModeShared))
    }

    @Test
    func stageMasksAreValidatedPerEncoderKind() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        func expectInvalid(_ encode: @escaping (ComputePassEncoder) throws -> Void) {
            #expect(throws: EncodingFailure.self) { try context.submit { try $0.withComputePass(encode) } }
        }
        expectInvalid { try $0.barrier(after: [], before: .dispatch) }
        expectInvalid { try $0.barrier(after: .fragment, before: .dispatch) }
        expectInvalid { try $0.queueBarrier(after: .blit, before: .vertex) }
        expectInvalid { try $0.queueBarrier(after: [], before: .dispatch) }
        // Queue barriers may wait on stages from other encoder kinds.
        try context.submit { try $0.withComputePass { try $0.queueBarrier(after: .fragment, before: .dispatch) } }.waitUntilCompleted()
        try context.retireCompletedSubmissions()
        #expect(context.inFlightCount == 0)
    }

    @Test
    func elementsEmitBarriersAtTheirTraversalPositionAcrossTreeShapes() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let buffer = try buffer(device)
        let system = System()
        var log: [ComputePassEncoder.Operation] = []
        func run(_ content: some Element) throws {
            var finishedPass: ComputePassEncoder?
            let recording = try context.submit { scope in
                try scope.withComputePass(producerBarrier: .init(after: .blit, beforeQueueStages: .dispatch)) { pass in
                    try system.render(root: content.environment(\.computePassEncoder, pass))
                    finishedPass = pass
                }
            }
            // The producer barrier is emitted after pass content, so read the log once the pass has ended.
            log = try #require(finishedPass).operations
            try context.waitForResult(recording)
            try context.retireCompletedSubmissions()
        }
        let tree = try Group {
            FillMarker(buffer: buffer, value: 1)
            EncoderBarrier(after: .blit, before: .blit)
            ForEach([2, 3], id: \.self) { value in
                QueueBarrier(after: .dispatch, before: .blit)
                FillMarker(buffer: buffer, value: UInt8(value))
            }
            FillMarker(buffer: buffer, value: 9).workloadEnabled(false)
            EncoderBarrier(after: .dispatch, before: .blit).workloadEnabled(false)
        }
        // Run twice: reused nodes must still emit barrier workload every frame.
        for _ in 0..<2 {
            try run(tree)
            #expect(log == [
                .fill, .encoderBarrier(after: .blit, before: .blit),
                .queueBarrier(after: .dispatch, before: .blit), .fill,
                .queueBarrier(after: .dispatch, before: .blit), .fill,
                .producerBarrier(after: .blit, beforeQueueStages: .dispatch)
            ])
        }
    }

    @Test
    func conditionalBranchesEmitOnlyTheActiveBarrier() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        for useFirst in [true, false] {
            var log: [ComputePassEncoder.Operation] = []
            let recording = try context.submit { scope in
                try scope.withComputePass { pass in
                    let content = try Group {
                        if useFirst {
                            EncoderBarrier(after: .blit, before: .dispatch)
                        } else {
                            QueueBarrier(after: .fragment, before: .dispatch)
                        }
                    }
                    try System().render(root: content.environment(\.computePassEncoder, pass))
                    log = pass.operations
                }
            }
            try context.waitForResult(recording)
            try context.retireCompletedSubmissions()
            #expect(log == [useFirst ? .encoderBarrier(after: .blit, before: .dispatch) : .queueBarrier(after: .fragment, before: .dispatch)])
        }
    }

    @Test
    func barriersOutsideAnActivePassAreConfigurationErrors() throws {
        #expect(throws: MetalSprocketsError.self) {
            try System().render(root: EncoderBarrier(after: .blit, before: .dispatch))
        }
        #expect(throws: MetalSprocketsError.self) {
            try System().render(root: QueueBarrier(after: .blit, before: .dispatch))
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func sameQueueSubmissionsOrderedByProducerAndConsumerBarriers() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let source = try buffer(device)
        let destination = try buffer(device)
        for value in [UInt8(5), UInt8(77)] {
            let producer = try context.submit { scope in
                try scope.withComputePass(producerBarrier: .init(after: .blit, beforeQueueStages: .blit)) { try $0.fill(source, range: 0..<64, value: value) }
            }
            let consumer = try context.submit { scope in
                try scope.withComputePass { pass in
                    try pass.queueBarrier(after: .blit, before: .blit)
                    try pass.copy(from: source, sourceOffset: 0, to: destination, destinationOffset: 0, size: 64)
                }
            }
            _ = producer
            let submission = consumer
            #expect(try await context.awaitResult(submission).outcome == .completed)
            #expect(UnsafeRawBufferPointer(start: destination.contents(), count: 64).allSatisfy { $0 == value })
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func crossQueueDependenciesUseExplicitEvents() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let producerContext = try MetalContext(device: device)
        let consumerContext = try MetalContext(device: device)
        let event = try #require(device.makeSharedEvent())
        let source = try buffer(device)
        let destination = try buffer(device)
        // The consumer is committed first; only the event wait orders it after the producer on another queue.
        consumerContext.waitForEvent(event, value: 1)
        let consumerRecording = try consumerContext.submit { scope in
            try scope.withComputePass { try $0.copy(from: source, sourceOffset: 0, to: destination, destinationOffset: 0, size: 64) }
        }
        let consumer = consumerRecording
        let producerRecording = try producerContext.submit { scope in
            try scope.withComputePass { try $0.fill(source, range: 0..<64, value: 0x5a) }
        }
        let producer = producerRecording
        producerContext.signalEvent(event, value: 1)
        #expect(try await producerContext.awaitResult(producer).outcome == .completed)
        #expect(try await consumerContext.awaitResult(consumer).outcome == .completed)
        #expect(UnsafeRawBufferPointer(start: destination.contents(), count: 64).allSatisfy { $0 == 0x5a })
    }

    @Test(.timeLimit(.minutes(1)))
    func renderPassBarriersOrderComputeProducedData() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let library = try await device.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;
        vertex float4 vertex_main(uint id [[vertex_id]]) {
            const float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};
            return float4(positions[id], 0, 1);
        }
        fragment float4 fragment_main(constant uchar4 &color [[buffer(0)]]) { return float4(color) / 255.0; }
        """, options: nil)
        let pipeline = try context.pipelines.renderPipeline(RenderPipelineConfiguration(vertex: VertexShader(library: library, name: "vertex_main"), fragment: FragmentShader(library: library, name: "fragment_main"), colorPixelFormats: [.rgba8Unorm]))
        let color = try buffer(device)
        let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        targetDescriptor.usage = .renderTarget
        targetDescriptor.storageMode = .shared
        let target = try #require(device.makeTexture(descriptor: targetDescriptor))
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        var parameters = ParameterSet()
        parameters.set("color", buffer: color)
        var log: [RenderPassEncoder.Operation] = []
        let recording = try context.submit { scope in
            try scope.withComputePass { try $0.fill(color, range: 0..<4, value: 0xff) }
            try scope.withRenderPass(descriptor: pass) { renderPass in
                try System().render(root: QueueBarrier(after: .blit, before: .fragment).environment(\.renderPassEncoder, renderPass))
                try renderPass.draw(pipeline, parameters: parameters) { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                log = renderPass.operations
            }
        }
        #expect(log == [.queueBarrier(after: .blit, before: .fragment), .draw])
        #expect(try await context.awaitResult(recording).outcome == .completed)
        var pixel = [UInt8](repeating: 0, count: 4)
        target.getBytes(&pixel, bytesPerRow: 16, from: MTLRegionMake2D(1, 1, 1, 1), mipmapLevel: 0)
        #expect(pixel == [255, 255, 255, 255])
    }
}
