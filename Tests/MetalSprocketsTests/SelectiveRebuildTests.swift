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

        // Known issue: update traversal always re-evaluates every body, so ConstantChild is
        // rebuilt too. Subtree skipping is still open (#197).
        withKnownIssue {
            #expect(TestMonitor.shared.updates == ["root-body", "dynamic-body-1"])
        }
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

        // Known issue: see #196. Binding equality is already stable (StateBox vends one
        // MSBinding), but the traversal re-evaluates the child's body regardless.
        withKnownIssue {
            #expect(TestMonitor.shared.updates == ["parent-body"])
        }
    }
}
