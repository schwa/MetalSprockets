// MARK: - ForEach

/// Creates elements from a collection of data.
///
/// Use `ForEach` to generate elements dynamically from a collection,
/// similar to SwiftUI's `ForEach`.
///
/// ## Overview
///
/// Render multiple objects from an array:
///
/// ```swift
/// struct Scene: Element {
///     let objects: [GameObject]
///
///     var body: some Element {
///         RenderPass {
///             ForEach(objects) { object in
///                 ObjectRenderer(object: object)
///             }
///         }
///     }
/// }
/// ```
///
/// ## Identifiable Data
///
/// For types conforming to `Identifiable`, use the simple initializer:
///
/// ```swift
/// ForEach(objects) { object in ... }
/// ```
///
/// ## Custom ID Key Path
///
/// For non-identifiable types, specify an ID key path:
///
/// ```swift
/// ForEach(vertices, id: \.index) { vertex in ... }
/// ```
public struct ForEach <Data, ID, Content>: Element where Data: RandomAccessCollection, ID: Hashable, Content: Element {
    // TODO: #99 Compare ids to see if they've changed in expandNode
    //    @MSState
    //    var ids: [ID]

    var data: Data
    var content: (Data.Element) throws -> Content
}

public extension ForEach {
    /// Creates a ForEach from identifiable data.
    ///
    /// - Parameters:
    ///   - data: The collection of identifiable elements.
    ///   - content: A closure that creates an element for each data item.
    init(_ data: Data, @ElementBuilder content: @escaping (Data.Element) throws -> Content) where Data: Collection, Data.Element: Identifiable, Data.Element.ID == ID {
        //        self.ids = data.map(\.id)
        self.data = data
        self.content = content
    }

    /// Creates a ForEach using a key path for identification.
    ///
    /// - Parameters:
    ///   - data: The collection of elements.
    ///   - id: A key path to a hashable property for identification.
    ///   - content: A closure that creates an element for each data item.
    init(_ data: Data, id: KeyPath<Data.Element, ID>, @ElementBuilder content: @escaping (Data.Element) throws -> Content) where Data: Collection {
        //        self.ids = data.map { $0[keyPath: id] }
        self.data = data
        self.content = content
    }
}

// TODO: #209 We're not using ids in the System StructuralIdentifier yet - need to implement proper ID tracking for ForEach elements
extension ForEach: BodylessElement {
    internal func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        for datum in data {
            let child = try content(datum)
            try visit(child)
        }
    }
}
