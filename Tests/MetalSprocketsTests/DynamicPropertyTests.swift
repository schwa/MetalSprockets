import Metal
@testable import MetalSprockets
import Testing

@MainActor
@Suite("MSDynamicProperty")
struct DynamicPropertyTests {
    /// A property that takes the protocol's default `update`, and records the context it was persisted with.
    @propertyWrapper
    struct RecordingProperty: MSDynamicProperty {
        final class Record {
            var persistCount = 0
            var environmentDevicePresent: Bool?
            var contextLabel: String?
            var shouldInvalidate = false
        }

        var wrappedValue: Int
        let record: Record

        // `update(in:)` is deliberately not implemented: the protocol's default should be used.

        nonmutating func persist(in context: MSDynamicPropertyContext) throws {
            record.persistCount += 1
            record.contextLabel = context.label
            record.environmentDevicePresent = context.environmentValues.device != nil
            if record.shouldInvalidate {
                context.invalidate()
            }
        }
    }

    struct Host: Element {
        @RecordingProperty var value: Int

        init(record: RecordingProperty.Record) {
            self._value = RecordingProperty(wrappedValue: 0, record: record)
        }

        var body: some Element {
            EmptyElement()
        }
    }

    @Test func `a property with no update implementation still gets persisted`() throws {
        let record = RecordingProperty.Record()
        let system = System()
        try system.update(root: Host(record: record))

        #expect(record.persistCount == 1)
        #expect(record.contextLabel == "_value")
    }

    @Test func `the context exposes the node's environment`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let record = RecordingProperty.Record()
        let system = System()

        try system.update(root: Host(record: record))
        #expect(record.environmentDevicePresent == false)

        try system.update(root: Host(record: record).device(device))
        #expect(record.environmentDevicePresent == true)
    }

    @Test func `invalidating from a property marks the node dirty and needing setup`() throws {
        let record = RecordingProperty.Record()
        record.shouldInvalidate = true
        let system = System()

        try system.update(root: Host(record: record))

        // update() clears dirty identifiers as it finishes, so the observable trace is needsSetup.
        #expect(system.nodes.values.map(\.needsSetup).contains(true))
    }

    @Test func `persisted values round-trip through the node`() throws {
        let system = System()
        try system.update(root: EmptyElement())
        let node = try #require(system.nodes.values.first)
        let context = MSDynamicPropertyContext(node: node, label: "_probe")

        #expect(context.persistedValue(forKey: "_probe") == nil)
        context.setPersistedValue(42, forKey: "_probe")
        #expect(context.persistedValue(forKey: "_probe") as? Int == 42)
        context.setPersistedValue(nil, forKey: "_probe")
        #expect(context.persistedValue(forKey: "_probe") == nil)
    }
}
