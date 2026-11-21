@testable import MetalSprockets
import Testing

// Unchanged subtrees are spliced from the previous traversal, and the splice is counted (#370, #519).
@MainActor
struct SubtreeSpliceTests {
    struct Leaf: Element, Equatable {
        var value: Int

        var body: some Element {
            EmptyElement()
        }
    }

    private func scene(values: [Int]) throws -> some Element {
        try Group {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Leaf(value: value)
            }
        }
    }

    @Test func `unchanged siblings are spliced and changed ones are not`() throws {
        let system = System()
        try system.update(root: scene(values: Array(0..<100)))
        let nodesPerLeaf = (system.nodes.count - 2) / 100

        try system.update(root: scene(values: Array(0..<100)))
        #expect(system.lastSplicedNodeCount == nodesPerLeaf * 100)

        var changed = Array(0..<100)
        changed[0] = -1
        changed[50] = -1
        try system.update(root: scene(values: changed))
        // Only the two changed leaves are visited; their unchanged children are still spliced.
        #expect(system.lastSplicedNodeCount == nodesPerLeaf * 100 - 2)
        #expect(system.nodes.count == nodesPerLeaf * 100 + 2)
    }
}
