import Metal

// TODO: #22 Make into actual Modifier.
public struct RenderPipelineDescriptorModifier<Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var modify: (MTLRenderPipelineDescriptor) -> Void

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func setupEnter(_ node: Node) throws {
        // Run during setup phase AFTER RenderPass.setupEnter() creates the descriptor
        // but BEFORE RenderPipeline.setupEnter() uses it
        guard let renderPipelineDescriptor = node.environmentValues.renderPipelineDescriptor else {
            return // Descriptor not set yet
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
