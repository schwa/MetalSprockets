/// Marks an element that writes environment values for its children during the update phase.
///
/// Subtree skipping (#370) uses this: once such an element changes, nothing below it may be skipped, because its
/// descendants read the environment while their bodies run.
internal protocol EnvironmentModifyingElement {}

internal protocol BodylessElement {
    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws

    func configureNodeBodyless(_ node: Node) throws

    /// Called once when a node is being removed from the tree (the element is no
    /// longer present after an `update`). Use this to release external resources
    /// or unregister observers. GPU resources held in the node's env/caches are
    /// freed automatically via ARC when the node is released.
    func teardown(_ node: Node) throws

    /// When true, `processWorkload` skips this element and its entire subtree
    /// during the workload phase. Setup still runs so resources stay built.
    /// Default: false.
    func skipsWorkload(_ node: Node) -> Bool

    /// Returns true if the change from `old` to `self` requires the setup phase to run again.
    /// This is a SHALLOW check - only considers this element, not its children.
    func requiresSetup(comparedTo old: Self) -> Bool
}

/// A bodyless element that takes part in the setup phase.
///
/// Conformance is what makes the setup phase visit an element at all: nodes whose element is not a `SetupElement`
/// never report `needsSetup`, so they cost nothing in `processSetup` and need no `requiresSetup` override. See #235.
internal protocol SetupElement: BodylessElement {
    func setupEnter(_ node: Node) throws
    func setupExit(_ node: Node) throws
}

/// A bodyless element that takes part in the workload phase, i.e. it encodes GPU work every frame.
internal protocol WorkloadElement: BodylessElement {
    func workloadEnter(_ node: Node) throws
    func workloadExit(_ node: Node) throws
}

extension BodylessElement {
    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        // This line intentionally left blank.
    }

    func configureNodeBodyless(_ node: Node) throws {
        // This line intentionally left blank.
    }

    func teardown(_ node: Node) throws {
        // This line intentionally left blank.
    }
    func skipsWorkload(_ node: Node) -> Bool {
        false
    }
}

extension SetupElement {
    func setupEnter(_ node: Node) throws {
        // This line intentionally left blank.
    }
    func setupExit(_ node: Node) throws {
        // This line intentionally left blank.
    }
}

extension WorkloadElement {
    func workloadEnter(_ node: Node) throws {
        // This line intentionally left blank.
    }
    func workloadExit(_ node: Node) throws {
        // This line intentionally left blank.
    }
}

extension BodylessElement {
    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        // Default: use Equatable if available, otherwise assume change requires setup
        if let self = self as? any Equatable,
           let old = old as? any Equatable {
            return !isEqual(self, old)
        }
        return true
    }
}

extension BodylessElement where Self: Equatable {
    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        self != old
    }
}
