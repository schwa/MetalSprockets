@testable import MetalSprockets
import Testing

@MainActor
@Suite("FrameRenderer")
struct FrameRendererTests {
    final class PhaseRecorder {
        var calls: [String] = []
        var errorToThrow: Error?
    }

    struct RecordingLeaf: Element, SetupElement, WorkloadElement, Equatable {
        let recorder: PhaseRecorder
        var body: Never { fatalError() }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.recorder === rhs.recorder
        }

        func setupEnter(_ node: Node) throws {
            recorder.calls.append("setup")
        }

        func workloadEnter(_ node: Node) throws {
            if let error = recorder.errorToThrow {
                recorder.errorToThrow = nil
                throw error
            }
            recorder.calls.append("workload")
        }
    }

    struct Failure: Error {}

    @Test func `a frame runs update, setup then workload`() throws {
        let recorder = PhaseRecorder()
        let renderer = FrameRenderer()
        try renderer.renderFrame(root: RecordingLeaf(recorder: recorder))
        #expect(recorder.calls == ["setup", "workload"])
    }

    @Test func `setup runs once across frames until invalidated`() throws {
        let recorder = PhaseRecorder()
        let renderer = FrameRenderer()
        let root = RecordingLeaf(recorder: recorder)

        try renderer.renderFrame(root: root)
        try renderer.renderFrame(root: root)
        #expect(recorder.calls == ["setup", "workload", "workload"])

        renderer.invalidateSetup()
        try renderer.renderFrame(root: root)
        #expect(recorder.calls == ["setup", "workload", "workload", "setup", "workload"])
    }

    @Test func `phase timings are reported for each phase`() throws {
        let renderer = FrameRenderer()
        let timings = try renderer.renderFrame(root: RecordingLeaf(recorder: PhaseRecorder()))
        #expect(timings.update >= 0)
        #expect(timings.setup >= 0)
        #expect(timings.workload >= 0)
        #expect(timings.total == timings.update + timings.setup + timings.workload)
    }

    @Test func `a thrown error leaves the renderer usable for the next frame`() throws {
        let recorder = PhaseRecorder()
        let renderer = FrameRenderer()
        let root = RecordingLeaf(recorder: recorder)

        recorder.errorToThrow = Failure()
        #expect(throws: Failure.self) {
            try renderer.renderFrame(root: root)
        }
        #expect(System.current == nil)

        try renderer.renderFrame(root: root)
        #expect(recorder.calls.contains("workload"))
    }

    @Test func `lastGPUTime round-trips`() {
        let renderer = FrameRenderer()
        #expect(renderer.lastGPUTime == nil)
        renderer.lastGPUTime = 0.004
        #expect(renderer.lastGPUTime == 0.004)
    }
}
