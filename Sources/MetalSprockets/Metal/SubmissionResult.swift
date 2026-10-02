import QuartzCore

/// The terminal result of one GPU submission.
///
/// GPU times come from Metal 4 commit feedback. Missing, zero or reversed timestamps give `nil` timing, never a
/// fabricated zero duration.
public struct SubmissionResult: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        case completed
        case gpuFailed(Submission.Failure)
        /// The submission did not finish within the root's deadline. The root stops accepting new work.
        case timedOut
    }

    /// Identifies the submission within its root, in commit order.
    public let submissionIdentifier: UInt64
    public let label: String?
    public let outcome: Outcome
    public let gpuStartTime: CFTimeInterval?
    public let gpuEndTime: CFTimeInterval?

    public var isSuccess: Bool { outcome == .completed }

    public var gpuDuration: TimeInterval? {
        guard let gpuStartTime, let gpuEndTime, gpuStartTime > 0, gpuEndTime >= gpuStartTime else {
            return nil
        }
        return gpuEndTime - gpuStartTime
    }

    package init(submissionIdentifier: UInt64, label: String?, outcome: Outcome, gpuStartTime: CFTimeInterval?, gpuEndTime: CFTimeInterval?) {
        self.submissionIdentifier = submissionIdentifier
        self.label = label
        self.outcome = outcome
        self.gpuStartTime = gpuStartTime
        self.gpuEndTime = gpuEndTime
    }
}
