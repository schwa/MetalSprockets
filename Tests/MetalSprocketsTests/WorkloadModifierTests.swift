@testable import MetalSprockets
import Testing

/// `onWorkloadEnter` and `onWorkloadExit` on any element (#152).
@Suite
@MainActor
struct WorkloadModifierTests {
    final class Log: @unchecked Sendable {
        var events: [String] = []
    }

    struct Child: Element, WorkloadElement {
        typealias Body = Never
        let log: Log
        var body: Never { fatalError() }

        func workloadEnter(_ node: Node) throws {
            log.events.append("child")
        }
    }

    @Test
    func `exit runs after the content and enter runs before it`() throws {
        let log = Log()
        let root = Child(log: log)
            .onWorkloadEnter { _ in log.events.append("enter") }
            .onWorkloadExit { _ in log.events.append("exit") }
        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()
        #expect(log.events == ["enter", "child", "exit"])
    }

    @Test
    func `exit sees the environment`() throws {
        var seen: String?
        let root = Child(log: Log())
            .onWorkloadExit { environment in seen = environment.exampleValue }
            .environment(\.exampleValue, "outer")
        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()
        #expect(seen == "outer")
    }
}
