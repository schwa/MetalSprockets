import Foundation
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

// `onCommandBufferScheduled` has no Metal 4 equivalent; `onSubmissionCommitted` reports the CPU commit instead.
@MainActor
@Suite("Submission Commit Notification Tests")
struct CommandBufferSchedulingTests {
    @Test("onSubmissionCommitted fires on commit with the submission identifier, before completion", .requiresMetal4)
    func committedHandlerFires() throws {
        final class Box: @unchecked Sendable {
            var events: [String] = []
            var committedIdentifier: UInt64?
        }
        let box = Box()
        let runner = try Runner()
        let recording = try runner.submit(
            EmptyElement()
                .onSubmissionCommitted { identifier in
                    box.committedIdentifier = identifier
                    box.events.append("committed")
                }
                .onCommandBufferCompleted { _ in
                    box.events.append("completed")
                }
        )
        let submission = recording
        #expect(box.committedIdentifier == submission.identifier)
        try submission.waitUntilCompleted()
        #expect(box.events == ["committed", "completed"])
    }

    @Test("Runner.run commits and waits", .requiresMetal4)
    func runCommitsAndWaits() throws {
        final class Box: @unchecked Sendable {
            var result: SubmissionResult?
        }
        let box = Box()
        try Runner().run(EmptyElement().onCommandBufferCompleted { box.result = $0 })
        #expect(box.result?.outcome == .completed)
    }

    @Test("Encoding failure never reports a commit", .requiresMetal4)
    func failedEncodingIsNotCommitted() throws {
        enum Failure: Error { case expected }
        let runner = try Runner()
        #expect(throws: Failure.expected) {
            try runner.submit(
                EmptyElement()
                    .onSubmissionCommitted { _ in Issue.record("Failed encoding must not report a commit") }
                    .onWorkloadEnter { _ in throw Failure.expected }
            )
        }
    }

    @Test("onSubmissionFinished fires when a committed recording completes", .requiresMetal4)
    func submissionFinishedFiresOnCompletion() throws {
        final class Box: @unchecked Sendable {
            var count = 0
        }
        let box = Box()
        let lock = NSLock()
        let recording = try Runner().submit(
            EmptyElement().onSubmissionFinished {
                lock.lock(); box.count += 1; lock.unlock()
            }
        )
        try recording.waitUntilCompleted()
        lock.lock(); let count = box.count; lock.unlock()
        #expect(count == 1)
    }

    @Test("onSubmissionFinished fires when encoding throws", .requiresMetal4)
    func submissionFinishedFiresOnEncodingFailure() throws {
        enum Failure: Error { case expected }
        final class Box: @unchecked Sendable {
            var count = 0
        }
        let box = Box()
        let lock = NSLock()
        #expect(throws: Failure.expected) {
            try Runner().submit(
                EmptyElement()
                    .onWorkloadEnter { _ in throw Failure.expected }
                    .onSubmissionFinished {
                        lock.lock(); box.count += 1; lock.unlock()
                    }
            )
        }
        lock.lock(); let count = box.count; lock.unlock()
        #expect(count == 1)
    }

    @Test("Submission callbacks outside a root are reported")
    func callbacksWithoutRootThrow() throws {
        let system = System()
        try system.update(root: EmptyElement().onCommandBufferCompleted { _ in })
        try system.processSetup()
        #expect(throws: MetalSprocketsError.self) {
            try system.processWorkload()
        }
    }
}
