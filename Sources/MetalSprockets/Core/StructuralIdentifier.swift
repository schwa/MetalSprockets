public struct StructuralIdentifier: Hashable, Sendable {
    public struct Atom: Hashable, Sendable {
        public let typeIdentifier: ElementTypeIdentifier
        public let index: Int

        public init(typeIdentifier: ElementTypeIdentifier, index: Int) {
            self.typeIdentifier = typeIdentifier
            self.index = index
        }

        public init(element: some Element, index: Int) {
            self.typeIdentifier = ElementTypeIdentifier(type(of: element))
            self.index = index
        }
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
        "\(typeIdentifier)#\(index)"
    }
}

public extension StructuralIdentifier {
    func appending(_ atom: Atom) -> StructuralIdentifier {
        StructuralIdentifier(atoms: atoms + [atom])
    }
}
