import Foundation

/// The product of one reconciliation pass over an element tree.
internal struct Reconciliation {
    /// The nodes making up the new tree, keyed by structural identifier.
    var nodes: [StructuralIdentifier: Node]
    /// The new traversal events, in pre-order enter/exit pairs.
    var events: [TraversalEvent]
}

/// Diffs an element tree against the previous traversal and produces the new node dictionary and traversal events.
///
/// One reconciler instance performs one pass; the mutable walk state (atom stack, sibling indices, previous-identifier
/// iterator) is stored on the instance rather than captured by nested closures. The reconciler reads the previous
/// tree from its ``System`` and reuses or creates nodes, but it does not install the result — ``System/update(root:)``
/// does that.
internal final class TreeReconciler {
    private let system: System

    /// Identifiers entered by the previous traversal, in pre-order, consumed in lock-step with this walk.
    private var previousIterator: IndexingIterator<[StructuralIdentifier]>
    private var newEvents: [TraversalEvent] = []
    private var newNodes: [StructuralIdentifier: Node] = [:]
    /// Atoms for the path from the root to the element currently being processed.
    private var atomStack: [StructuralIdentifier.Atom] = []
    /// Per-level sibling counts, used to give same-typed siblings distinct identities.
    private var siblingIndices: [[ElementTypeIdentifier: Int]] = [[:]]

    init(system: System) {
        self.system = system
        let previousIdentifiers = system.traversalEvents.compactMap { event -> StructuralIdentifier? in
            guard case .enter(let node) = event else {
                return nil
            }
            return node.id
        }
        self.previousIterator = previousIdentifiers.makeIterator()
    }

    /// Walk `root`, reconciling it against the previous tree.
    ///
    /// Must be called with `system` installed as ``System/current``: element bodies and dynamic properties resolve
    /// environment and state through the active node stack while their nodes are being configured.
    func reconcile(root: some Element) throws -> Reconciliation {
        try processElement(root)
        return Reconciliation(nodes: newNodes, events: newEvents)
    }

    private func nextIndex(for typeIdentifier: ElementTypeIdentifier) -> Int {
        let currentLevel = siblingIndices.count - 1
        let index = siblingIndices[currentLevel][typeIdentifier] ?? 0
        siblingIndices[currentLevel][typeIdentifier] = index + 1
        return index
    }

    /// Splice a whole unchanged subtree from the previous traversal, reusing its nodes and events verbatim.
    /// Returns false if the subtree could not be located. See #370.
    private func spliceSubtree(_ id: StructuralIdentifier) -> Bool {
        guard let range = System.subtreeEventRange(for: id, in: system.traversalEvents) else {
            return false
        }
        var enteredCount = 0
        for event in system.traversalEvents[range] {
            newEvents.append(event)
            if case .enter(let node) = event {
                enteredCount += 1
                newNodes[node.id] = node
            }
        }
        // The subtree's root identifier was already consumed by the caller; consume the descendants so the
        // previous-identifier iterator stays aligned with the pre-order walk.
        for _ in 1..<max(enteredCount, 1) {
            _ = previousIterator.next()
        }
        return true
    }

    /// Process a single element.
    ///
    /// `environmentStable` says no ancestor changed the environment this update. Only then may a subtree be
    /// skipped: its elements read the environment while their bodies run, so a changed ancestor environment has
    /// to force re-evaluation even when the elements themselves compare equal.
    private func processElement(_ element: any Element, environmentStable: Bool = true) throws {
        let typeIdentifier = ElementTypeIdentifier(type(of: element))
        let index = nextIndex(for: typeIdentifier)
        // An explicit .id() replaces sibling position, so the element keeps its identity
        // when it moves within its parent.
        let explicitID = (element as? any ExplicitlyIdentifiedElement)?.explicitID
        let atom = StructuralIdentifier.Atom(typeIdentifier: typeIdentifier, index: explicitID == nil ? index : 0, explicitID: explicitID)

        atomStack.append(atom)
        defer { atomStack.removeLast() }

        let currentId = StructuralIdentifier(atoms: atomStack)
        let previousId = previousIterator.next()

        let previousNode = previousId == currentId ? system.nodes[currentId] : nil
        // Class elements never compare equal (their mutable stored properties are invisible to `isEqual`), so
        // they always re-evaluate; only their unchanged children get skipped.
        let unchanged = previousNode.map { !system.isDirty(currentId) && isEqual($0.element, element) } ?? false

        // A clean, unchanged subtree under an unchanged parent can be reused wholesale: no body evaluation, no
        // child walk. Dirty marks propagate to ancestors (#367), so a clean root implies a clean subtree.
        if unchanged, environmentStable, !system.isSubtreeDirty(currentId), spliceSubtree(currentId) {
            return
        }

        let currentNode = system.processNode(currentId: currentId, previousId: previousId, element: element, newNodes: &newNodes)

        newEvents.append(.enter(currentNode))
        system.traversalContext.push(currentNode)
        defer {
            system.traversalContext.pop()
            newEvents.append(.exit(currentNode))
        }

        try element.configureNode(currentNode)

        siblingIndices.append([:])
        defer { siblingIndices.removeLast() }

        let childEnvironmentStable = environmentStable && (unchanged || !(element is any EnvironmentModifyingElement))

        try element.visitChildren { child in
            try processElement(child, environmentStable: childEnvironmentStable)
        }
    }
}
