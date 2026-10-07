import Metal
import MetalSprocketsSupport

// Records element trees into Metal 4 submissions.

internal extension MSEnvironmentValues {
    @MSEntry var recordingScope: RecordingScope?
    @MSEntry var _submissionIndex: UInt64 = 0
    @MSEntry var _maximumInFlightSubmissions: Int = 1
}

public extension MSEnvironmentValues {
    /// The identifier of the submission being recorded. Every element in one recording sees the same value, and it
    /// increases by one per committed submission. Zero outside a recording.
    ///
    /// Use it with ``maximumInFlightSubmissions`` to pick a per-frame resource from a ring:
    /// `slots[Int(submissionIndex % UInt64(maximumInFlightSubmissions))]`. Recording only starts when fewer than
    /// `maximumInFlightSubmissions` submissions are in flight, so the GPU has finished with the slot. Changing the
    /// limit at runtime breaks this pairing for the frames in flight.
    var submissionIndex: UInt64 { _submissionIndex }

    /// The in-flight limit of the root recording this tree. One outside a recording.
    var maximumInFlightSubmissions: Int { _maximumInFlightSubmissions }
}

/// Publishes a recording's plumbing (scope, context, command buffer, queue, device) from one node. Five separate
/// environment modifiers cost a measurable share of every frame's update phase (#436).
internal struct RecordingRoot<Content: Element>: Element, BodylessElement, EnvironmentModifyingElement {
    var content: Content
    var scope: RecordingScope
    var context: MetalContext
    var commandBuffer: any MTL4CommandBuffer
    var submissionIndex: UInt64 = 0

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func configureNodeBodyless(_ node: Node) throws {
        node.environmentValues.recordingScope = scope
        node.environmentValues.metalContext = context
        node.environmentValues.commandBuffer = commandBuffer
        node.environmentValues.commandQueue = context.commandQueue
        node.environmentValues.device = context.device
        node.environmentValues._submissionIndex = submissionIndex
        node.environmentValues._maximumInFlightSubmissions = context.maximumInFlightSubmissions
    }

    // Per-frame plumbing, not pipeline identity: the context (and so device and queue) is fixed for a System.
    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

extension MetalContext {
    /// Records one frame by traversing `content` with `system`, so node state and setup caches persist across frames.
    func submit(_ content: some Element, system: System, residencySets: [any MTLResidencySet] = [], presenting presentable: (any Presentable)? = nil) throws -> Submission {
        try submit(presenting: presentable) { scope in
            for residencySet in residencySets {
                try scope.useResidencySet(residencySet)
            }
            let root = RecordingRoot(content: content, scope: scope, context: self, commandBuffer: try scope.commandBuffer(), submissionIndex: nextSubmissionIdentifier)
            try system.render(root: root)
        }
    }

    /// Submits `content` and awaits its terminal result.
    nonisolated(nonsending) func run(_ content: some Element, system: System) async throws -> Submission {
        try await awaitSubmissionCapacity()
        let submission = try submit(content, system: system)
        try await awaitResult(submission)
        return submission
    }
}
