import os

// Every mutable field is guarded by `lock`, and `binding` is only written in `init` (#570).
extension StateBox: @unchecked Sendable where Wrapped: Sendable {}

internal final class StateBox<Wrapped> {
    // Writes can arrive off the owning isolation (see the `MSBinding` note in
    // `init`), so every access to `_value`, `dependencies`, `_system` and
    // `hasBeenConnected` goes through `lock`. Calls out to `System` and `Node`
    // are always made with the lock released to keep it non-reentrant. See #364.
    private let lock = OSAllocatedUnfairLock()
    private var _value: Storage

    // A declaration default stays `pending` until first read, so a StateBox that is replaced by the persisted one
    // never evaluates it (#578).
    private enum Storage {
        case pending(() -> Wrapped)
        case value(Wrapped)
    }
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
            // The traversal context belongs to whichever task is running the traversal, so it may only be
            // touched through the task-local `System.current`. Reads arriving from elsewhere (a GPU completion
            // handler, a detached Task) get no dependency instead of racing the node stack. See #392.
            let currentNode = resolveSystem().flatMap { system in
                System.current === system ? system.traversalContext.currentNode : nil
            }
            let pending: (() -> Wrapped)? = lock.withLockUnchecked {
                dependencies = dependencies.filter { $0.wrappedValue != nil }

                if let currentNode, !dependencies.contains(where: { $0() === currentNode }) {
                    dependencies.append(WeakBox(currentNode))
                }
                if case .pending(let makeValue) = _value {
                    return makeValue
                }
                return nil
            }
            // Evaluate the initial value with the lock released; it may read other state.
            let made = pending.map { $0() }
            return lock.withLockUnchecked {
                switch _value {
                case .value(let value):
                    return value
                case .pending:
                    // swiftlint:disable:next force_unwrapping
                    let value = made!
                    _value = .value(value)
                    return value
                }
            }
        }
        set {
            lock.withLockUnchecked {
                _value = .value(newValue)
            }
            valueDidChange()
        }
    }

    internal var binding: MSBinding<Wrapped> = MSBinding(
        get: { preconditionFailure("Empty Binding: get() called.") },
        set: { _ in preconditionFailure("Empty Binding: set() called.") }
    )

    internal convenience init(_ wrappedValue: Wrapped) {
        self.init(storage: .value(wrappedValue))
    }

    internal convenience init(makeValue: @escaping () -> Wrapped) {
        self.init(storage: .pending(makeValue))
    }

    /// The value for snapshots, without evaluating a pending initial value or recording a dependency.
    internal var snapshotValue: Any {
        lock.withLockUnchecked {
            switch _value {
            case .value(let value):
                return value
            case .pending:
                return "<not yet evaluated>"
            }
        }
    }

    private init(storage: Storage) {
        self._value = storage
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
                return wrappedValue
            },
            set: { [weak self] newValue in
                // Late writes (e.g. GPU completion hopping to main after the
                // element tree rebuilt) are dropped silently, matching
                // SwiftUI.Binding's behaviour for bindings to gone state.
                guard let self else {
                    return
                }
                wrappedValue = newValue
            }
        )
    }

    /// Update dependencies when the value changes.
    private func valueDidChange() {
        // An element initializer that assigns an `@MSState` with a declaration default goes through the setter
        // before the box is attached to any System. Nothing depends on it yet (#578).
        if System.current == nil, lock.withLockUnchecked({ _system == nil && !hasBeenConnected }) {
            return
        }
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
