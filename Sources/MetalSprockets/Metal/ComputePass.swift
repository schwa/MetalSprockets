import Metal
import MetalSprocketsSupport

// MARK: - ComputePass

/// A container that opens a Metal 4 compute encoder for its content.
///
/// Contains ``ComputePipeline``s with ``ComputeDispatch``es, and pipeline-free ``ComputeCommand``s such as copies.
/// Commands in one pass are not ordered against each other unless you add an ``EncoderBarrier``.
public struct ComputePass <Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    internal let label: String?
    internal let content: Content

    public init(label: String? = nil, @ElementBuilder content: () throws -> Content) throws {
        self.label = label
        self.content = try content()
    }

    func workloadEnter(_ node: Node) throws {
        logger?.verbose?.info("Enter compute pass: \(label ?? "<unlabeled>") (\(node.element.internalDescription))")
        let scope = try node.environmentValues.recordingScope.orThrow(.withHint(.missingEnvironment("recordingScope"), hint: "Compute passes run inside a root such as Runner, OffscreenRenderer or RenderView."))
        let pass = try scope.beginComputePass()
        node.environmentValues.computePassEncoder = pass
        node.environmentValues.computeCommandEncoder = pass.encoder
        if let label {
            try pass.setLabel(label)
        }
        try pass.beginTimestamps(node.environmentValues.timestampRequest)
    }

    // Also runs while unwinding a thrown traversal, so the encoder always ends before the recording is discarded.
    func workloadExit(_ node: Node) throws {
        guard let pass = node.environmentValues.computePassEncoder, let scope = node.environmentValues.recordingScope else {
            return
        }
        node.environmentValues.computePassEncoder = nil
        node.environmentValues.computeCommandEncoder = nil
        try pass.endTimestamps(node.environmentValues.timestampRequest)
        try scope.endComputePass(pass, producerBarrier: node.environmentValues.passProducerBarrier)
        logger?.verbose?.info("Exit compute pass: \(label ?? "<unlabeled>") (\(node.element.internalDescription))")
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

// MARK: - ComputePipeline

/// A compute pipeline compiled through the Metal 4 compiler. Linked functions come from ``Element/linkedFunctions(_:)``.
public struct ComputePipeline <Content>: Element, SetupElement, BodylessContentElement where Content: Element {
    private let label: String?
    private let computeKernel: ComputeKernel
    internal let content: Content

    public init(label: String? = nil, computeKernel: ComputeKernel, @ElementBuilder content: () throws -> Content) throws {
        self.label = label
        self.computeKernel = computeKernel
        self.content = try content()
    }

    func setupEnter(_ node: Node) throws {
        let context = try node.environmentValues.metalContext.orThrow(.missingEnvironment("metalContext"))
        // The context cache makes re-running setup cheap and recompiles only when identity changes.
        let pipeline = try context.pipelines.computePipeline(kernel: computeKernel, linkedFunctions: node.environmentValues.linkedFunctions ?? [], label: label)
        node.environmentValues.computePipeline = pipeline
        node.environmentValues.computePipelineState = pipeline.state
        node.environmentValues.reflection = pipeline.reflection
    }

    nonisolated func requiresSetup(comparedTo old: ComputePipeline<Content>) -> Bool {
        // Always re-run setup; the context cache decides whether anything recompiles.
        true
    }
}
