import Foundation
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import os
import Testing

private final class ReleaseTracker: @unchecked Sendable {
    private let released = OSAllocatedUnfairLock(initialState: false)
    var isReleased: Bool { released.withLock { $0 } }
    func markReleased() { released.withLock { $0 = true } }
}

private final class TrackedOwner: Sendable {
    let tracker: ReleaseTracker
    init(_ tracker: ReleaseTracker) { self.tracker = tracker }
    deinit { tracker.markReleased() }
}

private final class ResultRecorder: @unchecked Sendable {
    private let results = OSAllocatedUnfairLock<[SubmissionResult]>(initialState: [])
    var all: [SubmissionResult] { results.withLock { $0 } }
    func append(_ result: SubmissionResult) { results.withLock { $0.append(result) } }
}

@Suite("Metal 4 submission completion coordination")
struct SubmissionCompletionTests {
    private func makeCompletion(owner: AnyObject? = nil) -> SubmissionCompletion {
        SubmissionCompletion(submissionIdentifier: 3, label: "frame", owners: owner.map { [$0] } ?? [])
    }

    @Test(arguments: [true, false])
    func successRequiresBothFeedbackAndEventInEitherOrder(_ feedbackFirst: Bool) {
        let tracker = ReleaseTracker()
        let completion = makeCompletion(owner: TrackedOwner(tracker))
        if feedbackFirst {
            completion.recordFeedback(error: nil, gpuStartTime: 10, gpuEndTime: 12)
            #expect(completion.resolvedResult == nil)
            #expect(!tracker.isReleased)
            completion.recordEvent()
        } else {
            completion.recordEvent()
            #expect(completion.resolvedResult == nil)
            #expect(!tracker.isReleased)
            completion.recordFeedback(error: nil, gpuStartTime: 10, gpuEndTime: 12)
        }
        let result = completion.resolvedResult
        #expect(result?.outcome == .completed)
        #expect(result?.submissionIdentifier == 3)
        #expect(result?.label == "frame")
        #expect(result?.gpuDuration == 2)
        #expect(tracker.isReleased)
    }

    // #440: owners were released before terminal handlers ran, so a handler could not rely on them.
    @Test
    func terminalHandlersRunBeforeOwnersAreReleased() {
        let tracker = ReleaseTracker()
        let completion = makeCompletion(owner: TrackedOwner(tracker))
        let ownerAliveInHandler = OSAllocatedUnfairLock<Bool?>(initialState: nil)
        completion.onTerminated { _ in ownerAliveInHandler.withLock { $0 = !tracker.isReleased } }
        completion.recordFeedback(error: nil)
        completion.recordEvent()
        #expect(ownerAliveInHandler.withLock { $0 } == true)
        #expect(tracker.isReleased)
    }

    @Test
    func feedbackErrorResolvesWithoutWaitingForTheEventAndQuarantinesResources() {
        let tracker = ReleaseTracker()
        let completion = makeCompletion(owner: TrackedOwner(tracker))
        let failure = Submission.Failure.gpuFailure(domain: "MTL", code: 5, message: "fault")
        completion.recordFeedback(error: failure)
        #expect(completion.resolvedResult?.outcome == .gpuFailed(failure))
        #expect(!tracker.isReleased)
        completion.recordEvent()
        #expect(completion.resolvedResult?.outcome == .gpuFailed(failure))
        #expect(!tracker.isReleased)
    }

    @Test
    func terminalHandlerFiresExactlyOnceDespiteDuplicateAndLateNotifications() {
        let completion = makeCompletion()
        let recorder = ResultRecorder()
        completion.onTerminated { recorder.append($0) }
        completion.recordFeedback(error: nil)
        completion.recordFeedback(error: .gpuFailure(domain: "late", code: 1, message: "ignored"))
        completion.recordEvent()
        completion.recordEvent()
        completion.markTimedOut()
        #expect(recorder.all.count == 1)
        #expect(recorder.all.first?.outcome == .completed)
    }

    @Test
    func handlerRegisteredAfterResolutionFiresImmediatelyOnce() {
        let completion = makeCompletion()
        completion.recordEvent()
        completion.recordFeedback(error: nil)
        let recorder = ResultRecorder()
        completion.onTerminated { recorder.append($0) }
        #expect(recorder.all.map(\.outcome) == [.completed])
    }

    @Test
    func timeoutFaultsOnceAndLateCompletionCannotRenotifyOrRelease() {
        let tracker = ReleaseTracker()
        let completion = makeCompletion(owner: TrackedOwner(tracker))
        let recorder = ResultRecorder()
        completion.onTerminated { recorder.append($0) }
        completion.markTimedOut()
        #expect(completion.resolvedResult?.outcome == .timedOut)
        completion.recordFeedback(error: nil)
        completion.recordEvent()
        #expect(recorder.all.map(\.outcome) == [.timedOut])
        #expect(!tracker.isReleased)
    }

