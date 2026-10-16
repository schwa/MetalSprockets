import Synchronization

/// Protocol conformances of an element type, checked once per type instead of on every node every frame (RFC 0006).
///
/// Conformance depends only on the type, and a node's identifier includes its element's type, so a node keeps the same
/// info for its whole life. Hot paths call through the cached metatypes, whose static helpers cast the element to its
/// concrete type (`as! Self`), instead of casting to a protocol existential (`as? any P`), which looks up conformance.
internal struct ElementTypeInfo: @unchecked Sendable {
    let bodylessType: (any BodylessElement.Type)?
    let setupType: (any SetupElement.Type)?
    let workloadType: (any WorkloadElement.Type)?
    let isEnvironmentModifying: Bool
    let explicitlyIdentifiedType: (any ExplicitlyIdentifiedElement.Type)?
    let identityWrapperType: (any IdentityWrapperElement.Type)?
    /// Set for collapsible workload modifiers, so their chains are walked without protocol casts.
    let collapsibleType: (any CollapsibleWorkloadModifier.Type)?

    var isBodyless: Bool { bodylessType != nil }
    var isSetup: Bool { setupType != nil }
    var isWorkload: Bool { workloadType != nil }
    var isExplicitlyIdentified: Bool { explicitlyIdentifiedType != nil }

    private static let cache = Mutex<[ObjectIdentifier: Self]>([:])

    static func of(_ element: any Element) -> Self {
        of(type: type(of: element))
    }

    static func of(type elementType: any Element.Type) -> Self {
        let key = ObjectIdentifier(elementType)
        if let info = cache.withLock({ $0[key] }) {
            return info
        }
        let info = Self(
            bodylessType: elementType as? any BodylessElement.Type,
            setupType: elementType as? any SetupElement.Type,
            workloadType: elementType as? any WorkloadElement.Type,
            isEnvironmentModifying: elementType is any EnvironmentModifyingElement.Type,
            explicitlyIdentifiedType: elementType as? any ExplicitlyIdentifiedElement.Type,
            identityWrapperType: elementType as? any IdentityWrapperElement.Type,
            collapsibleType: elementType as? any CollapsibleWorkloadModifier.Type
        )
        cache.withLock { $0[key] = info }
        return info
    }
}

// Static entry points for the cached metatypes. `as! Self` casts to a concrete type and cannot fail: the metatype came
// from the element's own dynamic type.
// swiftlint:disable force_cast
extension BodylessElement {
    static func visitChildrenBodyless(of element: any Element, _ visit: (any Element) throws -> Void) throws {
        try (element as! Self).visitChildrenBodyless(visit)
    }

    static func configureNodeBodyless(of element: any Element, node: Node) throws {
        try (element as! Self).configureNodeBodyless(node)
    }

    static func skipsWorkload(of element: any Element, node: Node) -> Bool {
        (element as! Self).skipsWorkload(node)
    }
}

extension SetupElement {
    static func setupEnter(of element: any Element, node: Node) throws {
        try (element as! Self).setupEnter(node)
    }

    static func setupExit(of element: any Element, node: Node) throws {
        try (element as! Self).setupExit(node)
    }
}

extension WorkloadElement {
    static func workloadEnter(of element: any Element, node: Node) throws {
        try (element as! Self).workloadEnter(node)
    }

    static func workloadExit(of element: any Element, node: Node) throws {
        try (element as! Self).workloadExit(node)
    }
}

extension ExplicitlyIdentifiedElement {
    static func explicitID(of element: any Element) -> AnyElementID {
        (element as! Self).explicitID
    }
}

extension IdentityWrapperElement {
    static func wrappedContent(of element: any Element) -> any Element {
        (element as! Self).wrappedContent
    }
}
// swiftlint:enable force_cast
