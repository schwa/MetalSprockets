@testable import MetalSprockets
import Testing

// Regression tests for #197 (stateless elements rebuilt on every parent update) and
// #196 (a binding passed but unused forcing a child rebuild).
@Suite(.serialized)
@MainActor
struct SelectiveRebuildTests {
    struct Container<Content>: Element where Content: Element {
        var content: Content

        init(@ElementBuilder content: () throws -> Content) rethrows {
            self.content = try content()
        }

        var body: some Element {
            content
        }
    }

    final class Root: Element {
        @MSState var counter = 0

        var body: some Element {
            TestMonitor.shared.logUpdate("root-body")
            return Container {
                ConstantChild()
                DynamicChild(value: counter)
            }
        }
    }

    struct ConstantChild: Element {
        var body: some Element {
            TestMonitor.shared.logUpdate("constant-body")
            return EmptyElement()
        }
    }

    struct DynamicChild: Element {
        var value: Int

        var body: some Element {
            TestMonitor.shared.logUpdate("dynamic-body-\(value)")
            return EmptyElement()
        }
    }

    @Test("Stateless children do not rebuild when a parent's state changes")
    func statelessChildDoesNotRebuild() throws {
        TestMonitor.shared.reset()
        let system = System()
        let root = Root()

        try system.update(root: root)
        #expect(TestMonitor.shared.updates == ["root-body", "constant-body", "dynamic-body-0"])

        TestMonitor.shared.reset()
        system.withCurrentSystem {
            root.counter = 1
        }
        try system.update(root: root)

        // Clean subtrees are spliced from the previous traversal, so ConstantChild's body is not
        // re-evaluated (#370).
        #expect(TestMonitor.shared.updates == ["root-body", "dynamic-body-1"])
    }

    final class BindingRoot: Element {
        @MSState var value = 0

        var body: some Element {
            TestMonitor.shared.logUpdate("parent-body")
            return Container {
                UnusedBindingChild(value: $value)
            }
        }
    }

    struct UnusedBindingChild: Element {
        @MSBinding var value: Int

        var body: some Element {
            TestMonitor.shared.logUpdate("child-body")
            return EmptyElement()
        }
    }

    @Test("A child holding an unused binding does not rebuild when the parent's state changes")
    func unusedBindingDoesNotRebuildChild() throws {
        TestMonitor.shared.reset()
        let system = System()
        let root = BindingRoot()

        try system.update(root: root)
        #expect(TestMonitor.shared.updates == ["parent-body", "child-body"])

        TestMonitor.shared.reset()
        system.withCurrentSystem {
            root.value = 1
        }
        try system.update(root: root)

        // Binding equality is stable (a StateBox vends one MSBinding), so the child's subtree is clean and
        // unchanged and gets spliced rather than re-evaluated (#196, #371).
        #expect(TestMonitor.shared.updates == ["parent-body"])
    }

    // MARK: - Skipping edge cases (#371)

    struct Branching: Element {
        var showsFirst: Bool

        var body: some Element {
            if showsFirst {
                NamedChild(name: "first")
            } else {
                NamedChild(name: "second")
            }
            NamedChild(name: "constant")
        }
    }

    struct NamedChild: Element {
        var name: String

        var body: some Element {
            TestMonitor.shared.logUpdate("\(name)-body")
            return EmptyElement()
        }
    }

    @Test("A conditional branch switch rebuilds the branch but not its unchanged sibling")
    func conditionalBranchSwitch() throws {
        TestMonitor.shared.reset()
        let system = System()
        try system.update(root: Branching(showsFirst: true))
        #expect(TestMonitor.shared.updates == ["first-body", "constant-body"])

        TestMonitor.shared.reset()
        try system.update(root: Branching(showsFirst: false))
        #expect(TestMonitor.shared.updates.contains("second-body"))
        #expect(!TestMonitor.shared.updates.contains("constant-body"))
    }

    struct Removing: Element {
        var includesExtra: Bool

        var body: some Element {
            NamedChild(name: "kept")
            if includesExtra {
                NamedChild(name: "extra")
            }
        }
    }

    @Test("Removing a child drops its nodes while skipping is active")
    func nodeRemoval() throws {
        TestMonitor.shared.reset()
        let system = System()
        try system.update(root: Removing(includesExtra: true))
        let identifiersWithExtra = Set(system.nodes.keys)

        try system.update(root: Removing(includesExtra: false))
        let identifiersWithoutExtra = Set(system.nodes.keys)

        #expect(identifiersWithoutExtra.count < identifiersWithExtra.count)
        #expect(identifiersWithoutExtra.isSubset(of: identifiersWithExtra))

        // Putting it back restores the same identifiers.
        try system.update(root: Removing(includesExtra: true))
        #expect(Set(system.nodes.keys) == identifiersWithExtra)
    }

    struct Reordering: Element {
        var reversed: Bool

        var body: some Element {
            if reversed {
                NamedChild(name: "b").id("b")
                NamedChild(name: "a").id("a")
            } else {
                NamedChild(name: "a").id("a")
                NamedChild(name: "b").id("b")
            }
        }
    }

    @Test("Elements moved by explicit .id() keep their nodes while skipping is active")
    func explicitIDMove() throws {
        TestMonitor.shared.reset()
        let system = System()
        try system.update(root: Reordering(reversed: false))
        let identifiersBefore = Set(system.nodes.keys)

        TestMonitor.shared.reset()
        try system.update(root: Reordering(reversed: true))

        // Identity is pinned to the explicit id, so reordering neither creates nor drops nodes.
        #expect(Set(system.nodes.keys) == identifiersBefore)
        // Both moved elements are re-evaluated: the pre-order walk no longer lines up with the previous one.
        #expect(TestMonitor.shared.updates.sorted() == ["a-body", "b-body"])
    }
}
