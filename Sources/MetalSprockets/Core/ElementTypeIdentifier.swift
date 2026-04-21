public struct ElementTypeIdentifier: Hashable, Sendable {
    public var id: ObjectIdentifier

    public init(_ type: any Element.Type) {
        self.id = ObjectIdentifier(type)
    }
}

extension ElementTypeIdentifier: CustomDebugStringConvertible {
    public var debugDescription: String {
        "t#\(id.shortId)"
    }
}
