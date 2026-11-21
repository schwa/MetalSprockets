import MetalSprocketsSupport

/// Runs the setup and workload phases over the traversal events that reconciliation produced (#390).
///
/// The events are frozen for the run. The runner drives `traversalContext` so each node inherits the environment its
/// ancestors wrote earlier in the same phase.
internal struct PhaseRunner {
    let events: [TraversalEvent]
    let traversalContext: TraversalContext

    /// Runs `setupEnter`/`setupExit` on every node that needs setup, and clears its `needsSetup`.
    func runSetup() throws {
        assert(traversalContext.isEmpty)
        defer { traversalContext.clear() }
        for event in events {
            switch event {
            case .enter(let node):
                traversalContext.push(node)
                inheritEnvironmentFromActiveParent(node)
                if let setupType = node.typeInfo.setupType, node.needsSetup {
                    try setupType.setupEnter(of: node.element, node: node)
                }
            case .exit(let node):
                if let setupType = node.typeInfo.setupType, node.needsSetup {
                    try setupType.setupExit(of: node.element, node: node)
                    node.needsSetup = false
                }
                traversalContext.pop()
            }
        }
        assert(traversalContext.isEmpty)
    }

    /// Runs the workload phase. When an element returns true from `skipsWorkload(_:)`, neither its own enter/exit nor
    /// any of its descendants' run. Setup is unaffected.
    func runWorkload() throws {
        assert(traversalContext.isEmpty)
        defer { traversalContext.clear() }
        var state = WorkloadState()
        do {
            for event in events {
                switch event {
                case .enter(let node):
                    try enterWorkload(node, state: &state)
                case .exit(let node):
                    try exitWorkload(node, state: &state)
                }
            }
        } catch {
            unwindWorkload(&state)
            throw error
        }
        assert(traversalContext.isEmpty)
        assert(state.skipDepth == 0, "skipDepth should be zero after workload traversal")
    }

    /// Mutable bookkeeping for a single workload traversal.
    private struct WorkloadState {
        /// Depth of the subtree currently being skipped, or 0 when not skipping.
        var skipDepth = 0

        /// Nodes whose `workloadEnter` has run but whose `workloadExit` has not. If a descendant throws these are
        /// unwound in reverse so encoders are always ended (an un-ended `MTLCommandEncoder` aborts the process when
        /// deallocated).
        var enteredNodes: [Node] = []
    }

    private func enterWorkload(_ node: Node, state: inout WorkloadState) throws {
        traversalContext.push(node)
        inheritEnvironmentFromActiveParent(node)
        if state.skipDepth > 0 {
            state.skipDepth += 1
            return
        }
        guard let bodylessType = node.typeInfo.bodylessType else {
            return
        }
        if bodylessType.skipsWorkload(of: node.element, node: node) {
            state.skipDepth = 1
            return
        }
        if let workloadType = node.typeInfo.workloadType {
            try workloadType.workloadEnter(of: node.element, node: node)
            state.enteredNodes.append(node)
        }
    }

    private func exitWorkload(_ node: Node, state: inout WorkloadState) throws {
        defer { traversalContext.pop() }
        if state.skipDepth > 0 {
            state.skipDepth -= 1
            return
        }
        guard let workloadType = node.typeInfo.workloadType else {
            return
        }
        if state.enteredNodes.last === node {
            state.enteredNodes.removeLast()
        }
        try workloadType.workloadExit(of: node.element, node: node)
    }

    /// Runs `workloadExit` for every still-entered node, innermost first.
    private func unwindWorkload(_ state: inout WorkloadState) {
        for node in state.enteredNodes.reversed() {
            guard let workloadType = node.typeInfo.workloadType else {
                continue
            }
            do {
                try workloadType.workloadExit(of: node.element, node: node)
            } catch {
                logger?.error("workloadExit failed while unwinding after an error: \(error)")
            }
        }
        state.enteredNodes.removeAll()
    }

    /// Refreshes a node's inherited environment from the node above it on the active stack.
    ///
    /// Runs on every node that a traversal enters, including nodes that take no part in the current phase.
    /// As a result, values that an ancestor writes go through the intermediate nodes.
    private func inheritEnvironmentFromActiveParent(_ node: Node) {
        guard let parentNode = traversalContext.parentNode else {
            return
        }
        node.environmentValues.inherit(from: parentNode.environmentValues)
    }
}
