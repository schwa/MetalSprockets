internal final class Node: Identifiable {
    weak var system: System?
    var id: StructuralIdentifier
    var parentIdentifier: StructuralIdentifier?
    var element: (any Element)

    var stateProperties: [String: Any] = [:]
    var environmentValues = MSEnvironmentValues()
    var needsSetup = true

    /// Single-slot typed cache for framework elements (see ``NodeElementCache``).
    /// Access via ``cache(_:make:)``.
    private var elementCache: (any NodeElementCache)?

    init(system: System, id: StructuralIdentifier, parentIdentifier: StructuralIdentifier? = nil, element: (any Element)) {
        self.system = system
        self.id = id
        self.parentIdentifier = parentIdentifier
        self.element = element
    }

    /// Return the existing cache if it is of type `C`, otherwise build a new
    /// one via `make()`, store it, and return it. If a cache of a different
    /// type is already present (e.g. this node was reused for a different
    /// element type) it is replaced.
    func cache<C: NodeElementCache>(_ type: C.Type, make: () -> C) -> C {
        if let existing = elementCache as? C {
            return existing
        }
        let new = make()
        elementCache = new
        return new
    }
}
