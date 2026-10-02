import Metal
import MetalSprocketsSupport

internal struct IndexBuffer {
    let buffer: any MTLBuffer
    let type: MTLIndexType
    let indexCount: Int
    var offset = 0

    /// The GPU address and byte length of the indexed range, after checking it lies inside the buffer.
    func validatedRange() throws -> (address: MTLGPUAddress, length: Int) {
        let indexSize = type == .uint16 ? 2 : 4
        let length = indexCount * indexSize
        guard indexCount >= 1, offset >= 0, offset.isMultiple(of: indexSize), offset + length <= buffer.length else {
            throw EncodingFailure.invalidRange("\(indexCount) indices at offset \(offset) exceed index buffer length \(buffer.length)")
        }
        return (buffer.gpuAddress + UInt64(offset), length)
    }
}

internal enum EncodingFailure: Error, Equatable {
    case passEnded
    case invalidRange(String)
    case invalidIndirectOffset(Int)
    case unsupportedDevice(String)
    case invalidStages(String)
}

/// A producer barrier emitted when a pass ends, ordering later encoders on the same queue after this whole pass.
internal struct ProducerBarrier {
    let after: MTLStages
    let beforeQueueStages: MTLStages
    var visibility: MTL4VisibilityOptions = .device
}

private enum StageValidation {
    static let compute: MTLStages = [.dispatch, .blit, .accelerationStructure]
    static let render: MTLStages = [.vertex, .fragment, .tile, .object, .mesh]

    static func requireNonempty(_ stages: MTLStages, _ label: String) throws {
        guard !stages.isEmpty else {
            throw EncodingFailure.invalidStages("\(label) stages must not be empty")
        }
    }

    static func require(_ stages: MTLStages, within allowed: MTLStages, _ label: String) throws {
        try requireNonempty(stages, label)
        guard allowed.isSuperset(of: stages) else {
            throw EncodingFailure.invalidStages("\(label) stages include stages this encoder cannot encode")
        }
    }
}

/// An open compute encoder. Valid only inside its `withComputePass` closure.
internal final class ComputePassEncoder {
    enum Grid {
        case threads(MTLSize)
        case threadgroups(MTLSize)
        case indirect(any MTLBuffer, offset: Int)
    }

    /// The commands this pass encoded, in order. Lets callers and tests verify traversal ordering.
    enum Operation: Equatable {
        case dispatch
        case command
        case fill
        case copy
        case encoderBarrier(after: MTLStages, before: MTLStages)
        case queueBarrier(after: MTLStages, before: MTLStages)
        case producerBarrier(after: MTLStages, beforeQueueStages: MTLStages)
    }

    let encoder: any MTL4ComputeCommandEncoder
    private let scope: RecordingScope
    fileprivate var isActive = true
    private(set) var operations: [Operation] = []
    // Last pipeline bound on the encoder, to skip redundant setComputePipelineState. nil forces the next set.
    private var boundPipeline: ObjectIdentifier?

    fileprivate init(encoder: any MTL4ComputeCommandEncoder, scope: RecordingScope) {
        self.encoder = encoder
        self.scope = scope
    }

    func dispatch(_ pipeline: PipelineCache.ComputePipeline, parameters: ParameterSet, grid: Grid, threadsPerThreadgroup: MTLSize? = nil) throws {
        let encoder = try activeEncoder()
        let tables = try parameters.makeTables(for: pipeline.bindings, stages: [.kernel], functionTables: pipeline.functionTables, pipelineLabel: pipeline.state.label, scope: scope)
        let pipelineID = ObjectIdentifier(pipeline.state)
        if boundPipeline != pipelineID {
            encoder.setComputePipelineState(pipeline.state)
            boundPipeline = pipelineID
        }
        encoder.setArgumentTable(tables[.kernel])
        switch grid {
        case .threads(let size):
            guard pipeline.state.device.supportsFamily(.apple4) else {
                throw EncodingFailure.unsupportedDevice("Non-uniform threadgroups require Apple GPU Family 4 or later")
            }
            let group = threadsPerThreadgroup ?? ComputeDispatch.automaticThreadsPerThreadgroup(for: pipeline.state, gridSize: size)
            encoder.dispatchThreads(threadsPerGrid: size, threadsPerThreadgroup: group)
        case .threadgroups(let count):
            let group = threadsPerThreadgroup ?? ComputeDispatch.automaticThreadsPerThreadgroup(for: pipeline.state, gridSize: nil)
            encoder.dispatchThreadgroups(threadgroupsPerGrid: count, threadsPerThreadgroup: group)
        case let .indirect(buffer, offset):
            let length = MemoryLayout<MTLDispatchThreadgroupsIndirectArguments>.size
            guard offset >= 0, offset.isMultiple(of: 4), offset + length <= buffer.length else {
                throw EncodingFailure.invalidIndirectOffset(offset)
            }
            try scope.retainAllocation(buffer)
            let group = threadsPerThreadgroup ?? ComputeDispatch.automaticThreadsPerThreadgroup(for: pipeline.state, gridSize: nil)
            encoder.dispatchThreadgroups(indirectBuffer: buffer.gpuAddress + UInt64(offset), threadsPerThreadgroup: group)
        }
        operations.append(.dispatch)
    }

