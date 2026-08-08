@testable import MetalSprockets
import Testing

/// An `Optional` element sits above its wrapped element in the tree. Dynamic casts unwrap optionals,
/// so the Optional node used to match `any WorkloadElement`/`any SetupElement` through its wrapped
/// element and run that element's enter/exit twice — two live render command encoders per RenderPass.
/// See #381.
@MainActor
@Suite("Optional element phase participation")
struct OptionalWorkloadTests {
    final class Counters: @unchecked Sendable {
        var workload: [String] = []
        var setup: [String] = []
    }

    struct TrackedPass<Content>: Element, SetupElement, WorkloadElement, BodylessContentElement where Content: Element {
        let counters: Counters
        let content: Content

        init(counters: Counters, @ElementBuilder content: () -> Content) {
            self.counters = counters
            self.content = content()
        }

        func setupEnter(_ node: Node) throws {
            counters.setup.append("enter")
        }

        func setupExit(_ node: Node) throws {
            counters.setup.append("exit")
        }

        func workloadEnter(_ node: Node) throws {
            counters.workload.append("enter")
        }

        func workloadExit(_ node: Node) throws {
            counters.workload.append("exit")
        }
    }

    struct Leaf: Element {
        var value: Int
        var body: some Element {
            EmptyElement()
        }
    }

    struct Root: Element {
        var counters: Counters
        var value: Int?

        var body: some Element {
            if let value {
                TrackedPass(counters: counters) {
                    Leaf(value: value)
                }
            }
        }
    }

    @Test("A pass inside `if let` enters and exits exactly once per frame")
    func optionalWrappedPassRunsOnce() throws {
        let counters = Counters()
        let system = System()
        var transcript: [String] = []
        var expected: [String] = []
        for value in [nil, 1, 1, 2, nil, 3] {
            counters.workload = []
            try system.update(root: Root(counters: counters, value: value))
            try system.processSetup()
            try system.processWorkload()
            transcript.append("\(String(describing: value)): \(counters.workload.joined(separator: ","))")
            expected.append("\(String(describing: value)): \(value == nil ? "" : "enter,exit")")
        }
        #expect(transcript == expected)
    }

    @Test("Setup of a pass inside `if let` also runs once")
    func optionalWrappedPassSetsUpOnce() throws {
        let counters = Counters()
        let system = System()
        try system.update(root: Root(counters: counters, value: 1))
        try system.processSetup()
        #expect(counters.setup == ["enter", "exit"])
    }
}
