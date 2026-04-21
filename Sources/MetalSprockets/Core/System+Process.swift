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
            var skipDepth = 0
            for event in traversalEvents {
                switch event {
                case .enter(let node):
                    pushActiveNode(node)
                    if skipDepth > 0 {
                        skipDepth += 1
                        continue
                    }
                    if let bodylessElement = node.element as? any BodylessElement {
                        // Rebuild environment parent chain (mirrors `process`).
                        if activeNodeStack.count > 1 {
                            if node.environmentValues.storage.parent == nil {
                                let parentNode = activeNodeStack[activeNodeStack.count - 2]
                                var freshEnvironment = MSEnvironmentValues()
                                freshEnvironment.merge(parentNode.environmentValues)
                                freshEnvironment.storage.values.merge(node.environmentValues.storage.values) { _, new in new }
                                node.environmentValues = freshEnvironment
                            }
                        }
                        if bodylessElement.skipsWorkload(node) {
                            skipDepth = 1
                            continue
                        }
                        try bodylessElement.workloadEnter(node)
                    }
                case .exit(let node):
                    defer { popActiveNode() }
                    if skipDepth > 0 {
                        skipDepth -= 1
                        continue
                    }
                    if let bodylessElement = node.element as? any BodylessElement {
                        try bodylessElement.workloadExit(node)
                    }
                }
            }
            assert(activeNodeStack.isEmpty)
            assert(skipDepth == 0, "skipDepth should be zero after workload traversal")
        }
    }
}

internal extension System {
    func process(needsSetup: Bool = false, enter: (any BodylessElement, Node) throws -> Void, exit: (any BodylessElement, Node) throws -> Void) throws {
        try withCurrentSystem {
            assert(activeNodeStack.isEmpty)
            for event in traversalEvents {
                switch event {
                case .enter(let node):
                    pushActiveNode(node)
                    if let bodylessElement = node.element as? any BodylessElement, !needsSetup || node.needsSetup {
                        // Rebuild environment parent chain
                        // TODO: Investigate whether we need this still. Seems like patch for broken behavior.
                        if activeNodeStack.count > 1 {
                            if node.environmentValues.storage.parent == nil {
                                let parentNode = activeNodeStack[activeNodeStack.count - 2]
                                var freshEnvironment = MSEnvironmentValues()
                                freshEnvironment.merge(parentNode.environmentValues)
                                freshEnvironment.storage.values.merge(node.environmentValues.storage.values) { _, new in new }
                                node.environmentValues = freshEnvironment
                            }
                        }
                        try enter(bodylessElement, node)
                    }
                case .exit(let node):
                    if let bodylessElement = node.element as? any BodylessElement, !needsSetup || node.needsSetup {
                        try exit(bodylessElement, node)
                    }
                    popActiveNode()
                }
            }
            assert(activeNodeStack.isEmpty)
        }
    }
}
