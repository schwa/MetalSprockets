import Metal

// TODO: #22 Make into actual Modifier.
internal struct RenderPassDescriptorModifier<Content>: Element, BodylessElement, BodylessContentElement, EnvironmentModifyingElement where Content: Element {
    var content: Content
    var modify: (MTLRenderPassDescriptor) -> Void

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    // Runs in configureNode so the modified descriptor is inherited by children. The descriptor is
    // read from the parent's environment because the node's own copy may be stale from last frame.
    func configureNodeBodyless(_ node: Node) throws {
        guard let system = System.current else {
            fatalError("RenderPassDescriptorModifier: No System is currently active.")
        }

        let parent = system.traversalContext.parentNode
        guard let renderPassDescriptor = parent?.environmentValues.renderPassDescriptor ?? node.environmentValues.renderPassDescriptor else {
            fatalError("RenderPassDescriptorModifier: renderPassDescriptor not available.")
        }

        let copy = renderPassDescriptor.copyWithType(MTLRenderPassDescriptor.self)
        modify(copy)
        node.environmentValues.renderPassDescriptor = copy
        // Recompute after the caller's mutations so the published formats match the descriptor.
        node.environmentValues.renderAttachmentFormats = RenderAttachmentFormats(copy)
    }

    nonisolated func requiresSetup(comparedTo old: RenderPassDescriptorModifier<Content>) -> Bool {
        false
    }
}

public extension Element {
    func renderPassDescriptorModifier(_ modify: @escaping (MTLRenderPassDescriptor) -> Void) -> some Element {
        RenderPassDescriptorModifier(content: self, modify: modify)
    }
}
