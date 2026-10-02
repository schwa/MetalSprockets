import os

/// Delivers terminal submission results serially and in submission-identifier order.
///
/// Native completion arrives on unordered Metal queues. Results wait here until every earlier identifier has been
/// delivered, then exactly one thread drains the ready prefix. Handlers run outside the lock, so a handler that causes
/// another result to arrive only enqueues it for the active drainer instead of recursing or deadlocking.
internal final class ResultDelivery: Sendable {
    private struct Contents {
        var nextIdentifier: UInt64 = 1
        var pending: [UInt64: SubmissionResult] = [:]
        var isDelivering = false
    }

    private let state = OSAllocatedUnfairLock(initialState: Contents())
    private let handler: @Sendable (SubmissionResult) -> Void

    init(handler: @escaping @Sendable (SubmissionResult) -> Void) {
        self.handler = handler
    }

    func deliver(_ result: SubmissionResult) {
        let shouldDrain = state.withLock { contents in
            guard result.submissionIdentifier >= contents.nextIdentifier, contents.pending[result.submissionIdentifier] == nil else {
                return false
            }
            contents.pending[result.submissionIdentifier] = result
            guard !contents.isDelivering else {
                return false
            }
            contents.isDelivering = true
            return true
        }
        guard shouldDrain else {
            return
        }
        while let next = takeNextReady() {
            handler(next)
        }
    }

    private func takeNextReady() -> SubmissionResult? {
        state.withLock { contents in
            guard let next = contents.pending.removeValue(forKey: contents.nextIdentifier) else {
                contents.isDelivering = false
                return nil
            }
            contents.nextIdentifier += 1
            return next
        }
    }
}
