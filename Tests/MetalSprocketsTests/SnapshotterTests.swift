import Foundation
@testable import MetalSprockets
import Testing

@Suite("Snapshotter Tests")
struct SnapshotterTests {
    struct TestElement: Element {
        @MSState var counter: Int = 0

        var body: some Element {
            EmptyElement()
        }
    }

    @Test("dumpSnapshotIfNeeded is a no-op when disabled")
    @MainActor
    func disabledIsNoOp() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ms-snapshotter-disabled-\(UUID().uuidString).uvsnapshots")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let snapshotter = Snapshotter(shouldDumpSnapshots: false, fileURL: tmp)

        let system = System()
        try system.update(root: TestElement())

        snapshotter.dumpSnapshotIfNeeded(system)
        snapshotter.dumpSnapshotIfNeeded(system)

        #expect(!FileManager.default.fileExists(atPath: tmp.path))
    }

    @Test("dumpSnapshotIfNeeded writes JSONL records when enabled")
    @MainActor
    func enabledWritesJSONL() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ms-snapshotter-enabled-\(UUID().uuidString).uvsnapshots")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let snapshotter = Snapshotter(shouldDumpSnapshots: true, fileURL: tmp)

        let system = System()
        try system.update(root: TestElement())

        snapshotter.dumpSnapshotIfNeeded(system)
        snapshotter.dumpSnapshotIfNeeded(system)
        snapshotter.dumpSnapshotIfNeeded(system)

        #expect(FileManager.default.fileExists(atPath: tmp.path))

        let contents = try String(contentsOf: tmp, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 3)

        // Each line should be valid JSON containing a "frame" object with a "number".
        for (index, line) in lines.enumerated() {
            let data = Data(line.utf8)
            let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let frame = parsed?["frame"] as? [String: Any]
            let number = frame?["number"] as? Int
            #expect(number == index + 1)
            #expect(parsed?["snapshot"] != nil)
        }
    }

    @Test("Logging milestone branch executes at frame 100")
    @MainActor
    func loggingMilestone() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ms-snapshotter-milestone-\(UUID().uuidString).uvsnapshots")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let snapshotter = Snapshotter(shouldDumpSnapshots: true, fileURL: tmp)
        let system = System()
        try system.update(root: TestElement())

        // Hit the `frameCounter == 1` log on the first call and the
        // `isMultiple(of: 100)` branch on the 100th call.
        for _ in 0..<100 {
            snapshotter.dumpSnapshotIfNeeded(system)
        }

        let contents = try String(contentsOf: tmp, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 100)
    }
}
