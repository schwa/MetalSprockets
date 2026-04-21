internal final class StateBox<Wrapped> {
    private var _value: Wrapped
    private weak var _system: System?
    private var dependencies: [WeakBox<Node>] = []
    private var hasBeenConnected = false

    private var system: System? {
        if _system == nil {
            _system = System.current
            if _system != nil {
                hasBeenConnected = true
            } else if !hasBeenConnected {
                // Never been connected to a graph - this is a real error, else: was connected but graph is now gone (teardown) - this is OK
                assertionFailure("StateBox must be used within a System.")
            }
        }
        return _system
    }

    internal var wrappedValue: Wrapped {
        get {
            // Remove dependnecies whose values have been deallocated
            dependencies = dependencies.filter { $0.wrappedValue != nil }

            // Add current node accessoring the value to list of dependencies
            let currentNode = system?.activeNodeStack.last
            if let currentNode, !dependencies.contains(where: { $0() === currentNode }) {
                dependencies.append(WeakBox(currentNode))
            }
            return _value
        }
        set {
            _value = newValue
            valueDidChange()
        }
    }

    internal var binding: MSBinding<Wrapped> = MSBinding(
        get: { preconditionFailure("Empty Binding: get() called.") },
        set: { _ in preconditionFailure("Empty Binding: set() called.") }
    )

    internal init(_ wrappedValue: Wrapped) {
        self._value = wrappedValue
        // Capture `self` weakly so an `MSBinding` that outlives its owning
        // `StateBox` (e.g. deferred past body evaluation via Task /
        // DispatchQueue.main.async / a GPU completion handler) degrades
        // gracefully instead of crashing with swift_abortRetainUnowned.
        // See #331.
        self.binding = MSBinding(
            get: { [weak self] in
                guard let self else {
                    preconditionFailure("MSBinding read after its StateBox was deallocated")
                }
                return self.wrappedValue
            },
            set: { [weak self] newValue in
                // Late writes (e.g. GPU completion hopping to main after the
                // element tree rebuilt) are dropped silently, matching
                // SwiftUI.Binding's behaviour for bindings to gone state.
                guard let self else {
                    return
                }
                self.wrappedValue = newValue
            }
        )
    }

    /// Update dependencies when the value changes.
    private func valueDidChange() {
        // No system: either the graph is torn down (harmless) or the StateBox
        // was never attached (the `system` getter already asserts on that).
        guard let system else {
            return
        }
        // Prune dead dependency references opportunistically while we iterate.
        dependencies = dependencies.compactMap { boxedNode in
            guard let node = boxedNode() else {
                return nil
            }
            system.markDirty(node.id)
            node.needsSetup = true
            return boxedNode
        }
    }
}
