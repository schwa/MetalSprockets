/// The node whose element is being evaluated, for code that has no node parameter to receive it through.
///
/// Only property-wrapper getters (`@MSState` read tracking, `@MSEnvironment`) and ambient lookups such as
/// `ShaderLibrary` use this. Everything else gets its node passed in. The task-local holds the traversal context
/// privately, so callers see one node, not the `System` or the node stack. See #389.
internal enum ReadingNode {
    @TaskLocal private static var context: TraversalContext?

    /// The node being visited by the traversal running on this task, if any.
    static var current: Node? {
        context?.currentNode
    }

    /// Whether this task is running a traversal, even if no node is being visited yet.
    static var isActive: Bool {
        context != nil
    }

    static func withContext<R>(_ context: TraversalContext, _ operation: () throws -> R) rethrows -> R {
        try $context.withValue(context, operation: operation)
    }
}
