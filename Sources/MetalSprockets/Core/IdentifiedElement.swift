/// Type-erased wrapper for a user-supplied explicit identity.
///
/// `@unchecked Sendable` because the underlying value is only ever read as a hashable
/// key, matching how `ShaderLibrary.ID` erases its payload.
public struct AnyElementID: Hashable, @unchecked Sendable {
    private let base: AnyHashable

    public init<ID>(_ id: ID) where ID: Hashable {
        self.base = AnyHashable(id)
    }
}

extension AnyElementID: CustomStringConvertible {
    public var description: String {
        String(describing: base.base)
    }
}

/// An element that carries an explicit identity, contributed to its structural identifier.
internal protocol ExplicitlyIdentifiedElement {
    var explicitID: AnyElementID { get }
}

/// Wrapper produced by ``Element/id(_:)``.
internal struct IdentifiedElement<Content, ID>: Element, ExplicitlyIdentifiedElement where Content: Element, ID: Hashable {
    var content: Content
    var id: ID

    var explicitID: AnyElementID {
        AnyElementID(id)
    }

    var body: some Element {
        content
    }
}

public extension Element {
    /// Binds an explicit identity to this element.
    ///
    /// Structural identity is normally derived from an element's type and its position among
    /// its siblings, so moving an element within a container gives it a new identity and forces
    /// re-setup. Use `id(_:)` when identity should follow the data instead of the position:
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
