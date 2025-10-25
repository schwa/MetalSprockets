internal struct SetupModifier <Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var _setupEnter: ((MSEnvironmentValues) throws -> Void)?

    init(content: Content, setupEnter: ((MSEnvironmentValues) throws -> Void)? = nil) {
        self.content = content
        self._setupEnter = setupEnter
    }

    func setupEnter(_ node: Node) throws {
        try _setupEnter?(node.environmentValues)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        true
    }
}

public extension Element {
    func onSetupEnter(_ action: @escaping (MSEnvironmentValues) throws -> Void) -> some Element {
        SetupModifier(content: self, setupEnter: action)
    }
}
