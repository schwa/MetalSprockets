internal extension Element {
    func configureNode(_ node: Node) throws {
        guard let system = System.current else {
            preconditionFailure("No System is currently active.")
        }

        // TODO: #27 Avoid this in future
        // Get the parent node (second to last in stack, since current node is already pushed)
        let parent = system.activeNodeStack.count >= 2 ? system.activeNodeStack[system.activeNodeStack.count - 2] : nil

        applyInheritedEnvironment(from: parent, to: node)

        try updateDynamicProperties(node)

        if let bodylessElement = self as? any BodylessElement {
            try bodylessElement.configureNodeBodyless(node)
        }
        try persistDynamicProperties(node)
    }

    private func applyInheritedEnvironment(from parent: Node?, to node: Node) {
        guard let parent else {
            return
        }
        node.environmentValues.inherit(from: parent.environmentValues)
    }

    /// Runs the pre-body phase of every ``MSDynamicProperty`` on this element.
    private func updateDynamicProperties(_ node: Node) throws {
        try visitDynamicProperties(node) { property, context in
            try property.update(in: context)
        }
    }

    /// Runs the post-body phase of every ``MSDynamicProperty`` on this element.
    private func persistDynamicProperties(_ node: Node) throws {
        try visitDynamicProperties(node) { property, context in
            try property.persist(in: context)
        }
    }

    private func visitDynamicProperties(_ node: Node, _ body: (any MSDynamicProperty, MSDynamicPropertyContext) throws -> Void) throws {
        for (label, value) in Mirror(reflecting: self).children {
            guard let property = value as? any MSDynamicProperty else {
                continue
            }
            guard let label else {
                preconditionFailure("No label for dynamic property on \(type(of: self)).")
            }
            try body(property, MSDynamicPropertyContext(node: node, label: label))
        }
    }
}
