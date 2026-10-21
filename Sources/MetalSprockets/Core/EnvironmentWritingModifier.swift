// TODO: #22 Make into actual modifier.
internal struct EnvironmentWritingModifier<Content: Element>: Element, BodylessElement, EnvironmentModifyingElement, WithoutDynamicProperties {
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
    /// True for `.environment(keyPath, value)`, which writes without reading the inherited value. Directly nested plain
    /// writers collapse into the outermost one's node (#518). `transformEnvironment` reads the inherited value, so it
    /// keeps its own node.
    var isPlainWrite = false

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        if isPlainWrite, let next = content as? any PlainEnvironmentWriterChain, next.isPlainWrite {
            try visit(next.innermostContent)
        } else {
            try visit(content)
        }
    }

    func configureNodeBodyless(_ node: Node) throws {
        // A reused node can hold a write to a different key from an earlier frame (#539).
        node.environmentValues.removeOwnValues()
        applyWrites(&node.environmentValues)
    }

    nonisolated func requiresSetup(comparedTo old: EnvironmentWritingModifier<Content>) -> Bool {
        if ownWriteRequiresSetup(comparedTo: old) {
            return true
        }
        // A collapsed chain has one node, so the outermost writer compares the writers nested in it.
        if isPlainWrite, let next = content as? any PlainEnvironmentWriterChain, next.isPlainWrite {
            return next.chainRequiresSetup(comparedTo: old.content)
        }
        return false
    }

    nonisolated private func ownWriteRequiresSetup(comparedTo old: Self) -> Bool {
        // Environment changes might affect setup if they change pipeline-relevant values.
        guard let keyPath, let valuesAreEqual, keyPath == old.keyPath else {
            // Opaque closure form (or a different key path): stay conservative.
            return true
        }
        return !valuesAreEqual(value, old.value)
    }
}

/// A chain of plain environment writers, walked from the outermost writer's node (#518).
internal protocol PlainEnvironmentWriterChain {
    var isPlainWrite: Bool { get }
    /// The first element in the chain that is not a plain writer.
    var innermostContent: any Element { get }
    /// Applies this writer and then every plain writer nested in it, so writes nearer the content win.
    func applyWrites(_ values: inout MSEnvironmentValues)
    nonisolated func chainRequiresSetup(comparedTo old: any Element) -> Bool
}

extension EnvironmentWritingModifier: PlainEnvironmentWriterChain {
    var innermostContent: any Element {
        if let next = content as? any PlainEnvironmentWriterChain, next.isPlainWrite {
            return next.innermostContent
        }
        return content
    }

    func applyWrites(_ values: inout MSEnvironmentValues) {
        modify(&values)
        if isPlainWrite, let next = content as? any PlainEnvironmentWriterChain, next.isPlainWrite {
            next.applyWrites(&values)
        }
    }

    nonisolated func chainRequiresSetup(comparedTo old: any Element) -> Bool {
        guard let old = old as? Self else {
            return true
        }
        return requiresSetup(comparedTo: old)
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
        var modifier = EnvironmentWritingModifier(content: self) { environmentValues in
            environmentValues[keyPath: keyPath] = value
        }
        modifier.isPlainWrite = true
        return modifier
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
            value: value,
            isPlainWrite: true
        )
    }

    /// Transforms an environment value for this element and its descendants.
    ///
    /// Unlike ``Element/environment(_:_:)-1rm5p``, the transform receives the inherited value and can
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
