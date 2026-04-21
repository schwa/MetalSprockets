import Foundation
@testable import MetalSprockets
import Testing

@MainActor
@Suite
struct NodeTests {
    @Test
    func testParentIdentifierIsSet() throws {
        struct Parent: Element {
            var body: some Element {
                Child()
            }
        }

        struct Child: Element {
            var body: some Element {
                GrandChild()
            }
        }

        struct GrandChild: Element {
            var body: some Element {
                EmptyElement()
            }
        }

        let system = System()
        let root = Parent()

        try system.update(root: root)

        // Root should have no parent
        let rootNode = system.nodes[system.orderedIdentifiers[0]]
        #expect(rootNode?.parentIdentifier == nil)

        // Child should have root as parent
        let childNode = system.nodes[system.orderedIdentifiers[1]]
        #expect(childNode?.parentIdentifier == system.orderedIdentifiers[0])

        // GrandChild should have child as parent
        let grandChildNode = system.nodes[system.orderedIdentifiers[2]]
        #expect(grandChildNode?.parentIdentifier == system.orderedIdentifiers[1])

        // EmptyElement should have grandchild as parent
        let emptyNode = system.nodes[system.orderedIdentifiers[3]]
        #expect(emptyNode?.parentIdentifier == system.orderedIdentifiers[2])
    }

    // MARK: - NodeElementCache (per-node typed cache)

    private final class FakeCacheA: NodeElementCache {
        var value = 0
    }

    private final class FakeCacheB: NodeElementCache {
        var label = ""
    }

    @Test("Node.cache returns the same instance on repeat access")
    func nodeCacheReturnsSameInstance() {
        struct Leaf: Element {
            var body: some Element { EmptyElement() }
        }

        let system = System()
        let node = Node(system: system, id: StructuralIdentifier(atoms: []), element: Leaf())

        let first = node.cache(FakeCacheA.self) { FakeCacheA() }
        first.value = 42
        let second = node.cache(FakeCacheA.self) { FakeCacheA() }

        #expect(first === second)
        #expect(second.value == 42)
    }

    @Test("Node.cache replaces the slot when a different cache type is requested")
    func nodeCacheReplacesOnTypeChange() {
        struct Leaf: Element {
            var body: some Element { EmptyElement() }
        }

        let system = System()
        let node = Node(system: system, id: StructuralIdentifier(atoms: []), element: Leaf())

        let a = node.cache(FakeCacheA.self) { FakeCacheA() }
        a.value = 42

        let b = node.cache(FakeCacheB.self) { FakeCacheB() }
        b.label = "hello"

        // Asking for A again now builds a fresh one (old one was evicted).
        let a2 = node.cache(FakeCacheA.self) { FakeCacheA() }
        #expect(a2 !== a)
        #expect(a2.value == 0)
    }
}
