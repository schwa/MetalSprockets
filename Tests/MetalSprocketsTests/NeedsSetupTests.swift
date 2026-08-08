import CoreGraphics
@testable import MetalSprockets
import Testing

@Suite(.serialized)
struct NeedsSetupTests {
    // Track setup calls
    final class SetupTrackingElement: Element, BodylessElement, Identifiable, Equatable {
        typealias Body = Never

        nonisolated(unsafe) static var globalSetupEnterCount = 0
        nonisolated(unsafe) static var globalSetupExitCount = 0

        let id: Int

        init(id: Int) {
            self.id = id
        }

        func setupEnter(_ node: Node) throws {
            Self.globalSetupEnterCount += 1
        }

        func setupExit(_ node: Node) throws {
            Self.globalSetupExitCount += 1
        }

        func workloadEnter(_ node: Node) throws {}
        func workloadExit(_ node: Node) throws {}

        static func == (lhs: SetupTrackingElement, rhs: SetupTrackingElement) -> Bool {
            lhs.id == rhs.id
        }

        static func resetCounts() {
            globalSetupEnterCount = 0
            globalSetupExitCount = 0
        }
    }

    final class StateElement: Element {
        @MSState var counter = 0

        var body: some Element {
            SetupTrackingElement(id: counter)
        }
    }

    @Test("Setup called when state changes")
    @MainActor
    func testSetupOnStateChange() throws {
        SetupTrackingElement.resetCounts()
        let system = System()
        let element = StateElement()

        // First update and setup
        try system.update(root: element)
        try system.processSetup()

        #expect(SetupTrackingElement.globalSetupEnterCount == 1)

        // Change state - this should trigger needsSetup
        system.withCurrentSystem {
            element.counter = 1
        }

        // Update should create a new child element with different ID
        try system.update(root: element)
        try system.processSetup()

        // New element should get setup
        #expect(SetupTrackingElement.globalSetupEnterCount == 2)
    }

    @Test("Mark all nodes needing setup works")
    @MainActor
    func testMarkAllNodesNeedingSetup() throws {
        SetupTrackingElement.resetCounts()
        let system = System()

        // Create a simple element tree
        let element = SetupTrackingElement(id: 1)

        // Initial setup
        try system.update(root: element)
        try system.processSetup()

        #expect(SetupTrackingElement.globalSetupEnterCount == 1)

        // Update with equivalent element - should reuse node
        try system.update(root: SetupTrackingElement(id: 1))
        try system.processSetup()

        // Should still be 1 since element is equivalent
        #expect(SetupTrackingElement.globalSetupEnterCount == 1)

        // Mark all nodes as needing setup (simulates drawable size change)
        system.markAllNodesNeedingSetup()
        try system.processSetup()

        // Should now be 2
        #expect(SetupTrackingElement.globalSetupEnterCount == 2)
    }

    @Test("Setup not called for unchanged equivalent elements")
    @MainActor
    func testNoSetupForEquivalentElements() throws {
        SetupTrackingElement.resetCounts()
        let system = System()

        // First update
        try system.update(root: SetupTrackingElement(id: 1))
        try system.processSetup()

        #expect(SetupTrackingElement.globalSetupEnterCount == 1)

        // Second update with equivalent element (same id)
        try system.update(root: SetupTrackingElement(id: 1))
        try system.processSetup()

        // Should still be 1
        #expect(SetupTrackingElement.globalSetupEnterCount == 1)

        // Third update with different element
        try system.update(root: SetupTrackingElement(id: 2))
        try system.processSetup()

        // Should now be 2
        #expect(SetupTrackingElement.globalSetupEnterCount == 2)
    }

    @Test("Video rendering scenario - multiple frames")
    @MainActor
    func testVideoRenderingEfficiency() throws {
        // Simulates OffscreenVideoRenderer calling processSetup every frame
        SetupTrackingElement.resetCounts()
        let system = System()

        // Simulate rendering 10 frames with the same element
        for _ in 0..<10 {
            try system.update(root: SetupTrackingElement(id: 1))
            try system.processSetup()
            try system.processWorkload()
        }

        // Setup should only have been called once (first frame)
        #expect(SetupTrackingElement.globalSetupEnterCount == 1)
    }

    // See #346: the key-path form of .environment() records key path + value so an unchanged
    // value no longer forces the setup phase to re-run.
    @Test("Equatable .environment() value drives requiresSetup")
    @MainActor
    func testEnvironmentModifierRequiresSetup() throws {
        let small = SetupTrackingElement(id: 1).environment(\.drawableSize, CGSize(width: 100, height: 100))
        let sameSmall = SetupTrackingElement(id: 1).environment(\.drawableSize, CGSize(width: 100, height: 100))
        let large = SetupTrackingElement(id: 1).environment(\.drawableSize, CGSize(width: 200, height: 200))

        let modifier = try #require(small as? EnvironmentWritingModifier<SetupTrackingElement>)
        let sameModifier = try #require(sameSmall as? EnvironmentWritingModifier<SetupTrackingElement>)
        let largeModifier = try #require(large as? EnvironmentWritingModifier<SetupTrackingElement>)

        #expect(sameModifier.requiresSetup(comparedTo: modifier) == false)
        #expect(largeModifier.requiresSetup(comparedTo: modifier))
    }

    @Test("Unchanged .environment() value does not re-run setup across frames")
    @MainActor
    func testEnvironmentModifierStableAcrossFrames() throws {
        SetupTrackingElement.resetCounts()
        let system = System()

        for _ in 0..<3 {
            try system.update(root: SetupTrackingElement(id: 1).environment(\.drawableSize, CGSize(width: 100, height: 100)))
            try system.processSetup()
        }

        #expect(SetupTrackingElement.globalSetupEnterCount == 1)
    }
}