    /// Pipeline-free raw access. Declare every referenced allocation on the recording scope.
    func command(_ encode: (any MTL4ComputeCommandEncoder) throws -> Void) throws {
        let encoder = try activeEncoder()
        // The closure has raw access and may bind its own pipeline, so the cache is no longer trustworthy.
        boundPipeline = nil
        try encode(encoder)
        operations.append(.command)
    }

    func fill(_ buffer: any MTLBuffer, range: Range<Int>, value: UInt8) throws {
        let encoder = try activeEncoder()
        guard !range.isEmpty, range.lowerBound >= 0, range.upperBound <= buffer.length else {
            throw EncodingFailure.invalidRange("fill \(range) exceeds buffer length \(buffer.length)")
        }
        try scope.retainAllocation(buffer)
        encoder.fill(buffer: buffer, range: range, value: value)
        operations.append(.fill)
    }

    func copy(from source: any MTLBuffer, sourceOffset: Int, to destination: any MTLBuffer, destinationOffset: Int, size: Int) throws {
        let encoder = try activeEncoder()
        guard size > 0, sourceOffset >= 0, destinationOffset >= 0, sourceOffset + size <= source.length, destinationOffset + size <= destination.length else {
            throw EncodingFailure.invalidRange("copy of \(size) bytes exceeds a buffer")
        }
        try scope.retainAllocation(source)
        try scope.retainAllocation(destination)
        encoder.copy(sourceBuffer: source, sourceOffset: sourceOffset, destinationBuffer: destination, destinationOffset: destinationOffset, size: size)
        operations.append(.copy)
    }

    /// Orders later commands in this pass after earlier ones. Defaults to device visibility for resource dependencies.
    func barrier(after: MTLStages, before: MTLStages, visibility: MTL4VisibilityOptions = .device) throws {
        let encoder = try activeEncoder()
        try StageValidation.require(after, within: StageValidation.compute, "Encoder barrier after")
        try StageValidation.require(before, within: StageValidation.compute, "Encoder barrier before")
        encoder.barrier(afterEncoderStages: after, beforeEncoderStages: before, visibilityOptions: visibility)
        operations.append(.encoderBarrier(after: after, before: before))
    }

    /// Orders later commands in this pass after earlier encoders on the same queue, including earlier submissions.
    func queueBarrier(after: MTLStages, before: MTLStages, visibility: MTL4VisibilityOptions = .device) throws {
        let encoder = try activeEncoder()
        try StageValidation.requireNonempty(after, "Queue barrier after")
        try StageValidation.require(before, within: StageValidation.compute, "Queue barrier before")
        encoder.barrier(afterQueueStages: after, beforeStages: before, visibilityOptions: visibility)
        operations.append(.queueBarrier(after: after, before: before))
    }

    fileprivate func emitProducerBarrier(_ barrier: ProducerBarrier) throws {
        let encoder = try activeEncoder()
        try StageValidation.require(barrier.after, within: StageValidation.compute, "Producer barrier after")
        try StageValidation.requireNonempty(barrier.beforeQueueStages, "Producer barrier before")
        encoder.barrier(afterStages: barrier.after, beforeQueueStages: barrier.beforeQueueStages, visibilityOptions: barrier.visibility)
        operations.append(.producerBarrier(after: barrier.after, beforeQueueStages: barrier.beforeQueueStages))
    }

    func writeTimestamp(into heap: any MTL4CounterHeap, index: Int) throws {
        try activeEncoder().writeTimestamp(granularity: .precise, counterHeap: heap, index: index)
    }

    func pushDebugGroup(_ label: String) throws { try activeEncoder().pushDebugGroup(label) }
    func popDebugGroup() throws { try activeEncoder().popDebugGroup() }
    func setLabel(_ label: String) throws { try activeEncoder().label = label }

    private func activeEncoder() throws -> any MTL4ComputeCommandEncoder {
        guard isActive else {
            throw EncodingFailure.passEnded
        }
        return encoder
    }
}

/// An open render encoder. Valid only inside its `withRenderPass` closure.
internal final class RenderPassEncoder {
    enum Operation: Equatable {
        case draw
        case encoderBarrier(after: MTLStages, before: MTLStages)
        case queueBarrier(after: MTLStages, before: MTLStages)
        case producerBarrier(after: MTLStages, beforeQueueStages: MTLStages)
    }

