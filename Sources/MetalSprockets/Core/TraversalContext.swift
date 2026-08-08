import Foundation

/// The stack of nodes currently being visited by a traversal phase.
///
/// Owned by the phase running the traversal (reconciliation, setup, workload) and reached through
/// ``System/traversalContext``. Property wrappers such as `@MSEnvironment` and `@MSState` resolve their values through
/// this context — via ``currentNode`` and ``parentNode`` — rather than indexing a stack held on ``System``.
///
/// The context is empty outside a traversal; resolving environment or state then is a programmer error.
internal final class TraversalContext {
    private var stack: [Node] = []

    var isEmpty: Bool {
        stack.isEmpty
    }

    var depth: Int {
        stack.count
    }

    /// The node being visited, if any.
    var currentNode: Node? {
        stack.last
    }

    /// The node above ``currentNode``, if any.
    var parentNode: Node? {
        stack.count >= 2 ? stack[stack.count - 2] : nil
    }

    /// Whether any strict ancestor of ``currentNode`` satisfies `predicate`.
    func hasAncestor(where predicate: (Node) -> Bool) -> Bool {
        stack.dropLast().contains(where: predicate)
    }

    func push(_ node: Node) {
        stack.append(node)
    }

    func pop() {
        stack.removeLast()
    }

    /// Abandon the stack. Used to recover from a phase that threw part-way through a traversal, so the next frame
    /// starts clean rather than tripping the empty-stack assertions. See #296.
    func clear() {
        stack.removeAll()
    }
}
