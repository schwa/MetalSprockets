internal protocol BodylessElement {
    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws

    func configureNodeBodyless(_ node: Node) throws
    func setupEnter(_ node: Node) throws
    func setupExit(_ node: Node) throws
    func workloadEnter(_ node: Node) throws
    func workloadExit(_ node: Node) throws

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

extension BodylessElement {
    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        // This line intentionally left blank.
    }

    func configureNodeBodyless(_ node: Node) throws {
        // This line intentionally left blank.
    }

    func setupEnter(_ node: Node) throws {
        // This line intentionally left blank.
    }
    func setupExit(_ node: Node) throws {
        // This line intentionally left blank.
    }
    func workloadEnter(_ node: Node) throws {
        // This line intentionally left blank.
    }
    func workloadExit(_ node: Node) throws {
        // This line intentionally left blank.
    }
    func teardown(_ node: Node) throws {
        // This line intentionally left blank.
    }
    func skipsWorkload(_ node: Node) -> Bool {
        false
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
