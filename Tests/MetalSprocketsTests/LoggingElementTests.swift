import Foundation
@testable import MetalSprockets
import os
import Testing

@MainActor
@Suite("LoggingElement Tests")
struct LoggingElementTests {
    private let testLogger = Logger(subsystem: "MetalSprocketsTests", category: "LoggingElement")

    private func run(_ element: LoggingElement) throws {
        let system = System()
        try system.update(root: element)
        try system.processSetup()
        try system.processWorkload()
    }

    // MARK: - Phases coverage

    @Test("All phases with custom Logger")
    func testAllPhases() throws {
        try run(LoggingElement("all", phases: .all, logger: testLogger))
    }

    @Test("Setup only")
    func testSetupOnly() throws {
        try run(LoggingElement("setup", phases: .setup, logger: testLogger))
    }

    @Test("Workload only")
    func testWorkloadOnly() throws {
        try run(LoggingElement("workload", phases: .workload, logger: testLogger))
    }

    @Test("Enter phases only")
    func testEnterOnly() throws {
        try run(LoggingElement("enter", phases: .enter, logger: testLogger))
    }

    @Test("Exit phases only")
    func testExitOnly() throws {
        try run(LoggingElement("exit", phases: .exit, logger: testLogger))
    }

    @Test("Individual setupEnter phase")
    func testSetupEnter() throws {
        try run(LoggingElement("se", phases: .setupEnter, logger: testLogger))
    }

    @Test("Individual setupExit phase")
    func testSetupExit() throws {
        try run(LoggingElement("sx", phases: .setupExit, logger: testLogger))
    }

    @Test("Individual workloadEnter phase")
    func testWorkloadEnter() throws {
        try run(LoggingElement("we", phases: .workloadEnter, logger: testLogger))
    }

    @Test("Individual workloadExit phase")
    func testWorkloadExit() throws {
        try run(LoggingElement("wx", phases: .workloadExit, logger: testLogger))
    }

    @Test("No phases selected is a no-op")
    func testNoPhases() throws {
        try run(LoggingElement("none", phases: [], logger: testLogger))
    }

    @Test("Empty message uses phase name only")
    func testEmptyMessage() throws {
        try run(LoggingElement("", phases: .all, logger: testLogger))
    }

    // MARK: - Default (internal) logger path

    @Test("Without custom logger falls back to internal logger")
    func testInternalLoggerFallback() throws {
        // logger: nil -> customLogger is nil -> log() uses MetalSprockets.logger?.log().
        // This exercises the "else" branch of the log() method.
        try run(LoggingElement("internal-path", phases: .all))
    }

    // MARK: - Default-argument init

    @Test("Default init uses empty message and .all phases")
    func testDefaultInit() throws {
        try run(LoggingElement())
    }

    // MARK: - Phases OptionSet

    @Test("Phases rawValues are stable")
    func testPhasesRawValues() {
        #expect(LoggingElement.Phases.setupEnter.rawValue == 1)
        #expect(LoggingElement.Phases.setupExit.rawValue == 2)
        #expect(LoggingElement.Phases.workloadEnter.rawValue == 4)
        #expect(LoggingElement.Phases.workloadExit.rawValue == 8)
    }

    @Test("Composite phases")
    func testCompositePhases() {
        #expect(LoggingElement.Phases.setup.contains(.setupEnter))
        #expect(LoggingElement.Phases.setup.contains(.setupExit))
        #expect(LoggingElement.Phases.workload.contains(.workloadEnter))
        #expect(LoggingElement.Phases.workload.contains(.workloadExit))
        #expect(LoggingElement.Phases.enter.contains(.setupEnter))
        #expect(LoggingElement.Phases.enter.contains(.workloadEnter))
        #expect(LoggingElement.Phases.exit.contains(.setupExit))
        #expect(LoggingElement.Phases.exit.contains(.workloadExit))
        #expect(LoggingElement.Phases.all == [.setup, .workload])
    }

    // MARK: - requiresSetup

    @Test("requiresSetup is always false")
    func testRequiresSetup() {
        let a = LoggingElement("a", phases: .all, logger: testLogger)
        let b = LoggingElement("b", phases: .setup, logger: testLogger)
        #expect(a.requiresSetup(comparedTo: b) == false)
    }
}
