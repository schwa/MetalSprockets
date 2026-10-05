@testable import MetalSprockets
import Testing

// #479: reconciling a deep modifier chain must not compare each node's whole subtree again.
@MainActor
struct ReconciliationCostTests {
    final class Counter {
        var comparisons = 0
    }

    struct CountingLeaf: Element, Equatable {
        var counter: Counter

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.counter.comparisons += 1
            return true
        }

        var body: some Element {
            EmptyElement()
        }
    }

    // Like ParameterModifier: the content comes first, then a closure that never compares equal.
    struct ClosureModifier<Content: Element>: Element {
        var content: Content
        var action: () -> Void

        var body: some Element {
            content
        }
    }

    private func chain(depth: Int, leaf: CountingLeaf) -> any Element {
        var element: any Element = leaf
        for _ in 0..<depth {
            element = wrap(element)
        }
        return element
    }

    private func wrap(_ content: some Element) -> any Element {
        ClosureModifier(content: content) {}
    }

    @Test
    func `a modifier chain compares its leaf once per update`() throws {
        let counter = Counter()
        let system = System()
        let depth = 20
        try system.update(root: AnyElement(chain(depth: depth, leaf: CountingLeaf(counter: counter))))
        counter.comparisons = 0
        try system.update(root: AnyElement(chain(depth: depth, leaf: CountingLeaf(counter: counter))))
        #expect(counter.comparisons == 1)
    }

    @Test
    func `stored element fields are compared after cheaper fields`() {
        let counter = Counter()
        let leaf = CountingLeaf(counter: counter)
        #expect(!isEqual(ClosureModifier(content: leaf) {}, ClosureModifier(content: leaf) {}))
        #expect(counter.comparisons == 0)
    }
}
