import Synchronization

internal extension Element {
    func configureNode(_ node: Node) throws {
        guard let system = System.current else {
            preconditionFailure("No System is currently active.")
        }

        // TODO: #27 Avoid this in future
        // The current node is already pushed, so the environment parent is the node above it.
        let parent = system.traversalContext.parentNode

        applyInheritedEnvironment(from: parent, to: node)

        let hasDynamicProperties = DynamicPropertyCache.mayHaveDynamicProperties(self)
        if hasDynamicProperties {
            try updateDynamicProperties(node)
        }

        if node.typeInfo.isBodyless, let bodylessElement = self as? any BodylessElement {
            try bodylessElement.configureNodeBodyless(node)
        }
        if hasDynamicProperties {
            try persistDynamicProperties(node)
        }
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

/// Remembers element types that cannot hold a dynamic property, so their nodes skip reflection every frame (#496).
///
/// A type is recorded only when one reflection found no dynamic property and no optional field. An optional field could
/// hold a dynamic property in a later value, so such types are always reflected. A field declared as `Any` or another
/// existential is not detected and is assumed to keep the kind of value it first held.
internal enum DynamicPropertyCache {
    private static let typesWithout = Mutex<Set<ObjectIdentifier>>([])

    static func mayHaveDynamicProperties(_ element: some Element) -> Bool {
        let key = ObjectIdentifier(type(of: element))
        if typesWithout.withLock({ $0.contains(key) }) {
            return false
        }
        var canCache = true
        for (_, value) in Mirror(reflecting: element).children {
            if value is any MSDynamicProperty {
                return true
            }
            if Mirror(reflecting: value).displayStyle == .optional {
                canCache = false
            }
        }
        if canCache {
            typesWithout.withLock { _ = $0.insert(key) }
        }
        return false
    }
}
