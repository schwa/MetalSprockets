// MARK: - MSState

internal protocol StateProperty {
    var erasedValue: Any { get nonmutating set }
}

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
/// ## Topics
///
/// ### Related Types
/// - ``MSBinding``
/// - ``MSEnvironment``
@propertyWrapper
public struct MSState<Value> {
    @Box
    private var state: StateBox<Value>

    /// Creates a state property with the specified initial value.
    ///
    /// - Parameter wrappedValue: The initial value for the state.
    public init(wrappedValue: Value) {
        _state = Box(StateBox(wrappedValue))
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

extension MSState: StateProperty {
    internal var erasedValue: Any {
        get { state }
        nonmutating set {
            guard let newValue = newValue as? StateBox<Value> else {
                preconditionFailure("Expected StateBox<Value> in State.value set")
            }
            state = newValue
        }
    }
}
