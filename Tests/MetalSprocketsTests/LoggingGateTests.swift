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

    @Test func `withIntervalSignpost runs the task and returns its value with or without a signposter`() {
        // The module-level `signposter` globals latch on first use, so the only way to reach the signposting branch
        // is to pass a signposter in. Either way the wrapper has to be transparent: same value, run exactly once.
        var withoutCalls = 0
        let withoutSignposter = withIntervalSignpost(nil, name: "test") { () -> Int in
            withoutCalls += 1
            return 41
        }
        #expect(withoutSignposter == 41)
        #expect(withoutCalls == 1)

        let signposter = OSSignposter(subsystem: "io.schwa.metal-sprockets-tests", category: .pointsOfInterest)
        var withCalls = 0
        let withSignposter = withIntervalSignpost(signposter, name: "test") { () -> Int in
            withCalls += 1
            return 42
        }
        #expect(withSignposter == 42)
        #expect(withCalls == 1)
    }

    @Test func `withIntervalSignpost rethrows and still ends the interval`() {
        struct Boom: Error {
        }
        let signposter = OSSignposter(subsystem: "io.schwa.metal-sprockets-tests", category: .pointsOfInterest)
        #expect(throws: Boom.self) {
            try withIntervalSignpost(signposter, name: "test") {
                throw Boom()
            }
        }
        // A signposter left mid-interval would trip on the next use; this one still works.
        let value = withIntervalSignpost(signposter, name: "test") { 7 }
        #expect(value == 7)
    }
}
