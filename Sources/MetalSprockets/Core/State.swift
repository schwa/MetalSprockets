internal protocol StateProperty {
    var erasedValue: Any { get nonmutating set }
}

@propertyWrapper
public struct MSState<Value> {
    @Box
    private var state: StateBox<Value>

    public init(wrappedValue: Value) {
        _state = Box(StateBox(wrappedValue))
    }

    public var wrappedValue: Value {
        get {
            state.wrappedValue
        }
        nonmutating set {
            state.wrappedValue = newValue
        }
    }

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
