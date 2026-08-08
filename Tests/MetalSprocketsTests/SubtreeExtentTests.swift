import Foundation
@testable import MetalSprockets
import Testing

@MainActor
@Suite(.serialized)
struct SubtreeExtentTests {
    struct Leaf: Element {
        var body: some Element {
            EmptyElement()
        }
    }

    struct Branch: Element {
        var body: some Element {
            Leaf()
            Leaf()
        }
    }

    struct Root: Element {
        var body: some Element {
            Branch()
            Leaf()
        }
    }

    @Test
    func cleanSubtreesAreSplicedAcrossUpdates() throws {
        let system = System()
        let root = Root()
        try system.update(root: root)

        let identifiers = Set(system.nodes.keys)
        let nodesByIdentifier = system.nodes
        let eventCount = system.traversalEvents.count

        try system.update(root: root)

        #expect(Set(system.nodes.keys) == identifiers)
        #expect(system.traversalEvents.count == eventCount)
        for (identifier, node) in system.nodes {
            #expect(nodesByIdentifier[identifier] === node)
        }
    }

    @Test
    func subtreeExtentCoversNestedAndSiblingStructures() throws {
        let system = System()
        try system.update(root: Root())

        let events = system.traversalEvents
        let rootIdentifier = try #require(system.nodes.values.first { $0.parentIdentifier == nil }?.id)

        // The root's extent is the whole traversal.
        let rootRange = try #require(System.subtreeEventRange(for: rootIdentifier, in: events))
        #expect(rootRange == 0..<events.count)

        // Every node's extent is balanced and contains exactly its own subtree.
        for node in system.nodes.values {
            let range = try #require(System.subtreeEventRange(for: node.id, in: events))
            let slice = events[range]
            #expect(slice.count.isMultiple(of: 2))
            let containedNodes = slice.compactMap { event -> Node? in
                if case .enter(let entered) = event { return entered }
                return nil
            }
            for contained in containedNodes where contained.id != node.id {
                #expect(system.isDescendant(contained.id, of: node.id))
            }
            let expectedCount = system.nodes.values.count { $0.id == node.id || system.isDescendant($0.id, of: node.id) }
            #expect(containedNodes.count == expectedCount)
        }

        // Sibling subtrees are disjoint.
        let children = system.nodes.values.filter { $0.parentIdentifier == rootIdentifier }
        let ranges = try children.map { try #require(System.subtreeEventRange(for: $0.id, in: events)) }
        for (lhsIndex, lhs) in ranges.enumerated() {
            for rhs in ranges[(lhsIndex + 1)...] {
                #expect(!lhs.overlaps(rhs))
            }
        }

        // Helper accessors agree with the raw range.
        let branchIdentifier = try #require(children.first?.id)
        let subtreeEvents = try #require(system.previousSubtreeEvents(for: branchIdentifier))
        #expect(Array(subtreeEvents.indices) == Array(System.subtreeEventRange(for: branchIdentifier, in: events)!))
        let subtreeNodes = try #require(system.previousSubtreeNodes(for: branchIdentifier))
        #expect(subtreeNodes.first?.id == branchIdentifier)

        // Unknown identifiers have no extent.
        #expect(System.subtreeEventRange(for: StructuralIdentifier(atoms: []), in: events) == nil)
    }
}