    @Test(arguments: [(0.0, 5.0), (5.0, 3.0), (0.0, 0.0)])
    func invalidTimingIsAbsentRatherThanZero(_ times: (Double, Double)) {
        let completion = makeCompletion()
        completion.recordFeedback(error: nil, gpuStartTime: times.0, gpuEndTime: times.1)
        completion.recordEvent()
        #expect(completion.resolvedResult?.gpuDuration == nil)
    }

    @Test
    func missingTimingIsAbsent() {
        let completion = makeCompletion()
        completion.recordFeedback(error: nil)
        completion.recordEvent()
        #expect(completion.resolvedResult?.gpuDuration == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelingAWaiterThrowsWithoutCancelingTheSubmission() async throws {
        let tracker = ReleaseTracker()
        let completion = makeCompletion(owner: TrackedOwner(tracker))
        let waiter = Task { try await completion.waitForResult() }
        try await Task.sleep(for: .milliseconds(20))
        waiter.cancel()
        await #expect(throws: CancellationError.self) { try await waiter.value }
        #expect(completion.resolvedResult == nil)
        #expect(!tracker.isReleased)
        completion.recordFeedback(error: nil)
        completion.recordEvent()
        #expect(try await completion.waitForResult().outcome == .completed)
        #expect(tracker.isReleased)
    }

