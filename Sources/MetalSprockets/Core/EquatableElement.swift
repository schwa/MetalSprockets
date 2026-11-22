/// An element that compares its content with the content's own `==`, like SwiftUI's `EquatableView`.
///
/// When the content is equal to the previous frame's and the environment has not changed, the system reuses the
/// whole subtree from that frame: it does not evaluate the content's `body` or anything below it. This makes
/// unchanged parts of a large scene cost much less to update (#598).
///
/// Create one with ``Element/equatable()``. Any `Equatable` element is already compared with `==`; this wrapper makes
/// the intent explicit, as in SwiftUI.
///
/// ```swift
/// struct Cube: Element, Equatable {
///     var transform: simd_float4x4
///
///     var body: some Element {
///         Draw(.triangle, vertexCount: 36)
///             .parameter("transform", value: transform)
///     }
/// }
///
/// ForEach(cubes) { cube in
///     Cube(transform: cube.transform).equatable()
/// }
/// ```
///
/// `body` must depend only on the stored properties that `==` compares and on the environment. A value it reads from
/// elsewhere is not compared, so a change to it is not seen until `==` returns false.
public struct EquatableElement<Content: Element & Equatable>: Element, Equatable, TransparentElement {
    public var content: Content

    // Gets no node: the content's node compares the content with `==` already, so a node for the wrapper would only
    // add cost.
    var transparentContent: any Element { content }

    public init(content: Content) {
        self.content = content
    }

    public var body: Content {
        content
    }
}

public extension Element where Self: Equatable {
    /// Prevents the element from updating its subtree when its new value is equal to its old value.
    func equatable() -> EquatableElement<Self> {
        EquatableElement(content: self)
    }
}
