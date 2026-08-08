public struct StructuralIdentifier: Hashable, Sendable {
    public struct Atom: Hashable, Sendable {
        public let typeIdentifier: ElementTypeIdentifier
        public let index: Int
        /// Identity supplied via ``Element/id(_:)``. When present it replaces sibling position
        /// as the distinguishing part of the atom.
        public let explicitID: AnyElementID?

        public init(typeIdentifier: ElementTypeIdentifier, index: Int, explicitID: AnyElementID? = nil) {
            self.typeIdentifier = typeIdentifier
            self.index = index
            self.explicitID = explicitID
        }

        public init(element: some Element, index: Int, explicitID: AnyElementID? = nil) {
            self.typeIdentifier = ElementTypeIdentifier(type(of: element))
            self.index = index
            self.explicitID = explicitID
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
        guard let explicitID else {
            return "\(typeIdentifier)#\(index)"
        }
        return "\(typeIdentifier)#\(explicitID)"
    }
}

public extension StructuralIdentifier {
    func appending(_ atom: Atom) -> StructuralIdentifier {
        StructuralIdentifier(atoms: atoms + [atom])
    }
}
