import Metal

// TODO: #22 Make into actual Modifier.
internal struct RenderPassDescriptorModifier<Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var modify: (MTLRenderPassDescriptor) -> Void

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    // Apply modifier during configureNode phase (runs every frame during update).
    // This ensures the modified descriptor is inherited by children.
    // We read from the PARENT's environment to get the fresh descriptor for this frame,
    // since the node's own environment may have a stale cached value.
    func configureNodeBodyless(_ node: Node) throws {
        guard let system = System.current else {
            fatalError("RenderPassDescriptorModifier: No System is currently active.")
        }

        // Get parent's renderPassDescriptor (fresh for this frame)
        let parent = system.activeNodeStack.count >= 2 ? system.activeNodeStack[system.activeNodeStack.count - 2] : nil
        guard let renderPassDescriptor = parent?.environmentValues.renderPassDescriptor ?? node.environmentValues.renderPassDescriptor else {
            fatalError("RenderPassDescriptorModifier: renderPassDescriptor not available.")
        }

        let copy = renderPassDescriptor.copyWithType(MTLRenderPassDescriptor.self)
        modify(copy)
        node.environmentValues.renderPassDescriptor = copy
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
