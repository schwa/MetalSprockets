@testable import MetalSprockets
import Testing

@Suite
struct SystemTests {
    /// The identifier/node bookkeeping invariant every test used to repeat inline.
    private static func expectConsistentIdentifiers(_ system: System, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(Set(system.orderedIdentifiers) == Set(system.nodes.keys), sourceLocation: sourceLocation)
        #expect(system.orderedIdentifiers.count == Set(system.orderedIdentifiers).count, sourceLocation: sourceLocation)
        for id in system.orderedIdentifiers {
            #expect(system.nodes[id]?.id == id, sourceLocation: sourceLocation)
        }
    }

    struct TestElement: Element {
        var value: Int
        var body: Never { fatalError() }
    }

    struct ContainerElement: Element {
        var value: Int
        var childValue: Int

        var body: some Element {
            TestElement(value: childValue)
        }
    }

    struct MultiChildContainer: Element {
        var children: [Int]

        var body: some Element {
            ForEach(children, id: \.self) { value in
                TestElement(value: value)
            }
        }
    }

    @Test
    @MainActor
    func testSystemCreatesNodeForNewElement() throws {
        let system = System()
        let element = TestElement(value: 1)

        try system.render(root: element)

        #expect(system.orderedIdentifiers.count == 1)
        #expect(system.nodes.count == 1)
        Self.expectConsistentIdentifiers(system)

        let rootId = system.orderedIdentifiers[0]
        #expect((system.nodes[rootId]?.element as? TestElement)?.value == 1)
    }

    @Test
    @MainActor
    func testSystemDetectsUnchangedElement() throws {
        let system = System()
        let element1 = TestElement(value: 1)

        try system.render(root: element1)
        let node1 = system.nodes.values.first

        let element2 = TestElement(value: 1)
        try system.render(root: element2)

        #expect(system.nodes.count == 1)
        Self.expectConsistentIdentifiers(system)

        let node2 = system.nodes.values.first
        #expect(node2?.id == node1?.id)
        #expect((node2?.element as? TestElement)?.value == 1)
    }

    @Test
    @MainActor
    func testSystemDetectsChangedElementValue() throws {
        let system = System()
        let element1 = TestElement(value: 1)

        try system.render(root: element1)

        let element2 = TestElement(value: 2)
        try system.render(root: element2)

        #expect(system.orderedIdentifiers.count == 1)
        Self.expectConsistentIdentifiers(system)

        let node = system.nodes.values.first
        #expect((node?.element as? TestElement)?.value == 2)
    }

    @Test
    @MainActor
    func testSystemHandlesNestedElements() throws {
        let system = System()
        let container = ContainerElement(value: 1, childValue: 10)

        try system.render(root: container)

        #expect(system.orderedIdentifiers.count == 2)
        #expect(system.nodes.count == 2)
        Self.expectConsistentIdentifiers(system)

        let containerId = system.orderedIdentifiers[0]
        let containerNode = system.nodes[containerId]
        #expect((containerNode?.element as? ContainerElement)?.value == 1)

        let childId = system.orderedIdentifiers[1]
        let childNode = system.nodes[childId]
        #expect((childNode?.element as? TestElement)?.value == 10)

        #expect(containerId.atoms.count == 1)
        #expect(childId.atoms.count == 2)
    }

    @Test
    @MainActor
    func testSystemDetectsChildValueChange() throws {
        let system = System()

        let container1 = ContainerElement(value: 1, childValue: 10)
        try system.render(root: container1)

        let container2 = ContainerElement(value: 1, childValue: 20)
        try system.render(root: container2)

        #expect(system.orderedIdentifiers.count == 2)
        Self.expectConsistentIdentifiers(system)

        let containerId = system.orderedIdentifiers[0]
        let containerNode = system.nodes[containerId]
        #expect((containerNode?.element as? ContainerElement)?.value == 1)

        let childId = system.orderedIdentifiers[1]
        let childNode = system.nodes[childId]
        #expect((childNode?.element as? TestElement)?.value == 20)
    }

    @Test
    @MainActor
    func testSystemDetectsStructuralChanges() throws {
        let system = System()

        let container1 = MultiChildContainer(children: [1, 2])
        try system.render(root: container1)

        // Should have: container + ForEach + 2 * (IdentifiedElement + TestElement) = 6 nodes.
        // ForEach wraps each child in an IdentifiedElement so identity follows the data (#209).
        #expect(system.orderedIdentifiers.count == 6)
        Self.expectConsistentIdentifiers(system)

        let container2 = MultiChildContainer(children: [1, 2, 3])
        try system.render(root: container2)

        // Should now have: container + ForEach + 3 * (IdentifiedElement + TestElement) = 8 nodes
        #expect(system.orderedIdentifiers.count == 8)
        Self.expectConsistentIdentifiers(system)

        let newChildId = system.orderedIdentifiers[7]
        let newChildNode = system.nodes[newChildId]
        #expect((newChildNode?.element as? TestElement)?.value == 3)
    }
}
