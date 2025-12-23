// MARK: - Group

/// A container that groups multiple elements without affecting layout or rendering.
///
/// Use `Group` when you need to return multiple elements from a property or
/// apply modifiers to a collection of elements.
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
///
/// ## Extracting Complex Content
///
/// Use `Group` to create helper properties:
///
/// ```swift
/// var debugElements: some Element {
///     Group {
///         DebugGrid()
///         DebugAxes()
///     }
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
