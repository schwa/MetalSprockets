@testable import MetalSprockets
import Testing

@MainActor
@Suite("Reading node")
struct ReadingNodeTests {
    final class Recorder {
        var readingNodeIdentifiers: [StructuralIdentifier] = []
    }

    struct Probe: Element {
        let recorder: Recorder

        var body: some Element {
            if let node = ReadingNode.current {
                recorder.readingNodeIdentifiers.append(node.id)
            }
            return EmptyElement()
        }
    }

    @Test func `the reading node is the node whose body is being evaluated`() throws {
        let recorder = Recorder()
        let system = System()
        try system.update(root: Probe(recorder: recorder))

        let probeNode = try #require(system.nodes.values.first { $0.element is Probe })
        #expect(recorder.readingNodeIdentifiers == [probeNode.id])
        #expect(!ReadingNode.isActive)
        #expect(ReadingNode.current == nil)
    }

    @Test func `environment reader reads its own node's environment`() throws {
        final class Box { var value: Int? }
        let box = Box()
        let root = EnvironmentReader(keyPath: \.readingNodeTestValue) { value in
            box.value = value
            return EmptyElement()
        }
        .environment(\.readingNodeTestValue, 42)
        let system = System()
        try system.update(root: root)
        #expect(box.value == 42)
    }
}

private struct ReadingNodeTestKey: MSEnvironmentKey {
    static let defaultValue = 0
}

private extension MSEnvironmentValues {
    var readingNodeTestValue: Int {
        get { self[ReadingNodeTestKey.self] }
        set { self[ReadingNodeTestKey.self] = newValue }
    }
}
