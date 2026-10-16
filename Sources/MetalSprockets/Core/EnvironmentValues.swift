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

    /// A stored value. Boxed with its static type so reads use `unsafeDowncast` instead of a dynamic cast from `Any`:
    /// a key's value type is fixed, so the box for a key always has that key's `Value` type (#515).
    class Box: CustomStringConvertible {
        var description: String { "" }
    }

    final class TypedBox<Value>: Box {
        let value: Value
        init(_ value: Value) { self.value = value }
        override var description: String { "\(value)" }
    }

    /// Values written directly on this environment.
    private(set) var values: [Key: Box] = [:]

    /// The parent environment's effective values, captured when ``inherit(from:)`` was last called.
    private(set) var inheritedValues: [Key: Box] = [:]

    /// ``values`` layered over ``inheritedValues``, maintained eagerly so lookups stay O(1).
    private(set) var effectiveValues: [Key: Box] = [:]

    /// Re-reads the parent's effective values, leaving this environment's own values in place.
    ///
    /// Called on every node as the tree is traversed, so values written by ancestors during the
    /// setup and workload phases become visible to descendants entered afterwards.
    /// Reads a value as inherited from the parent, ignoring any value written on this environment.
    ///
    /// Accumulating modifiers use this so they rebuild from the parent's current value each frame instead of reading
    /// their own stale write back.
    internal func inheritedValue<Key: MSEnvironmentKey>(_ key: Key.Type) -> Key.Value {
        inheritedValues[.init(key)].map { unsafeDowncast($0, to: TypedBox<Key.Value>.self).value } ?? Key.defaultValue
    }

    /// The parameter set, stored outside the dictionaries. Parameter modifiers write it on every draw every frame, and a
    /// dictionary value of its own would make every such node copy and merge the whole environment each phase.
    private var ownParameterSet: ParameterSet??
    private var inheritedParameterSetStorage: ParameterSet?

    internal var parameterSet: ParameterSet? {
        get { ownParameterSet ?? inheritedParameterSetStorage }
        set { ownParameterSet = .some(newValue) }
    }

    /// The parameter set as inherited from the parent, ignoring this environment's own write.
    internal var inheritedParameterSet: ParameterSet? { inheritedParameterSetStorage }

    internal mutating func inherit(from parent: Self) {
        inheritedValues = parent.effectiveValues
        inheritedParameterSetStorage = parent.parameterSet
        recomputeEffectiveValues()
    }

    /// Drops inherited values, keeping the values written directly on this environment.
    internal mutating func removeInheritedValues() {
        inheritedValues = [:]
        inheritedParameterSetStorage = nil
        recomputeEffectiveValues()
    }

    // Updates the one key in place instead of re-merging the whole environment (#498).
    internal mutating func setValue(_ box: Box?, forKey key: Key) {
        values[key] = box
        effectiveValues[key] = box ?? inheritedValues[key]
    }

    private mutating func recomputeEffectiveValues() {
        guard !values.isEmpty else {
            effectiveValues = inheritedValues
            return
        }
        var effective = inheritedValues
        for (key, value) in values {
            effective[key] = value
        }
        effectiveValues = effective
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
            guard let box = effectiveValues[.init(key)] else {
                return Key.defaultValue
            }
            return unsafeDowncast(box, to: TypedBox<Key.Value>.self).value
        }
        set {
            setValue(TypedBox(newValue), forKey: .init(key))
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
