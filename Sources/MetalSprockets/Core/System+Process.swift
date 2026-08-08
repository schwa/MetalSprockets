import MetalSprocketsSupport

package extension System {
    func processSetup() throws {
        try withIntervalSignpost(signposter, name: "System.processSetup()") {
            try process(needsSetup: true) { element, node in
                try element.setupEnter(node)
            } exit: { element, node in
                try element.setupExit(node)
                node.needsSetup = false
            }
        }
    }

    func processWorkload() throws {
        try withIntervalSignpost(signposter, name: "System.processWorkload()") {
            try processWorkloadWithSkipping()
        }
    }
}

internal extension System {
    /// Workload traversal with subtree-skipping support for `skipsWorkload`.
    /// When a BodylessElement returns true from `skipsWorkload(_:)`, neither its
    /// own enter/exit nor any of its descendants' enter/exit run. Setup is
    /// unaffected.
    func processWorkloadWithSkipping() throws {
        try withCurrentSystem {
            assert(activeNodeStack.isEmpty)
            defer { clearActiveNodeStack() }
            var skipDepth = 0
            for event in traversalEvents {
                switch event {
                case .enter(let node):
                    pushActiveNode(node)
                    inheritEnvironmentFromActiveParent(node)
                    if skipDepth > 0 {
                        skipDepth += 1
                        continue
                    }
                    if let bodylessElement = node.element as? any BodylessElement {
                        if bodylessElement.skipsWorkload(node) {
                            skipDepth = 1
                            continue
                        }
                        if let workloadElement = bodylessElement as? any WorkloadElement {
                            try workloadElement.workloadEnter(node)
                        }
                    }
                case .exit(let node):
                    defer { popActiveNode() }
                    if skipDepth > 0 {
                        skipDepth -= 1
                        continue
                    }
                    if let workloadElement = node.element as? any WorkloadElement {
                        try workloadElement.workloadExit(node)
                    }
                }
            }
            assert(activeNodeStack.isEmpty)
            assert(skipDepth == 0, "skipDepth should be zero after workload traversal")
        }
    }
}

internal extension System {
    /// Refreshes a node's inherited environment from the node above it on the active stack.
    ///
    /// Runs on every node entered during a traversal, including nodes that take no part in the
    /// current phase, so values written by an ancestor propagate through intermediate nodes.
    func inheritEnvironmentFromActiveParent(_ node: Node) {
        guard activeNodeStack.count > 1 else {
            return
        }
        let parentNode = activeNodeStack[activeNodeStack.count - 2]
        node.environmentValues.inherit(from: parentNode.environmentValues)
    }

    func process(needsSetup: Bool = false, enter: (any SetupElement, Node) throws -> Void, exit: (any SetupElement, Node) throws -> Void) throws {
        try withCurrentSystem {
            assert(activeNodeStack.isEmpty)
            defer { clearActiveNodeStack() }
            for event in traversalEvents {
                switch event {
                case .enter(let node):
                    pushActiveNode(node)
                    inheritEnvironmentFromActiveParent(node)
                    if let bodylessElement = node.element as? any SetupElement, !needsSetup || node.needsSetup {
                        try enter(bodylessElement, node)
                    }
                case .exit(let node):
                    if let bodylessElement = node.element as? any SetupElement, !needsSetup || node.needsSetup {
                        try exit(bodylessElement, node)
                    }
                    popActiveNode()
                }
            }
            assert(activeNodeStack.isEmpty)
        }
    }
}
