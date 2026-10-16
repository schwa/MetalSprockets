import Synchronization

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
    let info = ComparisonCache.info(for: lhs)
    if let equatableType = info.equatableType {
        return equatableType.isEqualErased(lhs, rhs)
    }
    guard !info.isClass, !(type(of: rhs) is AnyClass) else {
        return false
    }
    if info.isNeverEqual {
        return false
    }
    return isEqualStructurally(lhs, rhs)
}

extension Equatable {
    /// `lhs` must have type `Self` (it comes from the cached metatype of `lhs`). Different dynamic types are unequal.
    static func isEqualErased(_ lhs: Any, _ rhs: Any) -> Bool {
        guard let rhs = rhs as? Self else {
            return false
        }
        // swiftlint:disable:next force_cast
        return (lhs as! Self) == rhs
    }
}

/// Compares one stored property of a non-Equatable element.
///
/// Unlike an element, a class-typed property is compared by identity: an element holding the same model instance
/// (for example an `@Observable`) has not changed. (#352)
private func isEqualStoredProperty(_ lhs: Any, _ rhs: Any) -> Bool {
    if let equatableType = ComparisonCache.info(for: lhs).equatableType {
        return equatableType.isEqualErased(lhs, rhs)
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
    if ComparisonCache.isNeverEqual(lhs) {
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
    // Same type, so the field count and labels match.
    let pairs = Array(zip(lhsMirror.children, rhsMirror.children))
    // Child elements go last: they can be whole subtrees, and a cheap field (often a closure) usually decides
    // first. Comparing content first made reconciliation quadratic in tree depth. (#479)
    let isElement = { (pair: (Mirror.Child, Mirror.Child)) in pair.0.value is any Element }
    return pairs.lazy.filter { !isElement($0) }.allSatisfy { isEqualStoredProperty($0.value, $1.value) }
        && pairs.lazy.filter(isElement).allSatisfy { isEqualStoredProperty($0.value, $1.value) }
}

/// Per-type facts used by `isEqual`, computed once per type instead of on every comparison (#495).
internal enum ComparisonCache {
    struct Info: @unchecked Sendable {
        var equatableType: (any Equatable.Type)?
        var isClass: Bool
        /// See ``isNeverEqual(_:)``. Only computed for non-Equatable, non-class types.
        var isNeverEqual = false

        var isEquatable: Bool { equatableType != nil }
    }

    private static let infos = Mutex<[ObjectIdentifier: Info]>([:])
    private static let neverEqual = Mutex<[ObjectIdentifier: Bool]>([:])

    static func info(for value: Any) -> Info {
        let key = ObjectIdentifier(type(of: value))
        if let info = infos.withLock({ $0[key] }) {
            return info
        }
        var info = Info(equatableType: type(of: value) as? any Equatable.Type, isClass: type(of: value) is AnyClass)
        if !info.isEquatable, !info.isClass {
            info.isNeverEqual = isNeverEqual(value)
        }
        infos.withLock { $0[key] = info }
        return info
    }

    /// True when a struct has a stored property that can never compare equal (a closure, a non-Equatable dynamic
    /// property, or another non-Equatable value that is not a struct, optional or class). Such values always rebuild.
    ///
    /// Decided from the first value seen. If a field declared as `Any` or another existential later holds something
    /// comparable, the cached answer only causes an extra rebuild, never a missed change.
    static func isNeverEqual(_ value: Any) -> Bool {
        let key = ObjectIdentifier(type(of: value))
        if let cached = neverEqual.withLock({ $0[key] }) {
            return cached
        }
        let mirror = Mirror(reflecting: value)
        let result = mirror.displayStyle == .struct && mirror.children.contains { child in
            isAlwaysUnequal(child.value)
        }
        neverEqual.withLock { $0[key] = result }
        return result
    }

    // Mirrors the cases where isEqualStoredProperty returns false whatever the other value is.
    private static func isAlwaysUnequal(_ value: Any) -> Bool {
        if info(for: value).isEquatable {
            return false
        }
        if value is any MSDynamicProperty || value is any EnvironmentDependentProperty {
            return true
        }
        if info(for: value).isClass {
            return false
        }
        switch Mirror(reflecting: value).displayStyle {
        case .struct:
            // A nested struct that is never equal makes this field never equal too, for example ForEach's
            // IdentifiedElement wrapping a modifier that holds a closure (#506).
            return isNeverEqual(value)
        case .optional:
            return false
        default:
            return true
        }
    }
}
