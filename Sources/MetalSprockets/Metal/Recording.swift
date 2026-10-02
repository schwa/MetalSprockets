import Metal
import MetalSprocketsSupport

// Records element trees into Metal 4 submissions.

internal extension MSEnvironmentValues {
    @MSEntry var recordingScope: RecordingScope?
}

/// Publishes a recording's plumbing (scope, context, command buffer, queue, device) from one node. Five separate
/// environment modifiers cost a measurable share of every frame's update phase (#436).
internal struct RecordingRoot<Content: Element>: Element, BodylessElement, EnvironmentModifyingElement {
    var content: Content
    var scope: RecordingScope
    var context: MetalContext
    var commandBuffer: any MTL4CommandBuffer

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func configureNodeBodyless(_ node: Node) throws {
        node.environmentValues.recordingScope = scope
        node.environmentValues.metalContext = context
        node.environmentValues.commandBuffer = commandBuffer
        node.environmentValues.commandQueue = context.commandQueue
        node.environmentValues.device = context.device
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
            let root = RecordingRoot(content: content, scope: scope, context: self, commandBuffer: try scope.commandBuffer())
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
