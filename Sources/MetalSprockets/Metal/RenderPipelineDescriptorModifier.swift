import Metal

// TODO: #22 Make into actual Modifier.
public struct RenderPipelineDescriptorModifier<Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var modify: (MTLRenderPipelineDescriptor) -> Void

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func configureNodeBodyless(_ node: Node) throws {
        // Access the descriptor during the setup phase when we know it exists
        guard let renderPipelineDescriptor = node.environmentValues.renderPipelineDescriptor else {
            return // Descriptor not set yet, will be set by RenderPass.setupEnter()
        }

        let copy = renderPipelineDescriptor.copyWithType(MTLRenderPipelineDescriptor.self)
        modify(copy)
        node.environmentValues.renderPipelineDescriptor = copy
    }

    nonisolated func requiresSetup(comparedTo old: RenderPipelineDescriptorModifier<Content>) -> Bool {
        // Since we can't compare closures, be conservative
        true
    }
}

public extension Element {
    func renderPipelineDescriptorModifier(_ modify: @escaping (MTLRenderPipelineDescriptor) -> Void) -> some Element {
        RenderPipelineDescriptorModifier(content: self, modify: modify)
    }
}
