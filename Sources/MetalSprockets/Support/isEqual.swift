internal func isEqual<LHS: Equatable, RHS: Equatable>(_ lhs: LHS, _ rhs: RHS) -> Bool {
    if let lhs = lhs as? RHS, lhs == rhs {
        return true
    }
    return false
}

internal func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    if let equatableLHS = lhs as? any Equatable, let equatableRHS = rhs as? any Equatable {
        return isEqual(equatableLHS, equatableRHS)
    }
    // Non-Equatable fallback: two values of the same type that store nothing carry no
    // information, so they cannot differ. Treating them as equal stops stateless elements
    // from rebuilding whenever a parent's state changes. (#197)
    // Reference types are excluded: distinct instances are meaningfully distinct even when
    // they store nothing.
    guard !(type(of: lhs) is AnyClass), !(type(of: rhs) is AnyClass), type(of: lhs) == type(of: rhs) else {
        return false
    }
    let lhsMirror = Mirror(reflecting: lhs)
    let rhsMirror = Mirror(reflecting: rhs)
    // Only structs are compared field by field. A closure (or anything else without a struct display style)
    // reflects as childless, and two distinct closures are not interchangeable.
    guard lhsMirror.displayStyle == .struct, rhsMirror.displayStyle == .struct else {
        return false
    }
    if lhsMirror.children.isEmpty, rhsMirror.children.isEmpty {
        return true
    }
    // Structural comparison: a non-Equatable struct is equal when every stored property is. This lets elements
    // holding non-Equatable payloads (e.g. an unused `@MSBinding`) still compare equal and be skipped. (#197)
    guard lhsMirror.children.count == rhsMirror.children.count else {
        return false
    }
    return zip(lhsMirror.children, rhsMirror.children).allSatisfy { lhsChild, rhsChild in
        guard lhsChild.label == rhsChild.label else {
            return false
        }
        if lhsChild.value is any EnvironmentDependentProperty {
            return false
        }
        if let lhsObject = lhsChild.value as? AnyObject, let rhsObject = rhsChild.value as? AnyObject,
            type(of: lhsChild.value) is AnyClass {
            return lhsObject === rhsObject
        }
        return isEqual(lhsChild.value, rhsChild.value)
    }
}
