import Foundation

// MARK: - MSBinding

/// A two-way connection to a mutable value owned by another element.
///
/// `MSBinding` is analogous to SwiftUI's `@Binding`. Use it to read and write
/// a value owned by a parent element, enabling two-way data flow through the
/// render graph.
///
/// ## Overview
///
/// Receive a binding from a parent element:
///
/// ```swift
/// struct RotatingCube: Element {
///     @MSBinding var rotation: Float
///
///     var body: some Element {
///         // Use and modify rotation...
///     }
/// }
///
/// // Parent creates binding from state:
/// struct Scene: Element {
///     @MSState var cubeRotation: Float = 0
///
///     var body: some Element {
///         RotatingCube(rotation: $cubeRotation)
///     }
/// }
/// ```
///
/// ## Creating Custom Bindings
///
/// Create a binding manually when you need custom get/set behavior:
///
/// ```swift
/// let binding = MSBinding(
///     get: { someValue },
///     set: { someValue = $0 }
/// )
/// ```
///
/// ## Topics
///
/// ### Related Types
/// - ``MSState``
/// - ``MSEnvironment``
@propertyWrapper
public struct MSBinding<Value>: Equatable {
    private let get: () -> Value
    private let set: (Value) -> Void
    // TOOD: Use a less expensive unique identifier
    private let id = UUID()

    /// Creates a binding with custom getter and setter closures.
    ///
    /// - Parameters:
    ///   - get: A closure that returns the current value.
    ///   - set: A closure that updates the value.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.get = get
        self.set = set
    }

    /// The current value of the binding.
    public var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
