public struct StructuralIdentifier: Hashable, @unchecked Sendable {
    // Sendable is `@unchecked` because `Atom.Component.explicit` wraps an
    // arbitrary `AnyHashable` whose element type isn't statically known to be
    // Sendable. In practice these identifiers are immutable value types built
    // from `ObjectIdentifier` (the type id) plus either an `Int` or a user-
    // supplied `.id(_:)` value, and are only ever used as dictionary/set keys.
    public struct Atom: Hashable, @unchecked Sendable {
        public enum Component: Hashable, @unchecked Sendable {
            case index(Int)
            case explicit(AnyHashable)
        }

        public let typeIdentifier: ElementTypeIdentifier
        public let component: Component
    }

    public let atoms: [Atom]

    public init(atoms: [Atom]) {
        self.atoms = atoms
    }
}

extension StructuralIdentifier: CustomStringConvertible {
    public var description: String {
        atoms.map(\.description).joined(separator: "/")
    }
}

extension StructuralIdentifier.Atom: CustomStringConvertible {
    public var description: String {
        switch component {
        case .index(let index):
            return "\(typeIdentifier)#\(index)"
        case .explicit(let explicit):
            return "\(typeIdentifier)(\(explicit))"
        }
    }
}

public extension StructuralIdentifier.Atom {
    init(typeIdentifier: ElementTypeIdentifier, index: Int) {
        self.typeIdentifier = typeIdentifier
        self.component = .index(index)
    }

    init(typeIdentifier: ElementTypeIdentifier, explicit: AnyHashable) {
        self.typeIdentifier = typeIdentifier
        self.component = .explicit(explicit)
    }

    init(element: some Element, index: Int) {
        self.typeIdentifier = ElementTypeIdentifier(type(of: element))
        self.component = .index(index)
    }

    init(element: some Element, explicit: AnyHashable) {
        self.typeIdentifier = ElementTypeIdentifier(type(of: element))
        self.component = .explicit(explicit)
    }
}

public extension StructuralIdentifier {
    func appending(_ atom: Atom) -> StructuralIdentifier {
        StructuralIdentifier(atoms: atoms + [atom])
    }
}
