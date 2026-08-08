import Foundation
@testable import MetalSprockets
import Testing

@Suite("System Snapshot Tests")
struct SystemSnapshotTests {
    struct TestElement: Element {
        @MSState var counter: Int = 0

        var body: some Element {
            EmptyElement()
        }
    }

    struct ParentElement: Element {
        @MSState var name: String = "Parent"

        var body: some Element {
            TestElement()
            TestElement()
        }
    }

    @Test("Create basic snapshot")
    @MainActor
    func testBasicSnapshot() throws {
        let system = System()
        let root = ParentElement()

        try system.update(root: root)

        let snapshot = system.snapshot()

        #expect(!snapshot.nodes.isEmpty)
        #expect(snapshot.timestamp.timeIntervalSinceNow < 1) // Recent timestamp
    }

    @Test("Snapshot captures node hierarchy")
    @MainActor
    func testNodeHierarchy() throws {
        let system = System()
        let root = ParentElement()

        try system.update(root: root)

        let snapshot = system.snapshot()

        #expect(snapshot.nodes.count == 6) // 1 parent + 2 children

        let parentNode = snapshot.nodes.first { $0.elementType.contains("ParentElement") }
        #expect(parentNode != nil)
        #expect(parentNode?.parentIdentifier == nil) // Root has no parent

        let childNodes = snapshot.nodes.filter { $0.elementType.contains("TestElement") }
        #expect(childNodes.count == 3)

        let tupleNode = snapshot.nodes.first { $0.elementType.contains("TupleElement") }
        #expect(tupleNode != nil)
        #expect(tupleNode?.parentIdentifier == parentNode?.identifier)

        for child in childNodes.filter({ $0.elementType == "TestElement" }) {
            #expect(child.parentIdentifier == tupleNode?.identifier)
        }
    }

    @Test("Snapshot captures state properties")
    @MainActor
    func testStateCapture() throws {
        let system = System()
        let root = TestElement()

        try system.update(root: root)

        let snapshot = system.snapshot()

        let node = snapshot.nodes.first { $0.elementType.contains("TestElement") }
        #expect(node != nil)

        let counterState = node?.stateProperties.first { $0.key == "_counter" || $0.key == "counter" }
        #expect(counterState != nil)
        #expect(counterState?.value.contains("0") == true) // Initial value is 0
    }

    @Test("Codable works")
    @MainActor
    func testCodable() throws {
        let system = System()
        let root = ParentElement()

        try system.update(root: root)

        let snapshot = system.snapshot()

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)
        #expect(!data.isEmpty)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SystemSnapshot.self, from: data)
        #expect(decoded.nodes.count == snapshot.nodes.count)
    }

    @Test("Text dump works")
    @MainActor
    func testTextDump() throws {
        let system = System()
        let root = ParentElement()

        try system.update(root: root)

        let snapshot = system.snapshot()
        let dump = snapshot.textDump()

        #expect(dump.contains("SYSTEM SNAPSHOT"))
        #expect(dump.contains("NODE HIERARCHY"))
        #expect(dump.contains("ParentElement"))
        #expect(dump.contains("TestElement"))
    }

    @Test("System dump method")
    @MainActor
    func testSystemDump() throws {
        let system = System()
        let root = TestElement()

        try system.update(root: root)

        system.dump()
        system.dump(includeEnvironment: true)

        let snapshot = system.snapshot()
        #expect(!snapshot.nodes.isEmpty)
    }

    @Test("Snapshot with environment values", .disabled())
    @MainActor
    func testEnvironmentSnapshot() throws {
        struct EnvElement: Element {
            var body: some Element {
                EmptyElement()
            }
        }

        let system = System()
        let root = EnvElement()

        try system.update(root: root)

        let snapshot = system.snapshot()
        let dump = snapshot.textDump(includeEnvironment: true)

        #expect(dump.contains("Environment"))
        #expect(!snapshot.nodes.isEmpty)
    }
}
