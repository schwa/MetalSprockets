internal struct OnDisappearModifier <Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var action: () -> Void

    init(content: Content, action: @escaping () -> Void) {
        self.content = content
        self.action = action
    }

    func teardown(_ node: Node) throws {
        action()
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        false
    }
}

public extension Element {
    /// Performs an action when this element is removed from the tree.
    ///
    /// The closure runs once when the system detects that this element is no
    /// longer present in the latest update. Use it to release external state
    /// (e.g. unregister observers, stop ongoing work). GPU resources held in
    /// the node's environment or caches are freed automatically via ARC.
    ///
    /// ```swift
    /// MyContent()
    ///     .onDisappear {
    ///         print("removed from tree")
    ///     }
    /// ```
    ///
    /// - Parameter action: Closure invoked when the element is torn down.
    func onDisappear(perform action: @escaping () -> Void) -> some Element {
        OnDisappearModifier(content: self, action: action)
    }
}
