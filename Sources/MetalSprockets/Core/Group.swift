// MARK: - Group

/// A container that groups multiple elements for organizational purposes.
///
/// Use `Group` when you need to return multiple elements from a property or
/// apply modifiers to a collection of elements. The order of elements within
/// a `Group` matters, just as it does in a `body` property.
///
/// ## Overview
///
/// Group elements together:
///
/// ```swift
/// var body: some Element {
///     Group {
///         Element1()
///         Element2()
///         Element3()
///     }
///     .environment(\.someValue, value)  // Applied to all children
/// }
/// ```
public struct Group <Content>: Element where Content: Element {
    public typealias Body = Never

    internal let content: Content

    /// Creates a group containing the specified elements.
    public init(@ElementBuilder content: () throws -> Content) throws {
        self.content = try content()
    }
}

extension Group: BodylessElement, BodylessContentElement {
}
