/// Type-erased wrapper for a user-supplied explicit identity.
///
/// `@unchecked Sendable` because the underlying value is only ever read as a hashable
/// key, matching how `ShaderLibrary.ID` erases its payload.
///
/// `Int` identities (for example `ForEach(..., id: \.offset)`) are stored directly, so building, hashing and comparing
/// them every frame does not go through `AnyHashable`. An `Int` identity never equals one of another type.
public struct AnyElementID: Hashable, @unchecked Sendable {
    private enum Storage: Hashable {
        case int(Int)
        case other(AnyHashable)
    }

    private let storage: Storage

    public init<ID>(_ id: ID) where ID: Hashable {
        if ID.self == Int.self {
            storage = .int(unsafeBitCast(id, to: Int.self))
        } else {
            storage = .other(AnyHashable(id))
        }
    }
}

extension AnyElementID: CustomStringConvertible {
    public var description: String {
        switch storage {
        case .int(let value):
            String(describing: value)
        case .other(let value):
            String(describing: value.base)
        }
    }
}

/// An element that carries an explicit identity, contributed to its structural identifier.
internal protocol ExplicitlyIdentifiedElement {
    var explicitID: AnyElementID { get }
}

/// Wrapper produced by ``Element/id(_:)``.
///
/// Bodyless, so visiting its content needs no body evaluation or observation tracking: one per `ForEach` item.
/// An identity-only wrapper: the reconciler gives its content the wrapper's identity and skips the wrapper's node.
internal protocol IdentityWrapperElement: ExplicitlyIdentifiedElement {
    var wrappedContent: any Element { get }
}

internal struct IdentifiedElement<Content, ID>: Element, BodylessContentElement, IdentityWrapperElement where Content: Element, ID: Hashable {
    typealias Body = Never

    var content: Content
    var id: ID

    var explicitID: AnyElementID {
        AnyElementID(id)
    }

    var wrappedContent: any Element { content }
}

public extension Element {
    /// Binds an explicit identity to this element.
    ///
    /// Structural identity usually comes from the type of an element and its position among its siblings.
    /// When an element moves in a container, it gets a new identity, and setup runs again.
    /// To make identity follow the data instead of the position, use `id(_:)`:
    ///
    /// ```swift
    /// ForEach(passes) { pass in
    ///     pass.element
    ///         .id(pass.name)
    /// }
    /// ```
    ///
    /// - Parameter id: A hashable value identifying this element.
    /// - Returns: An element with the explicit identity applied.
    func id<ID>(_ id: ID) -> some Element where ID: Hashable {
        IdentifiedElement(content: self, id: id)
    }
}
