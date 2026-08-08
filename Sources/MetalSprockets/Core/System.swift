import Foundation
import os
import QuartzCore

/// Represents a traversal event in the node tree
internal enum TraversalEvent {
    case enter(Node)
    case exit(Node)

    var node: Node {
        switch self {
        case .enter(let node), .exit(let node):
            return node
        }
    }
}

/// The core engine that manages the element tree, node lifecycle, and render graph traversal.
///
/// `System` maintains the mapping between elements and their corresponding nodes,
/// handles state persistence, environment propagation, and orchestrates the setup
/// and workload phases of rendering.
///
/// - Note: `System` is marked `@unchecked Sendable` because each instance is
///   confined to a single isolation context (MainActor, custom actor, or
///   synchronous single-threaded code). Instances must not be shared across
///   isolation domains.
package final class System: @unchecked Sendable {
    /// How long each phase of a frame took.
    package struct PhaseTimings {
        package var update: TimeInterval
        package var setup: TimeInterval
        package var workload: TimeInterval

        package var total: TimeInterval {
            update + setup + workload
        }
    }

    private(set) var traversalEvents: [TraversalEvent] = []
    private(set) var nodes: [StructuralIdentifier: Node] = [:]
    /// The node stack for the traversal currently in flight. Owned by the phase doing the traversal; empty outside
    /// one. Environment and state resolve through this context (see ``TraversalContext``).
    let traversalContext = TraversalContext()
    /// Identifiers of nodes whose element should be re-evaluated on the next update.
    ///
    /// Wrapped in `OSAllocatedUnfairLock` because `markDirty(_:)` may be called
    /// from non-main threads (e.g. `onCommandBufferCompleted` handlers writing
    /// back to `@MSState`) concurrently with `System.update(root:)` on the
    /// owning isolation. See #330.
    private let _dirtyIdentifiers = OSAllocatedUnfairLock<Set<StructuralIdentifier>>(initialState: [])

    /// Read-only snapshot of the current dirty identifiers. Takes the lock.
    var dirtyIdentifiers: Set<StructuralIdentifier> {
        _dirtyIdentifiers.withLock { $0 }
    }

    private let snapshotter = Snapshotter()

    @TaskLocal internal static var current: System?

    package init() {
        // This line intentionally left blank.
    }

    /// Mark all nodes as needing setup (e.g., when drawable size changes)
    package func markAllNodesNeedingSetup() {
        for node in nodes.values where node.element is any SetupElement {
            node.needsSetup = true
        }
    }

    /// Mark a node as dirty (needs rebuild on next update)
    internal func markDirty(_ id: StructuralIdentifier) {
        _dirtyIdentifiers.withLock { _ = $0.insert(id) }
    }

    /// Mark a node dirty along with every ancestor, so a subtree can be tested for dirtiness by looking only at its
    /// root. See #367.
    internal func markDirtyIncludingAncestors(_ node: Node) {
        var chain: [StructuralIdentifier] = [node.id]
        var parentIdentifier = node.parentIdentifier
        // Bounded by the tree depth; `seen` guards against a malformed cyclic parent chain.
        var seen: Set<StructuralIdentifier> = [node.id]
        while let identifier = parentIdentifier, !seen.contains(identifier) {
            chain.append(identifier)
            seen.insert(identifier)
            parentIdentifier = nodes[identifier]?.parentIdentifier
        }
        let identifiers = chain
        _dirtyIdentifiers.withLock { $0.formUnion(identifiers) }
    }

    /// Whether the given identifier is currently marked dirty.
    internal func isDirty(_ id: StructuralIdentifier) -> Bool {
        _dirtyIdentifiers.withLock { $0.contains(id) }
    }

    /// Whether the subtree rooted at `id` contains any dirty node.
    ///
    /// Relies on ``markDirtyIncludingAncestors(_:)``: a dirty descendant always marks its ancestors, so the root's own
    /// mark is sufficient. Falls back to a subtree walk for identifiers marked without ancestor propagation.
    internal func isSubtreeDirty(_ id: StructuralIdentifier) -> Bool {
        let dirty = dirtyIdentifiers
        if dirty.contains(id) {
            return true
        }
        return dirty.contains { descendantIdentifier in
            isDescendant(descendantIdentifier, of: id)
        }
    }

    /// The contiguous range of traversal events covering the subtree rooted at `id`, from its `.enter` event through
    /// its matching `.exit` event. Returns `nil` if the identifier is not present in `events`. See #369.
    internal static func subtreeEventRange(for id: StructuralIdentifier, in events: [TraversalEvent]) -> Range<Int>? {
        guard let start = events.firstIndex(where: { event in
            guard case .enter(let node) = event else {
                return false
            }
            return node.id == id
        }) else {
            return nil
        }
        var depth = 0
        for index in start..<events.count {
            switch events[index] {
            case .enter:
                depth += 1
            case .exit(let node):
                depth -= 1
                if depth == 0 {
                    // Balanced traversal: the exit closing the opening enter must be the same node.
                    assert(node.id == id)
                    return start..<(index + 1)
                }
            }
        }
        return nil
    }

    /// The traversal events for the subtree rooted at `id` in the *previous* traversal, or `nil` if that subtree was
    /// not present.
    internal func previousSubtreeEvents(for id: StructuralIdentifier) -> ArraySlice<TraversalEvent>? {
        Self.subtreeEventRange(for: id, in: traversalEvents).map { traversalEvents[$0] }
    }

    /// The nodes of the subtree rooted at `id` in the previous traversal, in enter order.
    internal func previousSubtreeNodes(for id: StructuralIdentifier) -> [Node] {
        guard let events = previousSubtreeEvents(for: id) else {
            return []
        }
        return events.compactMap { event in
            guard case .enter(let node) = event else {
                return nil
            }
            return node
        }
    }

    /// Whether `id` is a descendant of `ancestor` in the node tree.
    internal func isDescendant(_ id: StructuralIdentifier, of ancestor: StructuralIdentifier) -> Bool {
        var seen: Set<StructuralIdentifier> = [id]
        var current = nodes[id]?.parentIdentifier
        while let identifier = current, !seen.contains(identifier) {
            if identifier == ancestor {
                return true
            }
            seen.insert(identifier)
            current = nodes[identifier]?.parentIdentifier
        }
        return false
    }

    /// Atomically remove and return all currently-dirty identifiers.
    internal func takeDirtyIdentifiers() -> Set<StructuralIdentifier> {
        _dirtyIdentifiers.withLock { dirty in
            let taken = dirty
            dirty.removeAll()
            return taken
        }
    }

    /// Renders one frame of `root`: update, setup, workload, in that order.
    ///
    /// This is the supported entry point. The individual phases are internal because they only mean anything in this
    /// sequence. See #374.
    @discardableResult
    package func render(root: some Element) throws -> PhaseTimings {
        let updateStart = CACurrentMediaTime()
        try update(root: root)
        let setupStart = CACurrentMediaTime()
        return try withCurrentSystem {
            try processSetup()
            let workloadStart = CACurrentMediaTime()
            try processWorkload()
            let end = CACurrentMediaTime()
            return PhaseTimings(update: setupStart - updateStart, setup: workloadStart - setupStart, workload: end - workloadStart)
        }
    }

    internal func update(root: some Element) throws {
        assert(traversalContext.isEmpty)
        try withCurrentSystem {
            defer {
                assert(traversalContext.isEmpty, "traversal context should be empty after update")
                _ = takeDirtyIdentifiers()
                traversalContext.clear()
            }

            let reconciliation = try TreeReconciler(system: self).reconcile(root: root)

            _ = takeDirtyIdentifiers()

            // Find removed nodes by diffing old vs new, and give their elements a
            // chance to tear down any external state before they're dropped.
            let removedIds = Set(nodes.keys).subtracting(Set(reconciliation.nodes.keys))
            for id in removedIds {
                guard let removedNode = nodes[id] else { continue }
                if let bodyless = removedNode.element as? any BodylessElement {
                    do {
                        try bodyless.teardown(removedNode)
                    } catch {
                        logger?.error("teardown failed for removed node \(id): \(error)")
                    }
                }
            }

            self.nodes = reconciliation.nodes
            self.traversalEvents = reconciliation.events

            snapshotter.dumpSnapshotIfNeeded(self)
        }
    }
}

