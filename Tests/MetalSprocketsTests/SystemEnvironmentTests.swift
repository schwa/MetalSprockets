import Foundation
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@Suite("SystemEnvironment")
struct SystemEnvironmentTests {
    @Test func `flags default to off in an empty environment`() {
        let environment = SystemEnvironment(variables: [:])
        #expect(environment.loggingEnabled == false)
        #expect(environment.verboseLoggingEnabled == false)
        #expect(environment.fatalErrorOnThrow == false)
        #expect(environment.metalLoggingEnabled == false)
        #expect(environment.dumpSnapshotsEnabled == false)
        #expect(environment.renderViewLogFrameEnabled == false)
    }

    @Test(arguments: ["1", "yes", "true", "y", "on", "ON", " True "])
    func `truthy spellings enable a flag`(value: String) {
        #expect(SystemEnvironment(variables: ["MS_LOGGING": value]).loggingEnabled)
    }

    @Test(arguments: ["0", "no", "false", "", "maybe"])
    func `other spellings leave a flag off`(value: String) {
        #expect(SystemEnvironment(variables: ["MS_LOGGING": value]).loggingEnabled == false)
    }

    @Test func `unprefixed aliases are honoured`() {
        #expect(SystemEnvironment(enabled: ["LOGGING"]).loggingEnabled)
        #expect(SystemEnvironment(enabled: ["VERBOSE"]).verboseLoggingEnabled)
    }

    @Test func `each flag reads its own variable`() {
        #expect(SystemEnvironment(enabled: ["MS_FATALERROR_ON_THROW"]).fatalErrorOnThrow)
        #expect(SystemEnvironment(enabled: ["MS_METAL_LOGGING"]).metalLoggingEnabled)
        #expect(SystemEnvironment(enabled: ["MS_DUMP_SNAPSHOTS"]).dumpSnapshotsEnabled)
        #expect(SystemEnvironment(enabled: ["MS_RENDERVIEW_LOG_FRAME"]).renderViewLogFrameEnabled)
        #expect(SystemEnvironment(enabled: ["MS_DUMP_SNAPSHOTS"]).metalLoggingEnabled == false)
    }

    @Test func `raw variables are readable by name`() {
        #expect(SystemEnvironment(variables: ["MS_LOGGING": "on"])["MS_LOGGING"] == "on")
        #expect(SystemEnvironment(variables: [:])["MS_LOGGING"] == nil)
    }

    @Test func `binding current overrides the process environment for the duration of a closure`() {
        SystemEnvironment.$current.withValue(SystemEnvironment(enabled: ["MS_DUMP_SNAPSHOTS"])) {
            #expect(SystemEnvironment.current.dumpSnapshotsEnabled)
        }
        #expect(SystemEnvironment.current.dumpSnapshotsEnabled == ProcessInfo.processInfo.dumpSnapshotsEnabled)
    }

    @Test func `an overridden environment reaches the snapshot dump gate`() throws {
        try SystemEnvironment.$current.withValue(SystemEnvironment(enabled: ["MS_DUMP_SNAPSHOTS"])) {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SystemEnvironmentTests-\(UUID().uuidString)")
            let fileURL = directory.appendingPathComponent("snapshots.jsonl")
            let snapshotter = Snapshotter(fileURL: fileURL)
            let system = System()
            try system.update(root: EmptyElement())

            snapshotter.dumpSnapshotIfNeeded(system)

            #expect(FileManager.default.fileExists(atPath: fileURL.path))
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