    let encoder: any MTL4RenderCommandEncoder
    private let scope: RecordingScope
    fileprivate var isActive = true
    /// Whether an earlier draw in this pass set a non-default viewport or scissor, which the next draw must undo.
    var viewportOverridden = false
    var scissorOverridden = false
    private(set) var operations: [Operation] = []
    // Last state bound on the encoder, to skip redundant sets that flood MTL_DEBUG_LAYER. nil forces the next set.
    // Only state the library binds (never the raw Draw closure) is cached here; cull/fill/winding/amplification are
    // reset every draw because a Draw closure may set them (see Draw).
    private var boundPipeline: ObjectIdentifier?
    private var boundDepthStencil: ObjectIdentifier?
    private var boundDepthBias: DepthBias?
    private var boundStencilReference: UInt32?

    fileprivate init(encoder: any MTL4RenderCommandEncoder, scope: RecordingScope) {
        self.encoder = encoder
        self.scope = scope
    }

    /// Pipeline-free raw access, for work such as compositor-drawn masks. Nothing is bound first.
    func command(_ encode: (any MTL4RenderCommandEncoder) throws -> Void) throws {
        let encoder = try activeEncoder()
        // The closure has raw access and may bind its own state, so the cache is no longer trustworthy.
        invalidateStateCache()
        try encode(encoder)
        operations.append(.draw)
    }

    /// Binds per-draw depth/stencil state, skipping any that already matches the encoder. Called by `Draw` before its
    /// geometry closure. These are library-owned, so the cache stays valid across draws.
    func applyDrawState(depthStencil: any MTLDepthStencilState, bias: DepthBias, stencilReference: UInt32) throws {
        let encoder = try activeEncoder()
        let depthStencilID = ObjectIdentifier(depthStencil)
        if boundDepthStencil != depthStencilID {
            encoder.setDepthStencilState(depthStencil)
            boundDepthStencil = depthStencilID
        }
        if boundDepthBias != bias {
            encoder.setDepthBias(bias.bias, slopeScale: bias.slopeScale, clamp: bias.clamp)
            boundDepthBias = bias
        }
        if boundStencilReference != stencilReference {
            encoder.setStencilReferenceValue(stencilReference)
            boundStencilReference = stencilReference
        }
    }

    private func invalidateStateCache() {
        boundPipeline = nil
        boundDepthStencil = nil
        boundDepthBias = nil
        boundStencilReference = nil
    }

    /// Binds the pipeline and its argument tables, then hands the encoder to `encode` for draw calls.
    func draw(_ pipeline: PipelineCache.RenderPipeline, parameters: ParameterSet, _ encode: (any MTL4RenderCommandEncoder) throws -> Void) throws {
        try encode(try bind(pipeline, parameters: parameters))
        operations.append(.draw)
    }

    func drawIndexed(_ pipeline: PipelineCache.RenderPipeline, parameters: ParameterSet, primitiveType: MTLPrimitiveType, indices: IndexBuffer) throws {
        let range = try indices.validatedRange()
        let encoder = try bind(pipeline, parameters: parameters)
        try scope.retainAllocation(indices.buffer)
        encoder.drawIndexedPrimitives(primitiveType: primitiveType, indexCount: indices.indexCount, indexType: indices.type, indexBuffer: range.address, indexBufferLength: range.length)
        operations.append(.draw)
    }

    func barrier(after: MTLStages, before: MTLStages, visibility: MTL4VisibilityOptions = .device) throws {
        let encoder = try activeEncoder()
        try StageValidation.require(after, within: StageValidation.render, "Encoder barrier after")
        try StageValidation.require(before, within: StageValidation.render, "Encoder barrier before")
        encoder.barrier(afterEncoderStages: after, beforeEncoderStages: before, visibilityOptions: visibility)
        operations.append(.encoderBarrier(after: after, before: before))
    }

    func queueBarrier(after: MTLStages, before: MTLStages, visibility: MTL4VisibilityOptions = .device) throws {
        let encoder = try activeEncoder()
        try StageValidation.requireNonempty(after, "Queue barrier after")
        try StageValidation.require(before, within: StageValidation.render, "Queue barrier before")
        encoder.barrier(afterQueueStages: after, beforeStages: before, visibilityOptions: visibility)
        operations.append(.queueBarrier(after: after, before: before))
    }

    fileprivate func emitProducerBarrier(_ barrier: ProducerBarrier) throws {
        let encoder = try activeEncoder()
        try StageValidation.require(barrier.after, within: StageValidation.render, "Producer barrier after")
        try StageValidation.requireNonempty(barrier.beforeQueueStages, "Producer barrier before")
        encoder.barrier(afterStages: barrier.after, beforeQueueStages: barrier.beforeQueueStages, visibilityOptions: barrier.visibility)
        operations.append(.producerBarrier(after: barrier.after, beforeQueueStages: barrier.beforeQueueStages))
    }

