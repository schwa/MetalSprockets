import Metal
import MetalSprocketsSupport

#if os(visionOS)
import CompositorServices
#endif

// MARK: - RenderPass

internal protocol RenderPassElement {
}

/// A container that opens a Metal 4 render encoder for its content.
///
/// The pass renders into the environment's ``MSEnvironmentValues/renderPassDescriptor``, which roots such as
/// ``OffscreenRenderer`` and `RenderView` provide. Descriptor modifiers (for example ``Element/msaa(sampleCount:)``)
/// wrap the pass and rewrite a private copy of that descriptor.
///
/// ```swift
/// try RenderPass(label: "Main Scene") {
///     try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///         Draw { encoder in
///             encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
///         }
///     }
/// }
/// ```
public struct RenderPass <Content>: Element, SetupElement, WorkloadElement, BodylessContentElement, RenderPassElement, EnvironmentModifyingElement where Content: Element {
    private let label: String?
    internal let content: Content

    public init(label: String? = nil, @ElementBuilder content: () throws -> Content) throws {
        self.label = label
        self.content = try content()
    }

    func configureNodeBodyless(_ node: Node) throws {
        // Children (including any RenderPipelineDescriptorTransformer) start from a clean pipeline descriptor every
        // frame during the update phase. See #342.
        node.environmentValues.renderPipelineDescriptor = MTL4RenderPipelineDescriptor()
    }

    // Publishes a private copy each frame, before child pipelines compile against its formats.
    func setupEnter(_ node: Node) throws {
        let descriptor = try node.environmentValues.renderPassDescriptor.orThrow(.withHint(.missingEnvironment(\.renderPassDescriptor), hint: "Render passes need a root that supplies a render target, such as OffscreenRenderer or RenderView."))
        let copy = try (descriptor.copy() as? MTL4RenderPassDescriptor).orThrow(.generic("Could not copy the render pass descriptor"))
        node.environmentValues.activeRenderPassDescriptor = copy
        node.environmentValues.renderAttachmentFormats = RenderAttachmentFormats(copy)
    }

    func workloadEnter(_ node: Node) throws {
        logger?.verbose?.info("Enter render pass: \(label ?? "<unlabeled>") (\(node.element.debugName))")
        let scope = try node.environmentValues.recordingScope.orThrow(.withHint(.missingEnvironment("recordingScope"), hint: "Render passes run inside a root such as Runner, OffscreenRenderer or RenderView."))
        let descriptor = try node.environmentValues.activeRenderPassDescriptor.orThrow(.missingEnvironment(\.renderPassDescriptor))
        let pass = try scope.beginRenderPass(descriptor: descriptor)
        node.environmentValues.renderPassEncoder = pass
        node.environmentValues.renderCommandEncoder = pass.encoder
        if let label {
            try pass.setLabel(label)
        }
        try pass.beginTimestamps(node.environmentValues.timestampRequest)
    }

    // Also runs while unwinding a thrown traversal, so the encoder always ends before the recording is discarded.
    func workloadExit(_ node: Node) throws {
        guard let pass = node.environmentValues.renderPassEncoder, let scope = node.environmentValues.recordingScope else {
            return
        }
        node.environmentValues.renderPassEncoder = nil
        node.environmentValues.renderCommandEncoder = nil
        try pass.endTimestamps(node.environmentValues.timestampRequest)
        #if os(visionOS)
        if let renderContext = node.environmentValues.immersiveRenderContext {
            // The compositor ends the encoder itself, after drawing its own content. On device its Metal 4 endEncoding
            // also leaves the command buffer ended (observed on Apple Vision Pro, #434; not documented), so nothing may
            // be encoded after this pass and the recording must not end the buffer again.
            try scope.endRenderPass(pass, producerBarrier: node.environmentValues.passProducerBarrier) { encoder in renderContext.endEncoding(commandEncoder: encoder) }
            scope.markCommandBufferEndedByOwner()
            logger?.verbose?.info("Exit render pass: \(label ?? "<unlabeled>") (\(node.element.debugName))")
            return
        }
        #endif
        try scope.endRenderPass(pass, producerBarrier: node.environmentValues.passProducerBarrier)
        logger?.verbose?.info("Exit render pass: \(label ?? "<unlabeled>") (\(node.element.debugName))")
    }

    nonisolated func requiresSetup(comparedTo old: RenderPass<Content>) -> Bool {
        // Setup only copies the descriptor; always refresh it so resized targets are never stale.
        true
    }
}
