import Foundation

internal struct OnChange<Value: Equatable, Content>: Element where Content: Element {
    let value: Value
    let initial: Bool
    let action: (Value, Value) -> Void
    let content: Content

    @MSState
    private var previousValue: Value?

    @MSState
    private var hasInitialized: Bool

    init(value: Value, initial: Bool, action: @escaping (Value, Value) -> Void, content: Content) {
        self.value = value
        self.initial = initial
        self.action = action
        self.content = content
        self.hasInitialized = false
    }

    var body: some Element {
        // Check if this is the initial setup
        if !hasInitialized {
            if initial {
                // Call action with same value for both old and new on initial setup
                action(value, value)
            }
            hasInitialized = true
            previousValue = value
        } else if let oldValue = previousValue, oldValue != value {
            // Value has changed, call the action
            action(oldValue, value)
            previousValue = value
        }

        return content
    }
}

// MARK: - onChange Modifier

public extension Element {
    /// Performs an action when a value changes.
    ///
    /// Use this modifier to respond to value changes during the render loop,
    /// similar to SwiftUI's `onChange`.
    ///
    /// ```swift
    /// struct AnimatedElement: Element {
    ///     let frameCount: Int
    ///
    ///     var body: some Element {
    ///         MyContent()
    ///             .onChange(of: frameCount) { oldValue, newValue in
    ///                 print("Frame changed from \(oldValue) to \(newValue)")
    ///             }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - value: The value to observe.
    ///   - initial: If `true`, the action is called on first render with the same value for old and new.
    ///   - action: A closure called when the value changes, receiving old and new values.
    func onChange<V: Equatable>(
        of value: V,
        initial: Bool = false,
        perform action: @escaping (V, V) -> Void
    ) -> some Element {
        OnChange(value: value, initial: initial, action: action, content: self)
    }

    /// Performs an action when a value changes (simplified version).
    ///
    /// - Parameters:
    ///   - value: The value to observe.
    ///   - action: A closure called when the value changes.
    func onChange<V: Equatable>(
        of value: V,
        perform action: @escaping () -> Void
    ) -> some Element {
        OnChange(value: value, initial: false, action: { _, _ in action() }, content: self)
    }
}
