@testable import MetalSprockets
import Testing

@MainActor
struct ModifierContentReconciliationTests {
    final class Resource {}

    struct Leaf: Element {
        var value: Int
        var resource: Resource

        var body: some Element {
            EmptyElement()
        }
    }

    @Test
    func `debug group refreshes changed content`() throws {
        try checkContentUpdates { $0.debugGroup("unchanged label") }
    }

    @Test
    func `depth bias refreshes changed content`() throws {
        try checkContentUpdates { $0.depthBias(1, slopeScale: 2, clamp: 3) }
    }

    @Test
    func `nested modifiers refresh changed content`() throws {
        try checkContentUpdates { $0.depthBias(1).debugGroup("unchanged label") }
    }

    private func checkContentUpdates<Content: Element>(_ wrap: (Leaf) -> Content) throws {
        let system = System()
        let firstResource = Resource()
        let secondResource = Resource()
        let frames = [
            Leaf(value: 1, resource: firstResource),
            Leaf(value: 2, resource: firstResource),
            Leaf(value: 2, resource: secondResource),
            Leaf(value: 1, resource: firstResource)
        ]

        for frame in frames {
            try system.update(root: wrap(frame))
            let leaves = system.nodes.values.compactMap { $0.element as? Leaf }
            let leaf = try #require(leaves.first)
            #expect(leaves.count == 1)
            #expect(leaf.value == frame.value)
            #expect(leaf.resource === frame.resource)
        }
    }

    @Test
    func `unchanged modifier content still compares equal`() {
        let leaf = Leaf(value: 1, resource: Resource())
        #expect(isEqual(leaf.debugGroup("label"), leaf.debugGroup("label")))
        #expect(isEqual(leaf.depthBias(1), leaf.depthBias(1)))
        #expect(!isEqual(leaf.debugGroup("first"), leaf.debugGroup("second")))
        #expect(!isEqual(leaf.depthBias(1), leaf.depthBias(2)))
        #expect(!isEqual(leaf.depthBias(1, slopeScale: 2), leaf.depthBias(1, slopeScale: 3)))
        #expect(!isEqual(leaf.depthBias(1, clamp: 2), leaf.depthBias(1, clamp: 3)))
    }
}