    @Test
    func everyRegisteredHandlerFiresExactlyOnce() {
        let completion = makeCompletion()
        let first = ResultRecorder()
        let second = ResultRecorder()
        completion.onTerminated { first.append($0) }
        completion.onTerminated { second.append($0) }
        completion.recordFeedback(error: nil)
        completion.recordEvent()
        completion.recordEvent()
        #expect(first.all.count == 1)
        #expect(second.all.count == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func concurrentWaitersAllReceiveTheSameResult() async throws {
        let completion = makeCompletion()
        let outcomes = try await withThrowingTaskGroup(of: SubmissionResult.Outcome.self) { group in
            for _ in 0..<16 {
                group.addTask { try await completion.waitForResult().outcome }
            }
            group.addTask {
                try await Task.sleep(for: .milliseconds(20))
                completion.recordEvent()
                completion.recordFeedback(error: nil)
                return try await completion.waitForResult().outcome
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(outcomes.count == 17)
        #expect(outcomes.allSatisfy { $0 == .completed })
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellationBeforeRegistrationThrowsInsteadOfHanging() async {
        let completion = makeCompletion()
        let waiter = Task { () async throws -> SubmissionResult in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await completion.waitForResult()
        }
        await #expect(throws: CancellationError.self) { try await waiter.value }
        #expect(completion.resolvedResult == nil)
    }

    @Test
    func reentrantHandlerCanQueryStateWithoutDeadlock() {
        let completion = makeCompletion()
        let recorder = ResultRecorder()
        completion.onTerminated { [completion] result in
            recorder.append(result)
            // Reentering the completion from its own handler must not deadlock the state lock.
            if let resolved = completion.resolvedResult {
                recorder.append(resolved)
            }
        }
        completion.recordEvent()
        completion.recordFeedback(error: nil)
        #expect(recorder.all.count == 2)
    }
}

@Suite("Metal 4 ordered result delivery")
struct ResultDeliveryTests {
    private func result(_ identifier: UInt64) -> SubmissionResult {
        SubmissionResult(submissionIdentifier: identifier, label: nil, outcome: .completed, gpuStartTime: nil, gpuEndTime: nil)
    }

    @Test
    func outOfOrderResultsAreDeliveredInSubmissionOrderOnce() {
        let recorder = ResultRecorder()
        let delivery = ResultDelivery { recorder.append($0) }
        delivery.deliver(result(3))
        delivery.deliver(result(1))
        #expect(recorder.all.map(\.submissionIdentifier) == [1])
        delivery.deliver(result(2))
        delivery.deliver(result(2))
        delivery.deliver(result(1))
        #expect(recorder.all.map(\.submissionIdentifier) == [1, 2, 3])
    }

    @Test
    func reentrantDeliveryIsQueuedRatherThanRecursive() {
        let recorder = ResultRecorder()
        let reference = OSAllocatedUnfairLock<ResultDelivery?>(initialState: nil)
        let delivery = ResultDelivery { [self] delivered in
            recorder.append(delivered)
            if delivered.submissionIdentifier == 1 {
                reference.withLock { $0 }?.deliver(result(2))
                // The nested delivery must not have run inside this handler.
                #expect(recorder.all.count == 1)
            }
        }
        reference.withLock { $0 = delivery }
        delivery.deliver(result(1))
        #expect(recorder.all.map(\.submissionIdentifier) == [1, 2])
        reference.withLock { $0 = nil }
    }

    @Test(.timeLimit(.minutes(1)))
    func concurrentDeliveryIsSerialAndOrdered() async {
        let recorder = ResultRecorder()
        let overlapping = OSAllocatedUnfairLock(initialState: (active: 0, overlapped: false))
        let delivery = ResultDelivery { delivered in
            overlapping.withLock { state in
                state.active += 1
                if state.active > 1 {
                    state.overlapped = true
                }
            }
            recorder.append(delivered)
            overlapping.withLock { $0.active -= 1 }
        }
        let identifiers = (1...200).map { UInt64($0) }.shuffled()
        await withTaskGroup(of: Void.self) { group in
            for identifier in identifiers {
                group.addTask { delivery.deliver(result(identifier)) }
            }
        }
        #expect(recorder.all.map(\.submissionIdentifier) == (1...200).map { UInt64($0) })
        #expect(!overlapping.withLock { $0.overlapped })
    }
}

@MainActor
@Suite("Metal 4 submission results", .requiresMetal4)
struct SubmissionResultTests {
    @Test(.timeLimit(.minutes(1)))
    func commitNotificationPrecedesTerminalResultWithRealTiming() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 2)
        let events = OSAllocatedUnfairLock<[String]>(initialState: [])
        context.onSubmissionCommitted { submissionIdentifier, _ in
            events.withLock { $0.append("committed \(submissionIdentifier)") }
        }
        let recording = try context.submit { _ in }
        let submission = recording
        submission.onTerminated { result in
            events.withLock { $0.append("terminated \(result.submissionIdentifier)") }
        }
        let result = try await context.awaitResult(submission)
        #expect(result.outcome == .completed)
        #expect(result.submissionIdentifier == submission.identifier)
        #expect(events.withLock { $0 }.first == "committed \(result.submissionIdentifier)")
        #expect(events.withLock { $0 }.contains("terminated \(result.submissionIdentifier)"))
        if let duration = result.gpuDuration {
            #expect(duration >= 0)
        }
        #expect(!context.isFaulted)
    }

    @Test(.timeLimit(.minutes(1)))
    func contextDeliversInSubmissionOrderAndDrainRetiresEverything() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 3)
        let delivered = ResultRecorder()
        context.onSubmissionTerminated { delivered.append($0) }
        let callerHandlerFired = ResultRecorder()
        var submissions: [Submission] = []
        for _ in 0..<3 {
            submissions.append(try context.submit { _ in })
        }
        // A caller-registered handler must not displace the context's own delivery.
        submissions[1].onTerminated { callerHandlerFired.append($0) }
        try await context.drain()
        #expect(delivered.all.map(\.submissionIdentifier) == [1, 2, 3])
        #expect(delivered.all.allSatisfy { $0.outcome == .completed })
        #expect(callerHandlerFired.all.map(\.submissionIdentifier) == [2])
        #expect(context.inFlightCount == 0)
        #expect(!context.isFaulted)
    }

    @Test(.timeLimit(.minutes(1)))
    func drainAfterTimeoutQuarantinesFaultedWorkAndItsResources() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 2, submissionTimeout: .milliseconds(50))
        let gate = try #require(device.makeSharedEvent())
        context.commandQueue.waitForEvent(gate, value: 1)
        let tracker = ReleaseTracker()
        let submission = try context.submit { scope in try scope.retain(TrackedOwner(tracker)) }
        try await context.drain()
        #expect(submission.resolvedResult?.outcome == .timedOut)
        #expect(context.isFaulted)
        #expect(context.inFlightCount == 1)
        #expect(!context.canSubmit)
        gate.signaledValue = 1
        await context.completionEvent.valueSignaled(submission.identifier)
        try context.retireCompletedSubmissions()
        #expect(context.inFlightCount == 1)
        #expect(!tracker.isReleased)
    }

    @Test(.timeLimit(.minutes(1)))
    func timeoutFaultsTheContextAndRejectsNewRecording() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 1, submissionTimeout: .milliseconds(50))
        let gate = try #require(device.makeSharedEvent())
        context.commandQueue.waitForEvent(gate, value: 1)
        let submission = try context.submit { _ in }
        let result = try await context.awaitResult(submission)
        #expect(result.outcome == .timedOut)
        #expect(context.isFaulted)
        #expect(throws: MetalSprocketsError.self) { try context.submit { _ in } }
        // Releasing the gate lets the real work finish; the timed-out result must not be overridden.
        gate.signaledValue = 1
        await context.completionEvent.valueSignaled(submission.identifier)
        #expect(submission.resolvedResult?.outcome == .timedOut)
    }
}
