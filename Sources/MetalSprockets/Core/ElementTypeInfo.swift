import Synchronization

/// Protocol conformances of an element type, checked once per type instead of on every node every frame (RFC 0006).
///
/// Conformance depends only on the type, and a node's identifier includes its element's type, so a node keeps the same
/// info for its whole life. Hot paths check a flag before casting, which skips casts that would fail. Casts that
/// succeed still run where the existential is needed.
internal struct ElementTypeInfo: Sendable {
    let isBodyless: Bool
    let isSetup: Bool
    let isWorkload: Bool
    let isEnvironmentModifying: Bool
    let isExplicitlyIdentified: Bool
    /// Set for collapsible workload modifiers, so their chains are walked without protocol casts.
    let collapsibleType: (any CollapsibleWorkloadModifier.Type)?

    private static let cache = Mutex<[ObjectIdentifier: Self]>([:])

    static func of(_ element: any Element) -> Self {
        let key = ObjectIdentifier(type(of: element))
        if let info = cache.withLock({ $0[key] }) {
            return info
        }
        let info = Self(
            isBodyless: element is any BodylessElement,
            isSetup: element is any SetupElement,
            isWorkload: element is any WorkloadElement,
            isEnvironmentModifying: element is any EnvironmentModifyingElement,
            isExplicitlyIdentified: element is any ExplicitlyIdentifiedElement,
            collapsibleType: type(of: element) as? any CollapsibleWorkloadModifier.Type
        )
        cache.withLock { $0[key] = info }
        return info
    }
}
