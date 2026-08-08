extension Optional: Element, BodylessElement where Wrapped: Element {
    public typealias Body = Never

    internal func visitChildrenBodyless(_ visit: (any Element) throws -> Void) rethrows {
        try self.map { try visit($0) }
    }
}

// A dynamic cast of an `Optional` falls back to unwrapping when the optional's own type does not
// conform, so `node.element as? any WorkloadElement` on an Optional node would otherwise succeed
// against the *wrapped* element and run its enter/exit a second time — two live render command
// encoders for one `RenderPass`. Declaring the conformances here keeps the direct (no-op) match
// winning. See #381.
extension Optional: SetupElement where Wrapped: Element {
    internal func setupEnter(_ node: Node) throws {
        // This line intentionally left blank.
    }

    internal func setupExit(_ node: Node) throws {
        // This line intentionally left blank.
    }
}

extension Optional: WorkloadElement where Wrapped: Element {
    internal func workloadEnter(_ node: Node) throws {
        // This line intentionally left blank.
    }

    internal func workloadExit(_ node: Node) throws {
        // This line intentionally left blank.
    }
}
