internal func isEqual<LHS: Equatable, RHS: Equatable>(_ lhs: LHS, _ rhs: RHS) -> Bool {
    if let lhs = lhs as? RHS, lhs == rhs {
        return true
    }
    return false
}

/// Compares two elements.
///
/// Class elements are never equal, even when they are the same instance: their mutable stored properties are
/// invisible here, so `System` has to re-evaluate them.
internal func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    if let equatableLHS = lhs as? any Equatable, let equatableRHS = rhs as? any Equatable {
        return isEqual(equatableLHS, equatableRHS)
    }
    guard !(type(of: lhs) is AnyClass), !(type(of: rhs) is AnyClass) else {
        return false
    }
    return isEqualStructurally(lhs, rhs)
}

/// Compares one stored property of a non-Equatable element.
///
/// Unlike an element, a class-typed property is compared by identity: an element holding the same model instance
/// (for example an `@Observable`) has not changed. (#352)
private func isEqualStoredProperty(_ lhs: Any, _ rhs: Any) -> Bool {
    if let equatableLHS = lhs as? any Equatable, let equatableRHS = rhs as? any Equatable {
        return isEqual(equatableLHS, equatableRHS)
    }
    // A non-Equatable dynamic property (e.g. `@MSState`) owns mutable storage that reflection cannot see through,
    // so it is always treated as changed.
    if lhs is any MSDynamicProperty || lhs is any EnvironmentDependentProperty {
        return false
    }
    guard type(of: lhs) == type(of: rhs) else {
        return false
    }
    if type(of: lhs) is AnyClass {
        return (lhs as AnyObject) === (rhs as AnyObject)
    }
    let lhsMirror = Mirror(reflecting: lhs)
    // A non-Equatable optional is equal when both are nil, or both wrap equal values. (#352)
    if lhsMirror.displayStyle == .optional {
        switch (lhsMirror.children.first, Mirror(reflecting: rhs).children.first) {
        case (nil, nil):
            return true
        case let (lhsWrapped?, rhsWrapped?):
            return isEqualStoredProperty(lhsWrapped.value, rhsWrapped.value)
        default:
            return false
        }
    }
    return isEqualStructurally(lhs, rhs)
}

/// Compares two non-Equatable values of the same type field by field.
private func isEqualStructurally(_ lhs: Any, _ rhs: Any) -> Bool {
    guard type(of: lhs) == type(of: rhs) else {
        return false
    }
    let lhsMirror = Mirror(reflecting: lhs)
    let rhsMirror = Mirror(reflecting: rhs)
    // Only structs are compared field by field. A closure (or anything else without a struct display style)
    // reflects as childless, and two distinct closures are not interchangeable.
    guard lhsMirror.displayStyle == .struct, rhsMirror.displayStyle == .struct else {
        return false
    }
    // Two values of the same type that store nothing carry no information, so they cannot differ. Treating them as
    // equal stops stateless elements from rebuilding whenever a parent's state changes. (#197)
    if lhsMirror.children.isEmpty, rhsMirror.children.isEmpty {
        return true
    }
    // A non-Equatable struct is equal when every stored property is. This lets elements holding non-Equatable
    // payloads (e.g. an unused `@MSBinding`) still compare equal and be skipped. (#197)
    guard lhsMirror.children.count == rhsMirror.children.count else {
        return false
    }
    return zip(lhsMirror.children, rhsMirror.children).allSatisfy { lhsChild, rhsChild in
        guard lhsChild.label == rhsChild.label else {
            return false
        }
        return isEqualStoredProperty(lhsChild.value, rhsChild.value)
    }
}
