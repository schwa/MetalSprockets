@testable import MetalSprockets
import Testing

@Suite
@MainActor
struct WorkloadEnabledTests {
    /// An element that counts how many times its workload phase runs.
    final class Counter: @unchecked Sendable {
        var enters = 0
        var exits = 0
    }

    struct Tracked: Element, BodylessElement {
        typealias Body = Never
        let counter: Counter
        var body: Never { fatalError() }

        func workloadEnter(_ node: Node) throws {
            counter.enters += 1
        }
        func workloadExit(_ node: Node) throws {
            counter.exits += 1
        }
    }

    // MARK: -

    @Test
    func enabled_runs_workload() throws {
        let counter = Counter()

        struct Root: Element {
            let counter: Counter
            var body: some Element {
                Tracked(counter: counter).workloadEnabled(true)
            }
        }

        let system = System()
        try system.update(root: Root(counter: counter))
        try system.processSetup()
        try system.processWorkload()

        #expect(counter.enters == 1)
        #expect(counter.exits == 1)
    }

    @Test
    func disabled_skips_workload_on_self() throws {
        let counter = Counter()

        struct Root: Element {
            let counter: Counter
            var body: some Element {
                Tracked(counter: counter).workloadEnabled(false)
            }
        }

        let system = System()
        try system.update(root: Root(counter: counter))
        try system.processSetup()
        try system.processWorkload()

        #expect(counter.enters == 0)
        #expect(counter.exits == 0)
    }

    @Test
    func disabled_skips_entire_subtree() throws {
        let outer = Counter()
        let inner = Counter()

        struct Inner: Element {
            let outer: WorkloadEnabledTests.Counter
            let inner: WorkloadEnabledTests.Counter
            var body: some Element {
                get throws {
                    try Group {
                        Tracked(counter: outer)
                        Tracked(counter: inner)
                    }
                }
            }
        }

        struct Root: Element {
            let outer: WorkloadEnabledTests.Counter
            let inner: WorkloadEnabledTests.Counter
            var body: some Element {
                Inner(outer: outer, inner: inner).workloadEnabled(false)
            }
        }

        let system = System()
        try system.update(root: Root(outer: outer, inner: inner))
        try system.processSetup()
        try system.processWorkload()

        #expect(outer.enters == 0)
        #expect(outer.exits == 0)
        #expect(inner.enters == 0)
        #expect(inner.exits == 0)
    }

    @Test
    func sibling_of_disabled_still_runs() throws {
        let disabled = Counter()
        let sibling = Counter()

        struct Root: Element {
            let disabled: Counter
            let sibling: Counter
            var body: some Element {
                get throws {
                    try Group {
                        Tracked(counter: disabled).workloadEnabled(false)
                        Tracked(counter: sibling)
                    }
                }
            }
        }

        let system = System()
        try system.update(root: Root(disabled: disabled, sibling: sibling))
        try system.processSetup()
        try system.processWorkload()

        #expect(disabled.enters == 0)
        #expect(sibling.enters == 1)
        #expect(sibling.exits == 1)
    }

    @Test
    func modifier_does_not_require_setup_on_flag_change() throws {
        // Property-level check: the modifier itself returns false from
        // requiresSetup when only the enabled flag differs, so repeated flag
        // toggles don't mark the modifier's own node as needing setup.
        struct Dummy: Element, BodylessElement {
            typealias Body = Never
            var body: Never { fatalError() }
        }
        let a = WorkloadEnabledModifier(content: Dummy(), enabled: true)
        let b = WorkloadEnabledModifier(content: Dummy(), enabled: false)
        #expect(a.requiresSetup(comparedTo: b) == false)
        #expect(b.requiresSetup(comparedTo: a) == false)
    }

    @Test
    func nested_disabled_inside_disabled_is_still_skipped() throws {
        let inner = Counter()

        struct Root: Element {
            let inner: Counter
            var body: some Element {
                Tracked(counter: inner)
                    .workloadEnabled(true)   // inner flag says enabled
                    .workloadEnabled(false)  // outer flag says disabled
            }
        }

        let system = System()
        try system.update(root: Root(inner: inner))
        try system.processSetup()
        try system.processWorkload()

        // Outer disabled wins — inner subtree is entirely skipped.
        #expect(inner.enters == 0)
    }

    @Test
    func enter_exit_balanced_when_enabled() throws {
        let counter = Counter()

        struct Root: Element {
            let counter: Counter
            var body: some Element {
                get throws {
                    try Group {
                        Tracked(counter: counter)
                        Tracked(counter: counter)
                        Tracked(counter: counter)
                    }
                    .workloadEnabled(true)
                }
            }
        }

        let system = System()
        try system.update(root: Root(counter: counter))
        try system.processSetup()
        try system.processWorkload()

        #expect(counter.enters == 3)
        #expect(counter.exits == 3)
    }
}
