@testable import MetalSprockets
import Observation
import Testing

@MainActor
@Suite("@Observable support")
struct ObservationTests {
    @Observable
    final class Model {
        var count = 0
        var unread = 0
    }

    final class ValueRecorder {
        var values: [Int] = []
    }

    struct Leaf: Element, WorkloadElement, Equatable {
        let value: Int
        let recorder: ValueRecorder
        var body: Never { fatalError() }

        func workloadEnter(_ node: Node) throws {
            recorder.values.append(value)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.value == rhs.value && lhs.recorder === rhs.recorder
        }
    }

    struct ModelElement: Element {
        let model: Model
        let recorder: ValueRecorder

        var body: some Element {
            Leaf(value: model.count, recorder: recorder)
        }
    }

    @Test func `mutating an observed property read in body marks the node dirty`() throws {
        let model = Model()
        let system = System()
        try system.update(root: ModelElement(model: model, recorder: ValueRecorder()))
        #expect(system.dirtyIdentifiers.isEmpty)

        model.count += 1
        #expect(!system.dirtyIdentifiers.isEmpty)
    }

    @Test func `mutating a property the body never read does not mark the node dirty`() throws {
        let model = Model()
        let system = System()
        try system.update(root: ModelElement(model: model, recorder: ValueRecorder()))

        model.unread += 1
        #expect(system.dirtyIdentifiers.isEmpty)
    }

    @Test func `visiting children outside a system still evaluates the body`() throws {
        // No System is active, so observation tracking is skipped and the body is evaluated directly.
        #expect(System.current == nil)

        let recorder = ValueRecorder()
        var visited: [String] = []
        try ModelElement(model: Model(), recorder: recorder).visitChildren { child in
            visited.append("\(type(of: child))")
        }

        #expect(visited.count == 1)
        #expect(visited[0].contains("Leaf"))
    }

    @Test func `the body sees the new value after an observed change`() throws {
        let model = Model()
        let recorder = ValueRecorder()
        let renderer = FrameRenderer()
        let root = ModelElement(model: model, recorder: recorder)

        try renderer.renderFrame(root: root)
        model.count = 42
        try renderer.renderFrame(root: root)

        #expect(recorder.values == [0, 42])
    }
}
