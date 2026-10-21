internal struct WorkloadModifier <Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var _workloadEnter: ((MSEnvironmentValues) throws -> Void)?
    var _workloadExit: ((MSEnvironmentValues) throws -> Void)?

    init(content: Content, workloadEnter: ((MSEnvironmentValues) throws -> Void)? = nil, workloadExit: ((MSEnvironmentValues) throws -> Void)? = nil) {
        self.content = content
        self._workloadEnter = workloadEnter
        self._workloadExit = workloadExit
    }

    func workloadEnter(_ node: Node) throws {
        try _workloadEnter?(node.environmentValues)
    }

    func workloadExit(_ node: Node) throws {
        try _workloadExit?(node.environmentValues)
    }

    nonisolated func requiresSetup(comparedTo old: WorkloadModifier<Content>) -> Bool {
        // WorkloadModifier only affects the workload phase, never requires setup
        false
    }
}

public extension Element {
    func onWorkloadEnter(_ action: @escaping (MSEnvironmentValues) throws -> Void) -> some Element {
        WorkloadModifier(content: self, workloadEnter: action)
    }

    /// Runs `action` when the workload phase leaves this element, after its content.
    func onWorkloadExit(_ action: @escaping (MSEnvironmentValues) throws -> Void) -> some Element {
        WorkloadModifier(content: self, workloadExit: action)
    }
}
