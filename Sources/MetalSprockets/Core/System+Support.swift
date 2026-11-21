internal extension System {
    /// Runs `closure` with this system's traversal context installed as ``ReadingNode``'s source.
    func withReadingContext<R>(_ closure: () throws -> R) rethrows -> R {
        try ReadingNode.withContext(traversalContext, closure)
    }
}
