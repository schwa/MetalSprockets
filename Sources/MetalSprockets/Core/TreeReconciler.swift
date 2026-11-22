import Foundation

/// The product of one reconciliation pass over an element tree.
internal struct Reconciliation {
    /// The nodes making up the new tree, keyed by structural identifier.
    var nodes: [StructuralIdentifier: Node]
    /// The new traversal events, in pre-order enter/exit pairs.
    var events: [TraversalEvent]
    /// How many nodes of the previous tree were reused. When it equals the previous node count, nothing was removed.
    var reusedCount: Int
    /// How many of the reused nodes came from unchanged subtrees spliced in without being visited (#370, #519).
    var splicedCount: Int
}

/// Diffs an element tree against the previous traversal and produces the new node dictionary and traversal events.
///
/// One reconciler instance does one pass. The instance stores the mutable walk state (atom stack, sibling indices,
/// previous-identifier iterator). Nested closures do not capture it. The reconciler reads the previous
/// tree from its ``System`` and reuses or creates nodes, but it does not install the result — ``System/update(root:)``
/// does that.
internal final class TreeReconciler {
    private let system: System

    /// Nodes entered by the previous traversal, in pre-order, consumed in lock-step with this walk.
    private let previousNodes: [Node]
    /// For each of `previousNodes`, the index of its `.enter` event in the previous traversal events.
    private let previousEnterIndices: [Int]
    /// Index of the next unconsumed entry in `previousNodes`.
    private var previousPosition = 0
    private var newEvents: [TraversalEvent] = []
    private var newNodes: [StructuralIdentifier: Node] = [:]
    private var reusedCount = 0
    private var splicedCount = 0
    /// Atoms for the path from the root to the element currently being processed.
    private var atomStack: [StructuralIdentifier.Atom] = []
    /// Path hashes matching `atomStack`, so each identifier's hash extends its parent's instead of rehashing the path.
    private var hashStack: [Int] = [StructuralIdentifier.rootHash]
    /// Sibling counts per element type, used to give same-typed siblings distinct identities. One flat stack for all
    /// levels (`levelStarts` marks where each level begins), so entering a node allocates nothing. Siblings have few
    /// distinct types, so a linear search within the level is cheap.
    private var siblingCounts: [(type: ElementTypeIdentifier, count: Int)] = []
    private var levelStarts: [Int] = [0]

    init(system: System) {
        self.system = system
        var previousNodes: [Node] = []
        var previousEnterIndices: [Int] = []
        previousNodes.reserveCapacity(system.traversalEvents.count / 2)
        previousEnterIndices.reserveCapacity(system.traversalEvents.count / 2)
        for (index, event) in system.traversalEvents.enumerated() {
            if case .enter(let node) = event {
                previousNodes.append(node)
                previousEnterIndices.append(index)
            }
        }
        self.previousNodes = previousNodes
        self.previousEnterIndices = previousEnterIndices
        // The new tree is usually the same size as the previous one; avoid rehashing as it grows.
        newNodes.reserveCapacity(previousNodes.count)
        newEvents.reserveCapacity(system.traversalEvents.count)
    }

    /// Walk `root`, reconciling it against the previous tree.
    ///
    /// Must be called inside ``System/withReadingContext(_:)``: element bodies and dynamic properties resolve
    /// environment and state through ``ReadingNode`` while their nodes are being configured.
    func reconcile(root: some Element) throws -> Reconciliation {
        try processElement(root)
        return Reconciliation(nodes: newNodes, events: newEvents, reusedCount: reusedCount, splicedCount: splicedCount)
    }

    private func nextIndex(for typeIdentifier: ElementTypeIdentifier) -> Int {
        var position = levelStarts[levelStarts.count - 1]
        while position < siblingCounts.count {
            if siblingCounts[position].type == typeIdentifier {
                let index = siblingCounts[position].count
                siblingCounts[position].count = index + 1
                return index
            }
            position += 1
        }
        siblingCounts.append((typeIdentifier, 1))
        return 0
    }

    private func nextPreviousNode() -> Node? {
        guard previousPosition < previousNodes.count else {
            return nil
        }
        defer { previousPosition += 1 }
        return previousNodes[previousPosition]
    }

    /// Splice the whole unchanged subtree of the previous node just consumed by ``nextPreviousNode()``, reusing its
    /// nodes and events verbatim. See #370.
    ///
    /// The subtree starts at that node's known `.enter` event, so splicing costs the subtree's size, not a search of
    /// every previous event (#519).
    private func spliceSubtree() {
        let events = system.traversalEvents
        var index = previousEnterIndices[previousPosition - 1]
        var depth = 0
        var enteredCount = 0
        repeat {
            let event = events[index]
            newEvents.append(event)
            switch event {
            case .enter(let node):
                depth += 1
                enteredCount += 1
                newNodes[node.id] = node
            case .exit:
                depth -= 1
            }
            index += 1
        } while depth > 0
        reusedCount += enteredCount
        splicedCount += enteredCount
        // The caller consumed the subtree's root; consume the descendants so `previousPosition` stays aligned with
        // the pre-order walk.
        previousPosition += enteredCount - 1
    }

