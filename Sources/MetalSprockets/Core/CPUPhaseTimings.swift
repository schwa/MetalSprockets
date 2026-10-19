import Foundation

/// CPU time spent in each phase of one frame, in seconds.
///
/// - `content`: building the element tree in the caller's content closure. Only drivers that run that closure (such as
///   `RenderView`) report it. For other drivers, it is `nil`.
/// - `update`: reconciling the new element tree against the previous frame's nodes.
/// - `setup`: setup work for nodes that need it, such as pipeline creation.
/// - `workload`: encoding GPU commands.
///
/// Submitting the command buffer and waiting for a drawable are not included.
public struct CPUPhaseTimings: Sendable, Equatable {
    public var content: TimeInterval?
    public var update: TimeInterval
    public var setup: TimeInterval
    public var workload: TimeInterval

    public init(content: TimeInterval? = nil, update: TimeInterval, setup: TimeInterval, workload: TimeInterval) {
        self.content = content
        self.update = update
        self.setup = setup
        self.workload = workload
    }

    public var total: TimeInterval {
        (content ?? 0) + update + setup + workload
    }
}
