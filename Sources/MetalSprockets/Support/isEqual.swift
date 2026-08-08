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
    return Mirror(reflecting: lhs).children.isEmpty && Mirror(reflecting: rhs).children.isEmpty
}
