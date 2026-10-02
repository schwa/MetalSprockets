import Foundation

/// GPU work that a root has committed to its Metal 4 queue.
///
/// Dropping a submission does not cancel the work or release its resources; the root keeps them until the GPU is done.
public struct Submission: Sendable {
    public enum Failure: Error, Equatable {
        case gpuFailure(domain: String, code: Int, message: String)
    }

    /// Commit order within the root.
    public let identifier: UInt64
    let completion: SubmissionCompletion

    /// The terminal result, once known.
    public var resolvedResult: SubmissionResult? { completion.resolvedResult }

    /// Awaits the terminal result without blocking an actor. A GPU failure is reported in the result, not thrown.
    /// Canceling the awaiting task throws `CancellationError` without canceling the GPU submission.
    @discardableResult
    public func value() async throws -> SubmissionResult {
        try await completion.waitForResult()
    }

    /// Blocks until the terminal result is known or `timeout` passes, which reports `.timedOut`.
    /// For synchronous code only; use ``value()`` from async code.
    @discardableResult
    public func waitUntilCompleted(timeout: Duration = .seconds(5)) throws -> SubmissionResult {
        let semaphore = DispatchSemaphore(value: 0)
        completion.onTerminated { _ in semaphore.signal() }
        let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
        if semaphore.wait(timeout: .now() + seconds) == .timedOut {
            completion.markTimedOut()
        }
        return try completion.resolvedResult.orThrow(.generic("The submission produced no result"))
    }

    @discardableResult
    package func waitForResult() async throws -> SubmissionResult {
        try await completion.waitForResult()
    }

    func onTerminated(_ handler: @escaping @Sendable (SubmissionResult) -> Void) {
        completion.onTerminated(handler)
    }

    func waitUntilCompleted() async throws {
        _ = try await completion.waitForResult()
    }
}
