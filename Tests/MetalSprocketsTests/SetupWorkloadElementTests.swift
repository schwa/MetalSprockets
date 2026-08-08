@testable import MetalSprockets
import Testing

@MainActor
@Suite("SetupElement / WorkloadElement split")
struct SetupWorkloadElementTests {
    final class PhaseRecorder {
        var calls: [String] = []
    }

    struct SetupOnly: Element, SetupElement {
        let recorder: PhaseRecorder
        var body: Never { fatalError() }

        func setupEnter(_ node: Node) throws {
            recorder.calls.append("setupEnter")
        }

        func setupExit(_ node: Node) throws {
            recorder.calls.append("setupExit")
        }
    }

    struct WorkloadOnly: Element, WorkloadElement {
        let recorder: PhaseRecorder
        var body: Never { fatalError() }

        func workloadEnter(_ node: Node) throws {
            recorder.calls.append("workloadEnter")
        }

        func workloadExit(_ node: Node) throws {
            recorder.calls.append("workloadExit")
        }
    }

    struct PhaseFreeLeaf: Element, BodylessElement {
        var body: Never { fatalError() }
    }

    @Test func `a setup-only element sees only the setup phase`() throws {
        let recorder = PhaseRecorder()
        let system = System()
        try system.update(root: SetupOnly(recorder: recorder))
        try system.processSetup()
        try system.processWorkload()
        #expect(recorder.calls == ["setupEnter", "setupExit"])
    }

    @Test func `a workload-only element sees only the workload phase`() throws {
        let recorder = PhaseRecorder()
        let system = System()
        try system.update(root: WorkloadOnly(recorder: recorder))
        try system.processSetup()
        try system.processWorkload()
        #expect(recorder.calls == ["workloadEnter", "workloadExit"])
    }

    @Test func `an element outside the setup phase never needs setup`() throws {
        let system = System()
        try system.update(root: WorkloadOnly(recorder: PhaseRecorder()))
        #expect(system.nodes.values.allSatisfy { $0.needsSetup == false })

        system.markAllNodesNeedingSetup()
        #expect(system.nodes.values.allSatisfy { $0.needsSetup == false })
    }

    @Test func `a setup element needs setup until the setup phase runs`() throws {
        let system = System()
        try system.update(root: SetupOnly(recorder: PhaseRecorder()))
        #expect(system.nodes.values.map(\.needsSetup).contains(true))

        try system.processSetup()
        #expect(system.nodes.values.allSatisfy { $0.needsSetup == false })

        system.markAllNodesNeedingSetup()
        #expect(system.nodes.values.map(\.needsSetup).contains(true))
    }

    @Test func `a bodyless element in neither phase is still traversed`() throws {
        let system = System()
        try system.update(root: PhaseFreeLeaf())
        try system.processSetup()
        try system.processWorkload()
        #expect(system.nodes.count == 1)
    }
}
