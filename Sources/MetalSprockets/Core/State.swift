import os

// MARK: - MSState

/// A property wrapper that stores mutable state within an element.
///
/// `MSState` is analogous to SwiftUI's `@State`. Use it to store values that
/// can change over time and persist across render frames.
///
/// ## Overview
///
/// Declare state properties in your element:
///
/// ```swift
/// struct AnimatedTriangle: Element {
///     @MSState var rotation: Float = 0
///
///     var body: some Element {
///         RenderPass {
///             RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///                 Draw { encoder in
///                     rotation += 0.01  // Update state each frame
///                     // Use rotation value...
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Bindings
///
/// Access a binding to the state using the projected value (`$` prefix):
///
/// ```swift
/// ChildElement(rotation: $rotation)  // Pass binding to child
/// ```
///
/// ## See Also
///
/// - ``MSBinding``
/// - ``MSEnvironment``
@propertyWrapper
public struct MSState<Value> {
    // Updates swap in the persisted StateBox while a completion handler may hold this state, so the swap is locked
    // (#570).
    private let storage: StateBoxReference<Value>

    private var state: StateBox<Value> {
        get { storage.stateBox }
        nonmutating set { storage.stateBox = newValue }
    }

    /// Creates a state property with the specified initial value.
    ///
    /// - Parameter wrappedValue: The initial value for the state.
    public init(wrappedValue: Value) {
        storage = StateBoxReference(StateBox(wrappedValue))
    }

    /// The current value of the state.
    public var wrappedValue: Value {
        get {
            state.wrappedValue
        }
        nonmutating set {
            state.wrappedValue = newValue
        }
    }

    /// A binding to the state value.
    ///
    /// Use this to pass mutable access to child elements.
    public var projectedValue: MSBinding<Value> {
        state.binding
    }
}

/// `@MSState` reads and writes are safe from any thread, so state with a `Sendable` value can be captured by `@Sendable`
/// closures, such as completion handlers: `.onCommandBufferCompleted { [_baked] result in _baked.wrappedValue = … }`.
extension MSState: Sendable where Value: Sendable {}

/// The `StateBox` an `MSState` currently points at.
private final class StateBoxReference<Value>: @unchecked Sendable {
    private let lock: OSAllocatedUnfairLock<StateBox<Value>>

    init(_ stateBox: StateBox<Value>) {
        lock = OSAllocatedUnfairLock(uncheckedState: stateBox)
    }

    var stateBox: StateBox<Value> {
        get { lock.withLockUnchecked { $0 } }
        set { lock.withLockUnchecked { $0 = newValue } }
    }
}

extension MSState: MSDynamicProperty {
    /// Restores the `StateBox` the node is holding so the value survives the element struct
    /// being recreated.
    public nonmutating func update(in context: MSDynamicPropertyContext) {
        guard let persisted = context.persistedValue(forKey: context.label) else {
            return
        }
        guard let persisted = persisted as? StateBox<Value> else {
            preconditionFailure("Expected StateBox<Value> for state property \(context.label)")
        }
        state = persisted
    }

    public nonmutating func persist(in context: MSDynamicPropertyContext) {
        context.setPersistedValue(state, forKey: context.label)
    }
}
