import Metal

// TODO: #22 Make into actual Modifier.
public struct RenderPipelineDescriptorTransformer<Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var modify: (MTL4RenderPipelineDescriptor) -> Void

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    // Runs in configureNode so the modified descriptor is inherited by children. The descriptor is
    // read from the parent's environment because the node's own copy may be stale from last frame.
    // Mirrors RenderPassDescriptorModifier. See #342.
    func configureNodeBodyless(_ node: Node) throws {
        guard let system = System.current else {
            fatalError("RenderPipelineDescriptorTransformer: No System is currently active.")
        }

        let parent = system.traversalContext.parentNode
        guard let renderPipelineDescriptor = parent?.environmentValues.renderPipelineDescriptor ?? node.environmentValues.renderPipelineDescriptor else {
            return // Descriptor not set yet
        }

        let copy = renderPipelineDescriptor.copyWithType(MTL4RenderPipelineDescriptor.self)
        modify(copy)
        node.environmentValues.renderPipelineDescriptor = copy
    }

    nonisolated func requiresSetup(comparedTo old: RenderPipelineDescriptorTransformer<Content>) -> Bool {
        false
    }
}

public extension Element {
    func renderPipelineDescriptorTransformer(_ modify: @escaping (MTL4RenderPipelineDescriptor) -> Void) -> some Element {
        RenderPipelineDescriptorTransformer(content: self, modify: modify)
    }
}
