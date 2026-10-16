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
    // Hash of the whole path, computed once. Equal paths always have equal hashes, so it also rejects most unequal
    // paths before comparing atoms (#497).
    private let pathHash: Int

    public init(atoms: [Atom]) {
        self.atoms = atoms
        var hash = Self.rootHash
        for atom in atoms {
            hash = Self.extend(hash, with: atom)
        }
        self.pathHash = hash
    }

    /// For callers that already know the path hash, such as the reconciler extending its parent's hash.
    internal init(atoms: [Atom], pathHash: Int) {
        self.atoms = atoms
        self.pathHash = pathHash
    }

    internal static let rootHash = 0

    internal static func extend(_ hash: Int, with atom: Atom) -> Int {
        var hasher = Hasher()
        hasher.combine(hash)
        hasher.combine(atom)
        return hasher.finalize()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.pathHash == rhs.pathHash, lhs.atoms.count == rhs.atoms.count else {
            return false
        }
        // Leaf first: siblings and cousins differ near the end of the path.
        var index = lhs.atoms.count - 1
        while index >= 0 {
            if lhs.atoms[index] != rhs.atoms[index] {
                return false
            }
            index -= 1
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pathHash)
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
        StructuralIdentifier(atoms: atoms + [atom], pathHash: Self.extend(pathHash, with: atom))
    }
}
