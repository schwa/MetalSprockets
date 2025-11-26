import Metal

// TODO: #22 Make into actual Modifier.
internal struct RenderPassDescriptorModifier<Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var modify: (MTLRenderPassDescriptor) -> Void

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func configureNodeBodyless(_ node: Node) throws {
        if let renderPassDescriptor = node.environmentValues.renderPassDescriptor {
            modify(renderPassDescriptor)
        }
        else {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            node.environmentValues.renderPassDescriptor = renderPassDescriptor
            modify(renderPassDescriptor)
        }


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