    private func bind(_ pipeline: PipelineCache.RenderPipeline, parameters: ParameterSet) throws -> any MTL4RenderCommandEncoder {
        let encoder = try activeEncoder()
        let tables = try parameters.makeTables(for: pipeline.bindings, stages: pipeline.stages, functionTables: pipeline.functionTables, pipelineLabel: pipeline.state.label, scope: scope)
        let pipelineID = ObjectIdentifier(pipeline.state)
        if boundPipeline != pipelineID {
            encoder.setRenderPipelineState(pipeline.state)
            boundPipeline = pipelineID
        }
        for stage in pipeline.stages {
            encoder.setArgumentTable(tables[stage], stages: FunctionTables.renderStage(stage))
        }
        return encoder
    }

    /// Before any draw, the timestamp is taken before `stage` begins; after draws, once earlier draws finish `stage`.
    func writeTimestamp(afterStage stage: MTLRenderStages, into heap: any MTL4CounterHeap, index: Int) throws {
        try activeEncoder().writeTimestamp(granularity: .precise, after: stage, counterHeap: heap, index: index)
    }

    func pushDebugGroup(_ label: String) throws { try activeEncoder().pushDebugGroup(label) }
    func popDebugGroup() throws { try activeEncoder().popDebugGroup() }
    func setLabel(_ label: String) throws { try activeEncoder().label = label }

    private func activeEncoder() throws -> any MTL4RenderCommandEncoder {
        guard isActive else {
            throw EncodingFailure.passEnded
        }
        return encoder
    }
}

extension RecordingScope {
    /// Opens a compute pass. A producer barrier, when given, is emitted after all pass content and before the encoder ends.
    func withComputePass(producerBarrier: ProducerBarrier? = nil, _ encode: (ComputePassEncoder) throws -> Void) throws {
        let pass = try beginComputePass()
        do {
            try encode(pass)
        } catch {
            abandonComputePass(pass)
            throw error
        }
        try endComputePass(pass, producerBarrier: producerBarrier)
    }

    /// Opens a render pass and registers its attachments for residency and lifetime.
    func withRenderPass(descriptor: MTL4RenderPassDescriptor, producerBarrier: ProducerBarrier? = nil, _ encode: (RenderPassEncoder) throws -> Void) throws {
        let pass = try beginRenderPass(descriptor: descriptor)
        do {
            try encode(pass)
        } catch {
            abandonRenderPass(pass)
            throw error
        }
        try endRenderPass(pass, producerBarrier: producerBarrier)
    }

    // Begin/end pairs let a pass stay open across element traversal, where a closure cannot.

    func beginComputePass() throws -> ComputePassEncoder {
        ComputePassEncoder(encoder: try beginComputeEncoder(), scope: self)
    }

    /// Ends a pass after successful encoding, emitting its producer barrier last.
    func endComputePass(_ pass: ComputePassEncoder, producerBarrier: ProducerBarrier?) throws {
        defer {
            pass.isActive = false
            endEncoder(pass.encoder)
        }
        if let producerBarrier {
            try pass.emitProducerBarrier(producerBarrier)
        }
    }

    /// Ends a pass during error unwinding without emitting its producer barrier.
    func abandonComputePass(_ pass: ComputePassEncoder) {
        pass.isActive = false
        endEncoder(pass.encoder)
    }

    func beginRenderPass(descriptor: MTL4RenderPassDescriptor) throws -> RenderPassEncoder {
        for index in 0..<8 {
            let attachment = descriptor.colorAttachments[index]
            try [attachment?.texture, attachment?.resolveTexture].compactMap(\.self).forEach { try retainAllocation($0) }
        }
        try [descriptor.depthAttachment.texture, descriptor.depthAttachment.resolveTexture, descriptor.stencilAttachment.texture, descriptor.stencilAttachment.resolveTexture].compactMap(\.self).forEach { try retainAllocation($0) }
        return RenderPassEncoder(encoder: try beginRenderEncoder(descriptor: descriptor), scope: self)
    }

    /// `end` replaces the plain `endEncoding()`, for owners such as the visionOS compositor that end the encoder.
    func endRenderPass(_ pass: RenderPassEncoder, producerBarrier: ProducerBarrier?, end: ((any MTL4RenderCommandEncoder) -> Void)? = nil) throws {
        defer {
            pass.isActive = false
            if let end {
                end(pass.encoder)
                encoderEnded()
            } else {
                endEncoder(pass.encoder)
            }
        }
        if let producerBarrier {
            try pass.emitProducerBarrier(producerBarrier)
        }
    }

    func abandonRenderPass(_ pass: RenderPassEncoder) {
        pass.isActive = false
        endEncoder(pass.encoder)
    }
}
