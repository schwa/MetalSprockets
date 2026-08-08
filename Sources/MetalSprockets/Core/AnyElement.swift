// TODO: #219 Evaluate if AnyElement type erasure is still needed - may be redundant with current architecture
public struct AnyElement: Element, BodylessElement {
    private let base: any Element

    public init(_ base: some Element) {
        self.base = base
    }

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(base)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        // AnyElement does no setup work itself; the wrapped element is visited as a child and
        // compared on its own terms. Only a change of wrapped type matters. (#343)
        type(of: base) != type(of: old.base)
    }
}

public extension Element {
    func eraseToAnyElement() -> AnyElement {
        AnyElement(self)
    }
}
