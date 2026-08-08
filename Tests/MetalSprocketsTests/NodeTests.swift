import Foundation
@testable import MetalSprockets
import Testing

@MainActor
@Suite
struct NodeTests {
    /// Parent links are interior mechanics; what they are *for* is environment reaching descendants. Assert that
    /// instead: a value written at the root shows up several levels down. See #375.
    @Test
    func environmentReachesNestedDescendants() throws {
        struct Reader: Element, SetupElement {
            var body: Never { fatalError() }

            func setupEnter(_ node: Node) throws {
                TestMonitor.shared.logUpdate(node.environmentValues.exampleValue)
            }

            func setupExit(_ node: Node) throws {
            }
        }

        struct GrandChild: Element {
            var body: some Element {
                Reader()
            }
        }

        struct Child: Element {
            var body: some Element {
                GrandChild()
            }
        }

        struct Parent: Element {
            var body: some Element {
                Child()
                    .environment(\.exampleValue, "from root")
            }
        }

        TestMonitor.shared.reset()
        let system = System()
        try system.render(root: Parent())

        #expect(TestMonitor.shared.updates == ["from root"])
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
