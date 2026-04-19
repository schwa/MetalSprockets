import Foundation
import os
@testable import MetalSprockets
import Testing

@Suite("System Snapshot Extended Tests")
struct SystemSnapshotExtendedTests {
    struct CounterLeaf: Element, BodylessElement {
        let value: Int
        var body: Never { fatalError() }
    }

    struct StatefulElement: Element {
        @MSState var counter: Int = 5
        @MSState var name: String = "hello"

        var body: some Element {
            // Read `counter` so StateBox registers this node as a dependency.
            CounterLeaf(value: counter)
        }
    }

    struct EnvReadingElement: Element {
        @MSEnvironment(\.exampleValue) var env

        var body: some Element {
            EmptyElement()
        }
    }

    @Test("Dirty nodes appear in snapshot")
    @MainActor
    func testDirtyNodes() throws {
        let system = System()
        let root = StatefulElement()
        try system.update(root: root)

        // Mutate state to dirty the node (body reads `counter` so StateBox tracks dependency).
        system.withCurrentSystem {
            root.counter = 42
        }

        #expect(!system.dirtyIdentifiers.isEmpty)

        let snapshot = system.snapshot()
        #expect(!snapshot.dirtyIdentifiers.isEmpty)

        let dump = snapshot.textDump()
        #expect(dump.contains("DIRTY NODES"))
    }

    @Test("textDump with NEEDS SETUP marker")
    @MainActor
    func testNeedsSetupMarkerInDump() throws {
        let system = System()
        try system.update(root: StatefulElement())
        // After update, before processSetup - nodes need setup.
        let dump = system.snapshot().textDump()
        #expect(dump.contains("NEEDS SETUP"))
    }

    @Test("textDump includes state values")
    @MainActor
    func testDumpIncludesStateValues() throws {
        let system = System()
        try system.update(root: StatefulElement())

        let dump = system.snapshot().textDump()
        #expect(dump.contains("State:"))
        #expect(dump.contains("_counter"))
        #expect(dump.contains("5"))
        #expect(dump.contains("hello"))
    }

    @Test("textDump includeEnvironment surfaces environment values")
    @MainActor
    func testDumpIncludesEnvironment() throws {
        let system = System()
        let root = EnvReadingElement().environment(\.exampleValue, "my-env-value")
        try system.update(root: root)

        let dump = system.snapshot().textDump(includeEnvironment: true)
        #expect(dump.contains("Environment"))
        #expect(dump.contains("my-env-value"))
    }

    @Test("logSnapshot does not crash")
    @MainActor
    func testLogSnapshot() throws {
        // Dirty a node to exercise the [DIRTY] branch in logSnapshot.
        let system = System()
        let root = StatefulElement()
        try system.update(root: root)
        system.withCurrentSystem { root.counter = 100 }

        let logger = Logger(subsystem: "MetalSprocketsTests", category: "SnapshotTest")
        system.logSnapshot(logger: logger)
    }

    @Test("Snapshot codable with state + environment")
    @MainActor
    func testCodableRoundTripPreservesDetails() throws {
        let system = System()
        let root = EnvReadingElement().environment(\.exampleValue, "codable-test")
        try system.update(root: root)

        let snapshot = system.snapshot()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SystemSnapshot.self, from: data)

        #expect(decoded.nodes.count == snapshot.nodes.count)
        #expect(decoded.orderedIdentifiers == snapshot.orderedIdentifiers)
    }
}
