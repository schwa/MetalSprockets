import Metal
import os
import QuartzCore

internal final class SubmissionCompletion: Sendable {
    private struct Waiter {
        let identifier: Int
        let continuation: CheckedContinuation<SubmissionResult, any Error>
    }

    private struct Contents {
        var owners: [AnyObject]
        var lifetime: SubmissionCompletion?
        var feedbackReceived = false
        var eventReceived = false
        var timedOut = false
        var error: Submission.Failure?
        var gpuStartTime: CFTimeInterval?
        var gpuEndTime: CFTimeInterval?
        var result: SubmissionResult?
        var terminalHandlers: [@Sendable (SubmissionResult) -> Void] = []
        var waiters: [Waiter] = []
        var nextWaiterIdentifier = 0
        // Waiters canceled before their continuation was registered.
        var cancelledWaiters: Set<Int> = []
    }

    let submissionIdentifier: UInt64
    let label: String?

    // Callbacks retain/release these objects but never encode through them or touch the owning context.
    private let state: OSAllocatedUnfairLock<Contents>

    init(submissionIdentifier: UInt64, label: String?, owners: [AnyObject]) {
        self.submissionIdentifier = submissionIdentifier
        self.label = label
        state = OSAllocatedUnfairLock(uncheckedState: Contents(owners: owners))
    }

    convenience init(submissionIdentifier: UInt64, label: String?, commandBuffer: any MTL4CommandBuffer, allocator: any MTL4CommandAllocator, resources: RecordingScope.Resources) {
        let retainedObjects: [AnyObject] = [commandBuffer, allocator] + resources.allocations.map { $0 as AnyObject } + resources.residencySets.map { $0 as AnyObject } + resources.objects + resources.owners.map { $0 as AnyObject }
        self.init(submissionIdentifier: submissionIdentifier, label: label, owners: retainedObjects)
    }

    var resolvedResult: SubmissionResult? {
        state.withLockUnchecked { $0.result }
    }

    var isRetiredSuccessfully: Bool {
        state.withLockUnchecked { $0.result?.outcome == .completed }
    }

    func retainUntilCompleted() {
        state.withLockUnchecked { $0.lifetime = self }
    }

    /// Adds a terminal handler. Each handler fires exactly once, immediately if the submission already resolved.
    func onTerminated(_ handler: @escaping @Sendable (SubmissionResult) -> Void) {
        let resolved: SubmissionResult? = state.withLockUnchecked { contents in
            if let result = contents.result {
                return result
            }
            contents.terminalHandlers.append(handler)
            return nil
        }
        if let resolved {
            handler(resolved)
        }
    }

    func recordFeedback(error: Submission.Failure?, gpuStartTime: CFTimeInterval? = nil, gpuEndTime: CFTimeInterval? = nil) {
        resolve { contents in
            guard !contents.feedbackReceived else {
                return
            }
            contents.feedbackReceived = true
            contents.error = error
            contents.gpuStartTime = gpuStartTime
            contents.gpuEndTime = gpuEndTime
        }
    }

    func recordEvent() {
        resolve { $0.eventReceived = true }
    }

    /// Faults this submission as timed out. A later real completion cannot override or re-notify.
    func markTimedOut() {
        resolve { contents in
            if contents.result == nil {
                contents.error = nil
                contents.gpuStartTime = nil
                contents.gpuEndTime = nil
                contents.timedOut = true
            }
        }
    }

    func waitForResult() async throws -> SubmissionResult {
        let waiterIdentifier = state.withLockUnchecked { contents in
            defer { contents.nextWaiterIdentifier += 1 }
            return contents.nextWaiterIdentifier
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                enum Registration {
                    case resolved(SubmissionResult)
                    case cancelled
                    case waiting
                }
                let registration: Registration = state.withLockUnchecked { contents in
                    if let result = contents.result {
                        return .resolved(result)
                    }
                    if contents.cancelledWaiters.remove(waiterIdentifier) != nil {
                        return .cancelled
                    }
                    contents.waiters.append(Waiter(identifier: waiterIdentifier, continuation: continuation))
                    return .waiting
                }
                switch registration {
                case .resolved(let result):
                    continuation.resume(returning: result)
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .waiting:
                    break
                }
            }
        } onCancel: {
            // Canceling a waiter never cancels the GPU submission; the work and its resources stay retained.
            let cancelled: CheckedContinuation<SubmissionResult, any Error>? = state.withLockUnchecked { contents in
                guard let index = contents.waiters.firstIndex(where: { $0.identifier == waiterIdentifier }) else {
                    // The continuation is not registered yet; the body observes this and throws on registration.
                    if contents.result == nil {
                        contents.cancelledWaiters.insert(waiterIdentifier)
                    }
                    return nil
                }
                return contents.waiters.remove(at: index).continuation
            }
            cancelled?.resume(throwing: CancellationError())
        }
    }

    private func resolve(_ update: (inout Contents) -> Void) {
        var releasedOwners: [AnyObject] = []
        var waiters: [Waiter] = []
        var handlers: [@Sendable (SubmissionResult) -> Void] = []
        let result: SubmissionResult? = state.withLockUnchecked { contents in
            guard contents.result == nil else {
                return nil
            }
            update(&contents)
            let outcome: SubmissionResult.Outcome
            if contents.timedOut {
                outcome = .timedOut
            } else if let error = contents.error {
                outcome = .gpuFailed(error)
            } else if contents.feedbackReceived, contents.eventReceived {
                outcome = .completed
            } else {
                return nil
            }
            let result = SubmissionResult(
                submissionIdentifier: submissionIdentifier,
                label: label,
                outcome: outcome,
                gpuStartTime: contents.gpuStartTime,
                gpuEndTime: contents.gpuEndTime
            )
            contents.result = result
            if outcome == .completed {
                // Only successful, fully acknowledged work releases its resources. Faulted work stays quarantined.
                releasedOwners = contents.owners
                contents.owners.removeAll()
            }
            contents.lifetime = nil
            waiters = contents.waiters
            contents.waiters.removeAll()
            handlers = contents.terminalHandlers
            contents.terminalHandlers.removeAll()
            return result
        }
        // Destructors, resumed waiters, and the terminal handler may reenter; none runs under the state lock.
        guard let result else {
            return
        }
        for waiter in waiters {
            waiter.continuation.resume(returning: result)
        }
        for handler in handlers {
            handler(result)
        }
        // Released last, so terminal handlers can still use the submission's owners (#440).
        releasedOwners.removeAll()
    }
}
