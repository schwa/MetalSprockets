public struct _ConditionalContent<TrueContent, FalseContent>: Element, BodylessElement where TrueContent: Element, FalseContent: Element {
    let first: TrueContent?
    let second: FalseContent?

    init(first: TrueContent) {
        self.first = first
        self.second = nil
    }

    init(second: FalseContent) {
        self.first = nil
        self.second = second
    }

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        if let first {
            try visit(first)
        }
        else if let second {
            try visit(second)
        }
    }

    nonisolated func requiresSetup(comparedTo old: _ConditionalContent<TrueContent, FalseContent>) -> Bool {
        // This element holds no setup state of its own; only a branch switch matters. The
        // branch content is a child node and is compared on its own terms. (#343)
        (first != nil) != (old.first != nil)
    }
}
