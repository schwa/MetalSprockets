// TODO: #22 Make into actual modifier.
internal struct EnvironmentWritingModifier<Content: Element>: Element, BodylessElement, EnvironmentModifyingElement {
    var content: Content
    var modify: (inout MSEnvironmentValues) -> Void

    /// Key path written by `modify`, when the modifier was created from the key-path form.
    /// Together with `value` and `valuesAreEqual` this lets `requiresSetup(comparedTo:)`
    /// compare what the closure *does* instead of comparing the (uncomparable) closure.
    var keyPath: AnyKeyPath?
    var valuesAreEqual: ((Any?, Any?) -> Bool)?
    // Declared last so the memberwise initializer doesn't end with a closure argument,
    // which SwiftLint's trailing-closure rules would then complain about either way.
    var value: Any?

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func configureNodeBodyless(_ node: Node) throws {
        modify(&node.environmentValues)
    }

    nonisolated func requiresSetup(comparedTo old: EnvironmentWritingModifier<Content>) -> Bool {
        // Environment changes might affect setup if they change pipeline-relevant values.
        guard let keyPath, let valuesAreEqual, keyPath == old.keyPath else {
            // Opaque closure form (or a different key path): stay conservative.
            return true
        }
        return !valuesAreEqual(value, old.value)
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

    /// Sets an equatable environment value for this element and its descendants.
    ///
    /// This overload records the key path and value so repeated updates with an unchanged
    /// value can skip the setup phase (see #346).
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path to the environment value.
    ///   - value: The value to set.
    func environment<Value>(_ keyPath: WritableKeyPath<MSEnvironmentValues, Value>, _ value: Value) -> some Element where Value: Equatable {
        EnvironmentWritingModifier(
            content: self,
            modify: { environmentValues in
                environmentValues[keyPath: keyPath] = value
            },
            keyPath: keyPath,
            valuesAreEqual: { lhs, rhs in
                guard let lhs = lhs as? Value, let rhs = rhs as? Value else {
                    return false
                }
                return lhs == rhs
            },
            value: value
        )
    }

    /// Transforms an environment value for this element and its descendants.
    ///
    /// Unlike ``environment(_:_:)``, the transform receives the inherited value and can
    /// modify it in place:
    ///
    /// ```swift
    /// element.transformEnvironment(\.someValue) { value in
    ///     value += 1
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path to the environment value.
    ///   - transform: A closure that modifies the inherited value in place.
    func transformEnvironment<Value>(_ keyPath: WritableKeyPath<MSEnvironmentValues, Value>, transform: @escaping (inout Value) -> Void) -> some Element {
        EnvironmentWritingModifier(content: self) { environmentValues in
            transform(&environmentValues[keyPath: keyPath])
        }
    }
}