// MARK: - Node Processing

internal extension System {
    /// Determine whether to reuse an existing node or create a new one
    func processNode(currentId: StructuralIdentifier, previousId: StructuralIdentifier?, element: any Element, newNodes: inout [StructuralIdentifier: Node]) -> Node {
        if let previousId, previousId == currentId {
            return reuseNode(currentId: currentId, element: element, newNodes: &newNodes)
        }
        return makeNode(currentId: currentId, element: element, newNodes: &newNodes)
    }

    /// Reuse an existing node, updating it if its element has changed
    func reuseNode(currentId: StructuralIdentifier, element: any Element, newNodes: inout [StructuralIdentifier: Node]) -> Node {
        guard let existingNode = nodes[currentId] else {
            fatalError("Found matching structural ID \(currentId) but no existing node - this indicates a bug in the System")
        }
        existingNode.parentIdentifier = traversalContext.currentNode?.id

        if shouldUpdateNode(existingNode, with: element, id: currentId) {
            let oldElement = existingNode.element
            existingNode.element = element
            // Setup-phase values (e.g. renderPipelineState) must survive an element change, so only
            // inherited values are cleared.
            existingNode.environmentValues.removeInheritedValues()

            // An already-set needsSetup (e.g. from markAllNodesNeedingSetup) is preserved.
            if !existingNode.needsSetup {
                if let oldBodyless = oldElement as? any BodylessElement,
                    let newBodyless = element as? any BodylessElement,
                    type(of: oldBodyless) == type(of: newBodyless) {
                    existingNode.needsSetup = requiresSetupErased(old: oldBodyless, new: newBodyless)
                } else {
                    existingNode.needsSetup = true
                }
            }
            // Only elements that take part in the setup phase can need setup. (#235)
            existingNode.needsSetup = existingNode.needsSetup && element is any SetupElement
        }
        newNodes[currentId] = existingNode
        return existingNode
    }

    func makeNode(currentId: StructuralIdentifier, element: any Element, newNodes: inout [StructuralIdentifier: Node]) -> Node {
        let parentId = traversalContext.currentNode?.id
        let currentNode = Node(system: self, id: currentId, parentIdentifier: parentId, element: element)
        newNodes[currentId] = currentNode
        // New nodes need setup, unless the element takes no part in the setup phase. (#235)
        currentNode.needsSetup = element is any SetupElement
        return currentNode
    }

    func shouldUpdateNode(_ node: Node, with element: any Element, id: StructuralIdentifier) -> Bool {
        if isDirty(id) {
            return true
        }

        // requiresSetup is deliberately not consulted here: it only decides whether the setup phase
        // has to re-run, not whether the node changed.
        return !isEqual(node.element, element)
    }

    private func requiresSetupErased(old: any BodylessElement, new: any BodylessElement) -> Bool {
        // The generic helper recovers the concrete type that `any BodylessElement` erased.
        func helper<T: BodylessElement>(_ old: T, _ new: any BodylessElement) -> Bool {
            guard let new = new as? T else {
                return true
            }
            return new.requiresSetup(comparedTo: old)
        }

        return helper(old, new)
    }
}
