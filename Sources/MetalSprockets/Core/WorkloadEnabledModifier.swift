internal struct WorkloadEnabledModifier <Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var enabled: Bool

    init(content: Content, enabled: Bool) {
        self.content = content
        self.enabled = enabled
    }

    func skipsWorkload(_ node: Node) -> Bool {
        !enabled
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        // Toggling the flag doesn't require re-running setup; we keep the
        // pipeline state and other setup-phase resources intact so toggling
        // is cheap.
        false
    }
}

public extension Element {
    /// Controls whether this element's subtree participates in the workload phase.
    ///
    /// When `enabled` is `false`, neither this element nor any of its descendants
    /// have their workload phase run (no draws, dispatches, or blits). The setup
    /// phase still runs, so pipeline states and other setup-phase resources stay
    /// built — toggling the flag is cheap and does not cause a rebuild.
    ///
    /// Useful for debug toggles, A/B comparisons, and effect bypass switches
    /// where you want to keep everything warm but temporarily suppress output.
    ///
    /// ```swift
    /// MyExpensiveEffect()
    ///     .workloadEnabled(showEffect)
    /// ```
    ///
    /// If you want to remove an element from the tree entirely (triggering
    /// teardown of its resources), use a plain `if`/`ConditionalContent` instead.
    ///
    /// - Parameter enabled: Whether the subtree's workload phase runs. Defaults to `true`.
    func workloadEnabled(_ enabled: Bool = true) -> some Element {
        WorkloadEnabledModifier(content: self, enabled: enabled)
    }
}
