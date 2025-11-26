import Metal

// TODO: #22 Make into actual Modifier.
internal struct RenderPassDescriptorModifier<Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var modify: (MTLRenderPassDescriptor) -> Void

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func configureNodeBodyless(_ node: Node) throws {
        guard let renderPassDescriptor = node.environmentValues.renderPassDescriptor else {
            fatalError("RenderPassDescriptorModifier not available.")
        }
        let copy = renderPassDescriptor.copyWithType(MTLRenderPassDescriptor.self)
        modify(copy)
        node.environmentValues.renderPassDescriptor = copy
    }

    nonisolated func requiresSetup(comparedTo old: RenderPassDescriptorModifier<Content>) -> Bool {
        // Since we can't compare closures, be conservative
        true
    }
}

public extension Element {
    func renderPassDescriptorModifier(_ modify: @escaping (MTLRenderPassDescriptor) -> Void) -> some Element {
        RenderPassDescriptorModifier(content: self, modify: modify)
    }
}
