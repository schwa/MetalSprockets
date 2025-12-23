// TODO: #22 Make into actual modifier.
internal struct EnvironmentWritingModifier<Content: Element>: Element, BodylessElement {
    var content: Content
    var modify: (inout MSEnvironmentValues) -> Void

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func configureNodeBodyless(_ node: Node) throws {
        modify(&node.environmentValues)
    }

    nonisolated func requiresSetup(comparedTo old: EnvironmentWritingModifier<Content>) -> Bool {
        // Environment changes might affect setup if they change pipeline-relevant values
        // Since we can't compare closures, be conservative
        true
    }
}

// MARK: - environment Modifier

public extension Element {
    /// Sets an environment value for this element and its descendants.
    ///
    /// Environment values flow down through the element tree, providing
    /// shared context without explicit parameter passing.
    ///
    /// ## Overview
    ///
    /// Set custom environment values:
    ///
    /// ```swift
    /// RenderPass {
    ///     MyContent()
    /// }
    /// .environment(\.myCustomValue, someValue)
    /// ```
    ///
    /// ## Built-in Values
    ///
    /// Override built-in environment values:
    ///
    /// ```swift
    /// element
    ///     .environment(\.device, customDevice)
    ///     .environment(\.commandQueue, customQueue)
    /// ```
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path to the environment value.
    ///   - value: The value to set.
    func environment<Value>(_ keyPath: WritableKeyPath<MSEnvironmentValues, Value>, _ value: Value) -> some Element {
        EnvironmentWritingModifier(content: self) { environmentValues in
            environmentValues[keyPath: keyPath] = value
        }
    }
}
