@testable import MetalSprockets
import Testing

@MainActor
@Suite("System.render(root:)")
struct SystemRenderTests {
    final class PhaseRecorder {
        var calls: [String] = []
    }

    struct Recording: Element, SetupElement, WorkloadElement {
        let recorder: PhaseRecorder
        var body: Never { fatalError() }

        func setupEnter(_ node: Node) throws {
            recorder.calls.append("setup")
        }

        func workloadEnter(_ node: Node) throws {
            recorder.calls.append("workload")
        }
    }

    @Test func `render runs update, setup and workload in order`() throws {
        let recorder = PhaseRecorder()
        let system = System()
        try system.render(root: Recording(recorder: recorder))

        #expect(recorder.calls == ["setup", "workload"])
        #expect(system.nodes.count == 1)
    }

    @Test func `setup runs once across frames, workload every frame`() throws {
        let recorder = PhaseRecorder()
        let system = System()
        let root = Recording(recorder: recorder)
        try system.render(root: root)
        try system.render(root: root)

        #expect(recorder.calls == ["setup", "workload", "workload"])
    }

    @Test func `render reports per-phase timings`() throws {
        let system = System()
        let timings = try system.render(root: Recording(recorder: PhaseRecorder()))

        #expect(timings.update >= 0)
        #expect(timings.setup >= 0)
        #expect(timings.workload >= 0)
        #expect(timings.total >= timings.update)
    }
}
