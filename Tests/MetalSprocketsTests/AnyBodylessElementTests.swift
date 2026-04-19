import Foundation
@testable import MetalSprockets
import Testing

@MainActor
@Suite
struct AnyBodylessElementTests {
    // MARK: - AnyBodylessElement internal modifier chain

    @Test
    func testAnyBodylessElementCallsAllPhaseClosures() throws {
        TestMonitor.shared.reset()

        let modifier = AnyBodylessElement()
            .onSetupEnter { (_: Node) in
                TestMonitor.shared.logUpdate("setupEnter(node)")
            }
            .onSetupExit { (_: Node) in
                TestMonitor.shared.logUpdate("setupExit(node)")
            }
            .onWorkloadEnter { (_: Node) in
                TestMonitor.shared.logUpdate("workloadEnter(node)")
            }
            .onWorkloadExit { (_: Node) in
                TestMonitor.shared.logUpdate("workloadExit(node)")
            }

        let system = System()
        try system.update(root: modifier)
        try system.processSetup()
        try system.processWorkload()

        #expect(TestMonitor.shared.updates == [
            "setupEnter(node)",
            "setupExit(node)",
            "workloadEnter(node)",
            "workloadExit(node)"
        ])
    }

    @Test
    func testAnyBodylessElementNoArgOverloads() throws {
        TestMonitor.shared.reset()

        let modifier = AnyBodylessElement()
            .onSetupEnter {
                TestMonitor.shared.logUpdate("setupEnter()")
            }
            .onSetupExit {
                TestMonitor.shared.logUpdate("setupExit()")
            }
            .onWorkloadEnter {
                TestMonitor.shared.logUpdate("workloadEnter()")
            }
            .onWorkloadExit {
                TestMonitor.shared.logUpdate("workloadExit()")
            }

        let system = System()
        try system.update(root: modifier)
        try system.processSetup()
        try system.processWorkload()

        #expect(TestMonitor.shared.updates == [
            "setupEnter()",
            "setupExit()",
            "workloadEnter()",
            "workloadExit()"
        ])
    }

    @Test
    func testAnyBodylessElementUnsetClosuresAreSafe() throws {
        // Default AnyBodylessElement has no closures - should not crash.
        let system = System()
        try system.update(root: AnyBodylessElement())
        try system.processSetup()
        try system.processWorkload()
    }

    @Test
    func testAnyBodylessElementPropagatesThrownErrors() throws {
        struct Boom: Error {}
        let modifier = AnyBodylessElement()
            .onSetupEnter { throw Boom() }
        let system = System()
        try system.update(root: modifier)
        #expect(throws: Boom.self) {
            try system.processSetup()
        }
    }

    @Test
    func testAnyBodylessElementRequiresSetupIsAlwaysTrue() {
        let a = AnyBodylessElement()
        let b = AnyBodylessElement()
        #expect(a.requiresSetup(comparedTo: b) == true)
    }

    // MARK: - Public SetupModifier / WorkloadModifier

    struct Leaf: Element, BodylessElement {
        var body: Never { fatalError() }
    }

    @Test
    func testOnSetupEnterPublicModifier() throws {
        TestMonitor.shared.reset()
        let element = Leaf()
            .onSetupEnter { (_: MSEnvironmentValues) in
                TestMonitor.shared.logUpdate("setup")
            }
        let system = System()
        try system.update(root: element)
        try system.processSetup()
        try system.processWorkload()
        #expect(TestMonitor.shared.updates == ["setup"])
    }

    @Test
    func testOnWorkloadEnterPublicModifier() throws {
        TestMonitor.shared.reset()
        let element = Leaf()
            .onWorkloadEnter { (_: MSEnvironmentValues) in
                TestMonitor.shared.logUpdate("workload")
            }
        let system = System()
        try system.update(root: element)
        try system.processSetup()
        try system.processWorkload()
        #expect(TestMonitor.shared.updates == ["workload"])
    }

    @Test
    func testWorkloadModifierRequiresSetupIsFalse() {
        let a = WorkloadModifier(content: Leaf())
        let b = WorkloadModifier(content: Leaf())
        #expect(a.requiresSetup(comparedTo: b) == false)
    }

    @Test
    func testSetupModifierRequiresSetupIsTrue() {
        let a = SetupModifier(content: Leaf())
        let b = SetupModifier(content: Leaf())
        #expect(a.requiresSetup(comparedTo: b) == true)
    }
}
