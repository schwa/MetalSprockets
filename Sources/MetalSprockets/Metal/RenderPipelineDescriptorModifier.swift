import Metal

// TODO: #22 Make into actual Modifier.
public struct RenderPipelineDescriptorModifier<Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var modify: (MTLRenderPipelineDescriptor) -> Void

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    // Apply modifier during configureNode phase (runs every frame during update).
    // This ensures the modified descriptor is inherited by children.
    // We read from the PARENT's environment to get the fresh descriptor for this frame,
    // since the node's own environment may have a stale cached value.
    // Mirrors the pattern used by RenderPassDescriptorModifier. See #342.
    func configureNodeBodyless(_ node: Node) throws {
        guard let system = System.current else {
            fatalError("RenderPipelineDescriptorModifier: No System is currently active.")
        }

        let parent = system.activeNodeStack.count >= 2 ? system.activeNodeStack[system.activeNodeStack.count - 2] : nil
        guard let renderPipelineDescriptor = parent?.environmentValues.renderPipelineDescriptor ?? node.environmentValues.renderPipelineDescriptor else {
            return // Descriptor not set yet
        }

        let copy = renderPipelineDescriptor.copyWithType(MTLRenderPipelineDescriptor.self)
        modify(copy)
        node.environmentValues.renderPipelineDescriptor = copy
    }

    nonisolated func requiresSetup(comparedTo old: RenderPipelineDescriptorModifier<Content>) -> Bool {
        false
    }
}

public extension Element {
    func renderPipelineDescriptorModifier(_ modify: @escaping (MTLRenderPipelineDescriptor) -> Void) -> some Element {
        RenderPipelineDescriptorModifier(content: self, modify: modify)
    }
}
