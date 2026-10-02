import Metal
import MetalSprocketsSupport

internal extension MSEnvironmentValues {
    // The open pass scopes, published by RenderPass and ComputePass.
    @MSEntry var computePassEncoder: ComputePassEncoder?
    @MSEntry var renderPassEncoder: RenderPassEncoder?
    @MSEntry var passProducerBarrier: ProducerBarrier?
}

/// Orders work inside one pass: commands after this barrier wait for `after` stages of earlier commands in the pass.
///
/// Metal 4 does not track hazards, so dependent commands in one ``ComputePass`` or ``RenderPass`` need a barrier:
///
/// ```swift
/// ComputePass {
///     ComputeCommand { $0.fill(buffer: source, range: 0..<16, value: 1) }
///     EncoderBarrier(after: .blit, before: .blit)
///     ComputeCommand { $0.copy(sourceBuffer: source, sourceOffset: 0, destinationBuffer: destination, destinationOffset: 0, size: 16) }
/// }
/// ```
public struct EncoderBarrier: Element, WorkloadElement {
    public typealias Body = Never
    let after: MTLStages
    let before: MTLStages
    var visibility: MTL4VisibilityOptions = .device

    public init(after: MTLStages, before: MTLStages, visibility: MTL4VisibilityOptions = .device) {
        self.after = after
        self.before = before
        self.visibility = visibility
    }

    func workloadEnter(_ node: Node) throws {
        if let pass = node.environmentValues.computePassEncoder {
            try pass.barrier(after: after, before: before, visibility: visibility)
        } else if let pass = node.environmentValues.renderPassEncoder {
            try pass.barrier(after: after, before: before, visibility: visibility)
        } else {
            throw MetalSprocketsError.configurationError("EncoderBarrier must be placed inside an active Metal 4 render or compute pass.")
        }
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

/// Makes the rest of this pass wait for `after` stages of all earlier work on the queue, including earlier passes and
/// earlier submissions. Use it at the start of a pass that consumes what an earlier pass produced.
public struct QueueBarrier: Element, WorkloadElement {
    public typealias Body = Never
    let after: MTLStages
    let before: MTLStages
    var visibility: MTL4VisibilityOptions = .device

    public init(after: MTLStages, before: MTLStages, visibility: MTL4VisibilityOptions = .device) {
        self.after = after
        self.before = before
        self.visibility = visibility
    }

    func workloadEnter(_ node: Node) throws {
        if let pass = node.environmentValues.computePassEncoder {
            try pass.queueBarrier(after: after, before: before, visibility: visibility)
        } else if let pass = node.environmentValues.renderPassEncoder {
            try pass.queueBarrier(after: after, before: before, visibility: visibility)
        } else {
            throw MetalSprocketsError.configurationError("QueueBarrier must be placed inside an active Metal 4 render or compute pass.")
        }
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

private struct PassProducerBarrierModifier<Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var barrier: ProducerBarrier

    func workloadEnter(_ node: Node) throws {
        node.environmentValues.passProducerBarrier = barrier
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

public extension Element {
    /// Ends each pass inside this element with a producer barrier: later queue work at `beforeQueueStages` waits for
    /// this pass's `after` stages.
    ///
    /// Use it on the pass that produces something a later pass reads (the alternative is a ``QueueBarrier`` at the
    /// start of the consumer):
    ///
    /// ```swift
    /// try ComputePass { ... }
    ///     .barrierAfterPass(after: .dispatch, beforeQueueStages: .fragment)
    /// try RenderPass { ... }   // samples what the compute pass wrote
    /// ```
    func barrierAfterPass(after: MTLStages, beforeQueueStages: MTLStages, visibility: MTL4VisibilityOptions = .device) -> some Element {
        PassProducerBarrierModifier(content: self, barrier: ProducerBarrier(after: after, beforeQueueStages: beforeQueueStages, visibility: visibility))
    }
}
