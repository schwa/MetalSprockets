import MetalSprocketsSupport

package extension System {
    // Signposted as Setup and Workload by `render(root:)`.
    func processSetup() throws {
        try process(needsSetup: true) { setupType, node in
            try setupType.setupEnter(of: node.element, node: node)
        } exit: { setupType, node in
            try setupType.setupExit(of: node.element, node: node)
            node.needsSetup = false
        }
    }

    func processWorkload() throws {
        try processWorkloadWithSkipping()
    }
}

/// Mutable bookkeeping for a single workload traversal.
internal struct WorkloadTraversalState {
    /// Depth of the subtree currently being skipped, or 0 when not skipping.
    var skipDepth = 0

    /// Nodes whose `workloadEnter` has run but whose `workloadExit` has not. If a descendant throws these are unwound
    /// in reverse so encoders are always ended (an un-ended `MTLCommandEncoder` aborts the process when deallocated).
    var enteredNodes: [Node] = []
}

internal extension System {
    /// Workload traversal with subtree-skipping support for `skipsWorkload`.
    /// When a BodylessElement returns true from `skipsWorkload(_:)`, neither its
    /// own enter/exit nor any of its descendants' enter/exit run. Setup is
    /// unaffected.
    func processWorkloadWithSkipping() throws {
        try withCurrentSystem {
            assert(traversalContext.isEmpty)
            defer { traversalContext.clear() }
            var state = WorkloadTraversalState()
            do {
                for event in traversalEvents {
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
    }

    private func enterWorkload(_ node: Node, state: inout WorkloadTraversalState) throws {
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

    private func exitWorkload(_ node: Node, state: inout WorkloadTraversalState) throws {
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
    private func unwindWorkload(_ state: inout WorkloadTraversalState) {
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
}

internal extension System {
    /// Refreshes a node's inherited environment from the node above it on the active stack.
    ///
    /// Runs on every node entered during a traversal, including nodes that take no part in the
    /// current phase, so values written by an ancestor propagate through intermediate nodes.
    func inheritEnvironmentFromActiveParent(_ node: Node) {
        guard let parentNode = traversalContext.parentNode else {
            return
        }
        node.environmentValues.inherit(from: parentNode.environmentValues)
    }

    func process(needsSetup: Bool = false, enter: (any SetupElement.Type, Node) throws -> Void, exit: (any SetupElement.Type, Node) throws -> Void) throws {
        try withCurrentSystem {
            assert(traversalContext.isEmpty)
            defer { traversalContext.clear() }
            for event in traversalEvents {
                switch event {
                case .enter(let node):
                    traversalContext.push(node)
                    inheritEnvironmentFromActiveParent(node)
                    if let setupType = node.typeInfo.setupType, !needsSetup || node.needsSetup {
                        try enter(setupType, node)
                    }
                case .exit(let node):
                    if let setupType = node.typeInfo.setupType, !needsSetup || node.needsSetup {
                        try exit(setupType, node)
                    }
                    traversalContext.pop()
                }
            }
            assert(traversalContext.isEmpty)
        }
    }
}
