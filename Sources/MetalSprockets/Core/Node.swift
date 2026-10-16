internal final class Node: Identifiable {
    weak var system: System?
    // Fixed for the node's life. A node's identifier is always its parent node's identifier plus one atom, which lets
    // the reconciler match a reused node by its parent node and last atom (see `TreeReconciler`).
    let id: StructuralIdentifier
    var parentIdentifier: StructuralIdentifier?
    /// The parent node in the most recent traversal that reached this node. Children do not own parents' lifetimes in
    /// any cycle: parents never reference children.
    var parentNode: Node?
    var element: (any Element)

    var stateProperties: [String: Any] = [:]
    var environmentValues = MSEnvironmentValues()
    var needsSetup = true

    /// Single-slot typed cache for framework elements (see ``NodeElementCache``).
    /// Access via ``cache(_:make:)``.
    private var elementCache: (any NodeElementCache)?

    /// Conformances of `element`'s type. Fixed for the node's life: its identifier includes the element type.
    let typeInfo: ElementTypeInfo

    init(system: System, id: StructuralIdentifier, parentIdentifier: StructuralIdentifier? = nil, element: (any Element)) {
        self.system = system
        self.id = id
        self.parentIdentifier = parentIdentifier
        self.element = element
        self.typeInfo = ElementTypeInfo.of(element)
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
