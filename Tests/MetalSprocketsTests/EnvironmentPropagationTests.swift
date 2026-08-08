@testable import MetalSprockets
import Testing

@MainActor
@Suite(.serialized)
struct EnvironmentPropagationTests {
    /// Writes a phase-specific value into its own environment, mirroring how `RenderPass` and
    /// `RenderPipeline` publish encoders and pipeline states to their descendants.
    private struct PhaseWriter<Content: Element>: Element, SetupElement, WorkloadElement, BodylessContentElement {
        var content: Content

        var body: Never {
            fatalError()
        }

        func setupEnter(_ node: Node) throws {
            node.environmentValues.exampleValue = "from setup"
        }

        func setupExit(_ node: Node) throws {
        }

        func workloadEnter(_ node: Node) throws {
            node.environmentValues.exampleValue = "from workload"
        }

        func workloadExit(_ node: Node) throws {
        }
    }

    private struct Recorder: Element, SetupElement, WorkloadElement {
        var body: Never {
            fatalError()
        }

        func setupEnter(_ node: Node) throws {
            TestMonitor.shared.logUpdate("setup:\(node.environmentValues.exampleValue)")
        }

        func setupExit(_ node: Node) throws {
        }

        func workloadEnter(_ node: Node) throws {
            TestMonitor.shared.logUpdate("workload:\(node.environmentValues.exampleValue)")
        }

        func workloadExit(_ node: Node) throws {
        }
    }

    /// Sits between the writer and the recorder, taking part in neither phase.
    private struct PassThrough<Content: Element>: Element {
        var content: Content

        var body: some Element {
            content
        }
    }

    @Test func `phase-time writes reach descendants through intermediate elements`() throws {
        TestMonitor.shared.reset()

        let system = System()
        try system.update(root: PhaseWriter(content: PassThrough(content: Recorder())))
        try system.processSetup()
        try system.processWorkload()

        #expect(TestMonitor.shared.updates == ["setup:from setup", "workload:from workload"])
    }

    @Test func `phase-time writes survive repeated updates`() throws {
        TestMonitor.shared.reset()

        let system = System()
        let root = PhaseWriter(content: PassThrough(content: Recorder()))
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()
        try system.update(root: root)
        try system.processWorkload()

        #expect(TestMonitor.shared.updates == ["setup:from setup", "workload:from workload", "workload:from workload"])
    }

    @Test func `update-phase writes reach descendants`() throws {
        TestMonitor.shared.reset()

        let system = System()
        try system.update(root: PassThrough(content: Recorder()).environment(\.exampleValue, "from update"))
        try system.processSetup()

        #expect(TestMonitor.shared.updates == ["setup:from update"])
    }
}
