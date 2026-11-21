import Synchronization

/// Protocol conformances of an element type, checked once per type instead of on every node every frame (RFC 0006).
///
/// Conformance depends only on the type, and a node's identifier includes its element's type, so a node keeps the same
/// info for its whole life. Hot paths call through the cached metatypes. Their static helpers cast the element to its
/// concrete type (`as! Self`). A cast to a protocol existential (`as? any P`) looks up conformance, which is slower.
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

/// Runs `body` with `element` viewed as `Concrete`, which must be its dynamic type. Callers get `Concrete` from the
/// element's own cached metatype, so this skips the dynamic cast `as!` would do.
@inline(__always)
private func withConcrete<Concrete, Result, ThrownError>(_ element: any Element, as concrete: Concrete.Type, _ body: (UnsafePointer<Concrete>) throws(ThrownError) -> Result) throws(ThrownError) -> Result {
    try withOpened(element, as: concrete, body)
}

@inline(__always)
private func withOpened<Opened: Element, Concrete, Result, ThrownError>(_ opened: Opened, as _: Concrete.Type, _ body: (UnsafePointer<Concrete>) throws(ThrownError) -> Result) throws(ThrownError) -> Result {
    assert(Opened.self == Concrete.self, "Element of type \(Opened.self) dispatched as \(Concrete.self)")
    return try withUnsafePointer(to: opened) { pointer throws(ThrownError) -> Result in
        // Opened and Concrete are the same type, so the memory is already bound to Concrete.
        try body(UnsafeRawPointer(pointer).assumingMemoryBound(to: Concrete.self))
    }
}

// Static entry points for the cached metatypes. The metatype came from the element's own dynamic type.
extension BodylessElement {
    static func visitChildrenBodyless(of element: any Element, node: Node, _ visit: (any Element) throws -> Void) throws {
        try withConcrete(element, as: Self.self) { try $0.pointee.visitChildrenBodyless(node, visit) }
    }

    static func configureNodeBodyless(of element: any Element, node: Node, context: TraversalContext) throws {
        try withConcrete(element, as: Self.self) { try $0.pointee.configureNodeBodyless(node, context: context) }
    }

    static func skipsWorkload(of element: any Element, node: Node) -> Bool {
        withConcrete(element, as: Self.self) { $0.pointee.skipsWorkload(node) }
    }
}

extension SetupElement {
    static func setupEnter(of element: any Element, node: Node) throws {
        try withConcrete(element, as: Self.self) { try $0.pointee.setupEnter(node) }
    }

    static func setupExit(of element: any Element, node: Node) throws {
        try withConcrete(element, as: Self.self) { try $0.pointee.setupExit(node) }
    }
}

extension WorkloadElement {
    static func workloadEnter(of element: any Element, node: Node) throws {
        try withConcrete(element, as: Self.self) { try $0.pointee.workloadEnter(node) }
    }

    static func workloadExit(of element: any Element, node: Node) throws {
        try withConcrete(element, as: Self.self) { try $0.pointee.workloadExit(node) }
    }
}

extension ExplicitlyIdentifiedElement {
    static func explicitID(of element: any Element) -> AnyElementID {
        withConcrete(element, as: Self.self) { $0.pointee.explicitID }
    }
}

extension IdentityWrapperElement {
    static func wrappedContent(of element: any Element) -> any Element {
        withConcrete(element, as: Self.self) { $0.pointee.wrappedContent }
    }
}
