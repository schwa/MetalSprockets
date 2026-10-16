import Foundation
import MetalSprocketsSupport
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
    package typealias PhaseTimings = CPUPhaseTimings

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

    /// Identifiers of nodes that must be set up again on the next update.
    ///
    /// Same rationale as `_dirtyIdentifiers`: invalidation can arrive from a non-owning isolation, and `Node` itself
    /// is not thread-safe, so the request is recorded here and applied to the nodes on the owning isolation at the
    /// start of `update(root:)`. See #385.
    private let _pendingSetupIdentifiers = OSAllocatedUnfairLock<Set<StructuralIdentifier>>(initialState: [])

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
        for node in nodes.values where node.typeInfo.isSetup {
            node.needsSetup = true
        }
    }

    /// Requests that `node` be set up again on the next update.
    ///
    /// Safe to call from any isolation; the flag is written to the node during the next update.
    internal func markNeedsSetup(_ id: StructuralIdentifier) {
        _pendingSetupIdentifiers.withLock { _ = $0.insert(id) }
    }

    /// Applies and clears any setup requests recorded by ``markNeedsSetup(_:)``. Owning isolation only.
    private func applyPendingSetupIdentifiers() {
        let pending = _pendingSetupIdentifiers.withLock { pending -> Set<StructuralIdentifier> in
            let taken = pending
            pending.removeAll()
            return taken
        }
        for id in pending {
            nodes[id]?.needsSetup = true
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
        renderCount += 1
        let frame = renderCount
        let updateStart = CACurrentMediaTime()
        // Each interval carries the frame number, so a slow frame in Instruments matches the HUD's (#510).
        let update = frameSignposter.beginInterval("Update", id: frameSignposter.makeSignpostID(), "frame \(frame)")
        do {
            try self.update(root: root)
        } catch {
            frameSignposter.endInterval("Update", update, "failed")
            throw error
        }
        let nodeCount = nodes.count
        let createdCount = lastCreatedNodeCount
        frameSignposter.endInterval("Update", update, "nodes \(nodeCount), created \(createdCount)")
        let setupStart = CACurrentMediaTime()
        let timings = try withCurrentSystem {
            let setup = frameSignposter.beginInterval("Setup", id: frameSignposter.makeSignpostID(), "frame \(frame)")
            do {
                try processSetup()
            } catch {
                frameSignposter.endInterval("Setup", setup, "failed")
                throw error
            }
            frameSignposter.endInterval("Setup", setup)
            let workloadStart = CACurrentMediaTime()
            let workload = frameSignposter.beginInterval("Workload", id: frameSignposter.makeSignpostID(), "frame \(frame)")
            defer { frameSignposter.endInterval("Workload", workload) }
            try processWorkload()
            let end = CACurrentMediaTime()
            return PhaseTimings(update: setupStart - updateStart, setup: workloadStart - setupStart, workload: end - workloadStart)
        }
        lastPhaseTimings = timings
        return timings
    }

    /// Number of ``render(root:)`` calls, used as the frame number in signposts.
    private(set) var renderCount = 0

    /// Nodes created by the most recent update (not reused from the previous frame).
    private(set) var lastCreatedNodeCount = 0

    /// Timings of the most recent successful ``render(root:)``, for roots that render through another driver.
    package private(set) var lastPhaseTimings: PhaseTimings?

    internal func update(root: some Element) throws {
        assert(traversalContext.isEmpty)
        applyPendingSetupIdentifiers()
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
            // Usually every previous node was reused, so nothing was removed and no diff is needed.
            let removedIds = reconciliation.reusedCount == nodes.count ? [] : nodes.keys.filter { reconciliation.nodes[$0] == nil }
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

            lastCreatedNodeCount = reconciliation.nodes.count - reconciliation.reusedCount
            self.nodes = reconciliation.nodes
            self.traversalEvents = reconciliation.events
            // Again, to pick up invalidation that happened during this update (e.g. a dynamic property calling
            // `invalidate()` while its element was being evaluated), so setup still sees it this frame.
            applyPendingSetupIdentifiers()

            snapshotter.dumpSnapshotIfNeeded(self)
        }
    }
}

// MARK: - Node Processing

internal extension System {
    /// Determine whether to reuse an existing node or create a new one
    /// `isEqualToPrevious` is the caller's `isEqual` result for the previous element, so it is not computed twice.
    /// `previousNode` is the previous traversal's node with the same identifier, or nil.
    func processNode(currentId: StructuralIdentifier, previousNode: Node?, element: any Element, isEqualToPrevious: Bool, newNodes: inout [StructuralIdentifier: Node]) -> Node {
        if let previousNode {
            return reuseNode(previousNode, currentId: currentId, element: element, isEqualToPrevious: isEqualToPrevious, newNodes: &newNodes)
        }
        return makeNode(currentId: currentId, element: element, newNodes: &newNodes)
    }

    /// Reuse an existing node, updating it if its element has changed
    func reuseNode(_ existingNode: Node, currentId: StructuralIdentifier, element: any Element, isEqualToPrevious: Bool, newNodes: inout [StructuralIdentifier: Node]) -> Node {
        existingNode.parentIdentifier = traversalContext.currentNode?.id

        if isDirty(currentId) || !isEqualToPrevious {
            let oldElement = existingNode.element
            existingNode.element = element
            // Setup-phase values (e.g. renderPipelineState) must survive an element change, so only
            // inherited values are cleared.
            existingNode.environmentValues.removeInheritedValues()

            // An already-set needsSetup (e.g. from markAllNodesNeedingSetup) is preserved.
            if !existingNode.needsSetup, existingNode.typeInfo.isSetup {
                if let oldBodyless = oldElement as? any BodylessElement,
                   let newBodyless = element as? any BodylessElement,
                   type(of: oldBodyless) == type(of: newBodyless) {
                    existingNode.needsSetup = requiresSetupErased(old: oldBodyless, new: newBodyless)
                } else {
                    existingNode.needsSetup = true
                }
            }
            // Only elements that take part in the setup phase can need setup. (#235)
            existingNode.needsSetup = existingNode.needsSetup && existingNode.typeInfo.isSetup
        }
        newNodes[currentId] = existingNode
        return existingNode
    }

    func makeNode(currentId: StructuralIdentifier, element: any Element, newNodes: inout [StructuralIdentifier: Node]) -> Node {
        let parentId = traversalContext.currentNode?.id
        let currentNode = Node(system: self, id: currentId, parentIdentifier: parentId, element: element)
        newNodes[currentId] = currentNode
        // New nodes need setup, unless the element takes no part in the setup phase. (#235)
        currentNode.needsSetup = currentNode.typeInfo.isSetup
        return currentNode
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
