import Metal
@testable import MetalSprockets
import Testing

@MainActor
@Suite("State box lifetime")
struct StateBoxLifetimeTests {
    struct Counter: Element {
        @MSState var count = 0
        let recorder: Recorder

        var body: some Element {
            recorder.observed = count
            return EmptyElement()
        }
    }

    final class Recorder {
        var observed = -1
    }

    @Test func `a dependency that has gone away is pruned on the next write`() throws {
        let recorder = Recorder()
        let element = Counter(recorder: recorder)
        let system = System()
        try system.update(root: element)

        // The node registered as a dependency while the body read `count`.
        system.withCurrentSystem {
            element.count = 1
        }
        #expect(system.isDirty(try #require(system.nodes.values.first?.id)) || system.dirtyIdentifiers.isEmpty == false)

        // Replace the tree so the original node is dropped, then write again: the stale weak reference is pruned
        // rather than resurrected.
        try system.update(root: EmptyElement())
        system.withCurrentSystem {
            element.count = 2
        }
    }

    @Test func `reading state off the traversal isolation does not attach to the node stack`() throws {
        let element = Counter(recorder: Recorder())
        let system = System()
        try system.update(root: element)

        let child = try #require(system.nodes.values.first { $0.parentIdentifier != nil })

        // Stand in for a traversal in flight on the owning isolation while a GPU completion handler touches state:
        // `System.current` is not installed, so the read must ignore the stack rather than attach to `child`.
        system.traversalContext.push(child)
        defer { system.traversalContext.pop() }

        _ = element.count
        element.count = 7
        #expect(system.isDirty(child.id) == false)
    }

    @Test func `writing after the system is gone is harmless`() throws {
        let element = Counter(recorder: Recorder())
        do {
            let system = System()
            try system.update(root: element)
        }
        // The system has been released; the box has been connected before, so this is teardown, not misuse.
        element.count = 99
        #expect(element.count == 99)
    }
}

@MainActor
@Suite("Bodyless element defaults")
struct BodylessElementDefaultTests {
    /// Conforms to both phase protocols but implements neither method, so the defaults run.
    struct SilentLeaf: Element, SetupElement, WorkloadElement {
        typealias Body = Never
        var marker: Int
    }

    @Test func `the default phase methods do nothing and do not throw`() throws {
        let system = System()
        try system.update(root: SilentLeaf(marker: 1))
        try system.processSetup()
        try system.processWorkload()
        #expect(system.nodes.count == 1)
    }

    @Test func `a non-Equatable bodyless element always asks for setup`() {
        // Without Equatable there is nothing to compare, so the default stays conservative.
        let a = SilentLeaf(marker: 1)
        #expect(a.requiresSetup(comparedTo: a))
    }

    /// Equatable, but the System compares it through a type-erased helper that only knows `BodylessElement`, so the
    /// unconstrained default runs and falls back to `isEqual`.
    struct EquatableLeaf: Element, SetupElement, Equatable {
        typealias Body = Never
        var marker: Int
    }

    @Test func `an equal element does not need setting up again`() throws {
        let system = System()
        try system.update(root: EquatableLeaf(marker: 1))
        try system.processSetup()
        #expect(system.nodes.values.map(\.needsSetup).contains(true) == false)

        // Same value: the erased comparison finds them equal and setup stays skipped.
        try system.update(root: EquatableLeaf(marker: 1))
        #expect(system.nodes.values.map(\.needsSetup).contains(true) == false)

        // Different value: setup is required again.
        try system.update(root: EquatableLeaf(marker: 2))
        #expect(system.nodes.values.map(\.needsSetup).contains(true))
    }
}
