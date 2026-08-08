// MARK: - MSEnvironmentValues

/// A collection of environment values propagated through the element tree.
///
/// Environment values flow down from parent elements to children, providing
/// shared context like the Metal device, render pass descriptor, and custom values.
/// You can define your own custom environment values using the `@MSEntry` macro
/// or by manually conforming to ``MSEnvironmentKey``.
///
/// ## Accessing Environment Values
///
/// Use the ``MSEnvironment`` property wrapper to read environment values:
///
/// ```swift
/// struct MyElement: Element {
///     @MSEnvironment(\.device) var device
///
///     var body: some Element {
///         // Use device...
///     }
/// }
/// ```
///
/// ## Custom Environment Keys
///
/// The preferred way to define custom environment values is with the `@MSEntry` macro:
///
/// ```swift
/// extension MSEnvironmentValues {
///     @MSEntry var myCustomValue: Int = 0
/// }
/// ```
///
/// Alternatively, you can manually conform to ``MSEnvironmentKey``:
///
/// ```swift
/// struct MyCustomKey: MSEnvironmentKey {
///     static var defaultValue: Int { 0 }
/// }
///
/// extension MSEnvironmentValues {
///     var myCustomValue: Int {
///         get { self[MyCustomKey.self] }
///         set { self[MyCustomKey.self] = newValue }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Related Types
/// - ``MSEnvironment``
/// - ``MSEnvironmentKey``
public struct MSEnvironmentValues {
    struct Key: Hashable, CustomDebugStringConvertible {
        var id: ObjectIdentifier
        var value: Any.Type
    }

    /// Values written directly on this environment.
    private(set) var values: [Key: Any] = [:]

    /// The parent environment's effective values, captured when ``inherit(from:)`` was last called.
    private(set) var inheritedValues: [Key: Any] = [:]

    /// ``values`` layered over ``inheritedValues``, maintained eagerly so lookups stay O(1).
    private(set) var effectiveValues: [Key: Any] = [:]

    /// Re-reads the parent's effective values, leaving this environment's own values in place.
    ///
    /// Called on every node as the tree is traversed, so values written by ancestors during the
    /// setup and workload phases become visible to descendants entered afterwards.
    internal mutating func inherit(from parent: Self) {
        inheritedValues = parent.effectiveValues
        recomputeEffectiveValues()
    }

    /// Drops inherited values, keeping the values written directly on this environment.
    internal mutating func removeInheritedValues() {
        inheritedValues = [:]
        recomputeEffectiveValues()
    }

    internal mutating func setValue(_ value: Any?, forKey key: Key) {
        values[key] = value
        recomputeEffectiveValues()
    }

    private mutating func recomputeEffectiveValues() {
        effectiveValues = values.isEmpty ? inheritedValues : inheritedValues.merging(values) { _, own in own }
    }
}

/// A key for accessing values in the environment.
///
/// Conform to this protocol to define custom environment values that propagate
/// through the element tree.
///
/// ## Example
///
/// ```swift
/// struct CameraKey: MSEnvironmentKey {
///     static var defaultValue: Camera? { nil }
/// }
///
/// extension MSEnvironmentValues {
///     var camera: Camera? {
///         get { self[CameraKey.self] }
///         set { self[CameraKey.self] = newValue }
///     }
/// }
/// ```
public protocol MSEnvironmentKey {
    /// The type of value stored by this key.
    associatedtype Value

    /// The default value used when no explicit value has been set.
    static var defaultValue: Value { get }
}

public extension MSEnvironmentValues {
    subscript<Key: MSEnvironmentKey>(key: Key.Type) -> Key.Value {
        get {
            if let value = effectiveValues[.init(key)] as? Key.Value {
                return value
            }
            return Key.defaultValue
        }
        set {
            setValue(newValue, forKey: .init(key))
        }
    }
}

/// A property wrapper that reads a value from the element's environment.
///
/// `MSEnvironment` is analogous to SwiftUI's `@Environment`. Use it to access
/// shared context that flows down from parent elements.
///
/// ## Overview
///
/// Read built-in environment values:
///
/// ```swift
/// struct MyElement: Element {
///     @MSEnvironment(\.device) var device
///     @MSEnvironment(\.renderCommandEncoder) var encoder
///
///     var body: some Element {
///         // Use device and encoder...
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Related Types
/// - ``MSEnvironmentValues``
/// - ``MSEnvironmentKey``
/// - ``MSState``
/// - ``MSBinding``
/// Marks a property wrapper whose value comes from the environment rather than from the element's own storage.
/// Two elements holding one compare unequal: their stored fields say nothing about the environment they will read.
internal protocol EnvironmentDependentProperty {}

@propertyWrapper
public struct MSEnvironment <Value>: EnvironmentDependentProperty {
    /// The current value from the environment.
    public var wrappedValue: Value {
        guard let system = System.current else {
            preconditionFailure("Environment must be used within a System.")
        }
        guard let currentNode = system.traversalContext.currentNode else {
            preconditionFailure("Environment must be used within a System during an active traversal.")
        }
        return currentNode.environmentValues[keyPath: keyPath]
    }

    private var keyPath: KeyPath<MSEnvironmentValues, Value>

    /// Creates an environment property wrapper for the specified key path.
    ///
    /// - Parameter keyPath: A key path to the environment value to read.
    public init(_ keyPath: KeyPath<MSEnvironmentValues, Value>) {
        self.keyPath = keyPath
    }
}

extension MSEnvironmentValues.Key {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }

    init<K: MSEnvironmentKey>(_ key: K.Type) {
        id = ObjectIdentifier(key)
        value = key
    }

    var debugDescription: String {
        "\(value)"
    }
}

extension MSEnvironmentValues: CustomDebugStringConvertible {
    public var debugDescription: String {
        let keys = values.map { "\($0.key)".trimmingPrefix("__Key_") }.sorted()
        let inheritedKeys = inheritedValues.map { "\($0.key)".trimmingPrefix("__Key_") }.sorted()
        return "(values: [\(keys.joined(separator: ", "))], inherited: [\(inheritedKeys.joined(separator: ", "))])"
    }
}
