import Foundation
import MetalSprocketsSupport
import os
import Testing

@Suite("Verbose logging gate")
struct LoggingGateTests {
    private let logger = Logger(subsystem: "io.schwa.metal-sprockets-tests", category: "gate")

    @Test func `verbose is nil unless verbose logging is enabled`() {
        SystemEnvironment.$current.withValue(SystemEnvironment(variables: [:])) {
            #expect(logger.verbose == nil)
        }
    }

    @Test func `verbose returns the logger when MS_VERBOSE is set`() {
        SystemEnvironment.$current.withValue(SystemEnvironment(enabled: ["MS_VERBOSE"])) {
            #expect(logger.verbose != nil)
        }
    }

    @Test func `the unprefixed VERBOSE alias works too`() {
        SystemEnvironment.$current.withValue(SystemEnvironment(enabled: ["VERBOSE"])) {
            #expect(logger.verbose != nil)
        }
    }
}
