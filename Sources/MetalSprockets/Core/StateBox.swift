import os

internal final class StateBox<Wrapped> {
    // Writes can arrive off the owning isolation (see the `MSBinding` note in
    // `init`), so every access to `_value`, `dependencies`, `_system` and
    // `hasBeenConnected` goes through `lock`. Calls out to `System` and `Node`
    // are always made with the lock released to keep it non-reentrant. See #364.
    private let lock = OSAllocatedUnfairLock()
    private var _value: Wrapped
    private weak var _system: System?
    private var dependencies: [WeakBox<Node>] = []
    private var hasBeenConnected = false

    private func resolveSystem() -> System? {
        let current = System.current
        return lock.withLockUnchecked {
            if _system == nil {
                _system = current
                if _system != nil {
                    hasBeenConnected = true
                } else if !hasBeenConnected {
                    // Never been connected to a graph - this is a real error, else: was connected but graph is now gone (teardown) - this is OK
                    assertionFailure("StateBox must be used within a System.")
                }
            }
            return _system
        }
    }

    internal var wrappedValue: Wrapped {
        get {
            let currentNode = resolveSystem()?.traversalContext.currentNode
            return lock.withLockUnchecked {
                dependencies = dependencies.filter { $0.wrappedValue != nil }

                if let currentNode, !dependencies.contains(where: { $0() === currentNode }) {
                    dependencies.append(WeakBox(currentNode))
                }
                return _value
            }
        }
        set {
            lock.withLockUnchecked {
                _value = newValue
            }
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
        guard let system = resolveSystem() else {
            return
        }
        // Prune dead dependency references opportunistically, then notify with
        // the lock released.
        let nodes: [Node] = lock.withLockUnchecked {
            dependencies = dependencies.filter { $0() != nil }
            return dependencies.compactMap { $0() }
        }
        for node in nodes {
            system.markDirtyIncludingAncestors(node)
            // `Node` is not thread-safe and this can run off the owning isolation, so the setup request goes through
            // `System`'s lock instead of writing `node.needsSetup` here. See #385.
            system.markNeedsSetup(node.id)
        }
    }
}