    /// Whether `candidate`, the previous traversal's node at this position, has identifier `currentId`.
    ///
    /// A node's identifier is its parent node's identifier plus its own last atom, and identifiers never change.
    /// Sometimes the parent of the candidate is the node that the reconciler visits as the parent now. Then the paths
    /// are equal only when the last atoms are equal. It is not necessary to compare the shared prefix atom by atom
    /// (#497). In all other cases, compare the full paths.
    private func matches(_ candidate: Node, currentId: StructuralIdentifier, atom: StructuralIdentifier.Atom) -> Bool {
        if let parent = system.traversalContext.currentNode, candidate.parentNode === parent {
            return candidate.id.atoms.count == currentId.atoms.count && candidate.id.atoms.last == atom
        }
        return candidate.id == currentId
    }

    /// Process a single element.
    ///
    /// `environmentStable` says no ancestor changed the environment this update. Only then can the reconciler
    /// skip a subtree. Its elements read the environment while their bodies run. Thus, if the environment of an
    /// ancestor changes, the elements must run again, even when they compare equal.
    private func processElement(_ element: any Element, environmentStable: Bool = true, explicitID inheritedExplicitID: AnyElementID? = nil) throws {
        let typeInfo = ElementTypeInfo.of(element)
        if let transparentType = typeInfo.transparentType {
            try processElement(transparentType.transparentContent(of: element), environmentStable: environmentStable, explicitID: inheritedExplicitID)
            return
        }
        // `.id()` and ForEach wrap content in an IdentifiedElement. It has no behaviour of its own, so it gets no node:
        // its identity goes on its content's atom instead, saving one node per ForEach item. A wrapper around
        // already-identified content keeps its node, so both identities stay in the path.
        if inheritedExplicitID == nil, let wrapperType = typeInfo.identityWrapperType {
            let content = wrapperType.wrappedContent(of: element)
            if ElementTypeInfo.of(content).explicitlyIdentifiedType == nil {
                try processElement(content, environmentStable: environmentStable, explicitID: wrapperType.explicitID(of: element))
                return
            }
        }
        let typeIdentifier = ElementTypeIdentifier(type(of: element))
        // An explicit .id() replaces sibling position, so the element keeps its identity
        // when it moves within its parent. Identified elements do not take a sibling index, as before.
        let explicitID = inheritedExplicitID ?? typeInfo.explicitlyIdentifiedType?.explicitID(of: element)
        let index = explicitID == nil ? nextIndex(for: typeIdentifier) : 0
        let atom = StructuralIdentifier.Atom(typeIdentifier: typeIdentifier, index: index, explicitID: explicitID)

        atomStack.append(atom)
        let pathHash = StructuralIdentifier.extend(hashStack[hashStack.count - 1], with: atom)
        hashStack.append(pathHash)
        defer {
            atomStack.removeLast()
            hashStack.removeLast()
        }

        let currentId = StructuralIdentifier(atoms: atomStack, pathHash: pathHash)
        // The previous traversal's node at this position is reused when its identifier matches. One comparison, no
        // dictionary lookup (#497).
        let candidate = nextPreviousNode()
        let previousNode = candidate.flatMap { matches($0, currentId: currentId, atom: atom) ? $0 : nil }
        // Class elements never compare equal (their mutable stored properties are invisible to `isEqual`), so
        // they always re-evaluate; only their unchanged children get skipped.
        let isEqualToPrevious = previousNode.map { isEqual($0.element, element) } ?? false
        let unchanged = isEqualToPrevious && !system.isDirty(currentId)

        // A clean, unchanged subtree under an unchanged parent can be reused wholesale: no body evaluation, no
        // child walk. Dirty marks propagate to ancestors (#367), so a clean root implies a clean subtree.
        if unchanged, environmentStable, !system.isSubtreeDirty(currentId) {
            // `unchanged` implies `previousNode` is the candidate just consumed.
            spliceSubtree()
            return
        }

        if previousNode != nil {
            reusedCount += 1
        }
        let currentNode = system.processNode(currentId: currentId, previousNode: previousNode, element: element, isEqualToPrevious: isEqualToPrevious, newNodes: &newNodes)

        newEvents.append(.enter(currentNode))
        system.traversalContext.push(currentNode)
        defer {
            system.traversalContext.pop()
            newEvents.append(.exit(currentNode))
        }

        // Children see a stable environment when this node's writes are the same as last frame's, even if the element
        // itself compares unequal (it may hold a closure). Frame plumbing is ignored (#598).
        var writesStable = unchanged || !typeInfo.isEnvironmentModifying || typeInfo.writesFramePlumbing
        let previousOwnValues = !writesStable && previousNode != nil ? currentNode.environmentValues.ownValues : nil

        try element.configureNode(currentNode, context: system.traversalContext)

        if let previousOwnValues {
            writesStable = currentNode.environmentValues.ownValues.isSame(as: previousOwnValues)
        }

        levelStarts.append(siblingCounts.count)
        defer {
            siblingCounts.removeSubrange(levelStarts.removeLast()...)
        }

        let childEnvironmentStable = environmentStable && writesStable

        try element.visitChildren(node: currentNode, typeInfo: typeInfo) { child in
            try processElement(child, environmentStable: childEnvironmentStable)
        }
    }
}
