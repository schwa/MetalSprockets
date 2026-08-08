import Combine

@propertyWrapper
public struct MSObservedObject<ObjectType: ObservableObject> {
    @ObservedObjectBox
    private var object: ObjectType

    public init(wrappedValue: ObjectType) {
        _object = ObservedObjectBox(wrappedValue)
    }

    public var wrappedValue: ObjectType {
        object
    }

    public var projectedValue: ProjectedValue<ObjectType> {
        .init(self)
    }
}

extension MSObservedObject: Equatable {
    public static func == (l: MSObservedObject, r: MSObservedObject) -> Bool {
        l.wrappedValue === r.wrappedValue
    }
}

extension MSObservedObject: MSDynamicProperty {
    /// Subscribes the node to the observed object's change publisher for this update.
    public nonmutating func update(in context: MSDynamicPropertyContext) {
        _object.addDependency(context.node)
    }
}

@propertyWrapper
private final class ObservedObjectBox<Wrapped: ObservableObject> {
    let wrappedValue: Wrapped
    var cancellable: AnyCancellable?
    weak var node: Node?

    init(_ wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }

    func addDependency(_ node: Node) {
        guard node !== self.node else {
            return
        }
        self.node = node
        cancellable = wrappedValue.objectWillChange.sink { _ in
            node.system?.markDirty(node.id)
            node.needsSetup = true
        }
    }
}

@dynamicMemberLookup
public struct ProjectedValue <ObjectType: ObservableObject> {
    private var observedObject: MSObservedObject<ObjectType>

    internal init(_ observedObject: MSObservedObject<ObjectType>) {
        self.observedObject = observedObject
    }

    public subscript<Value>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Value>) -> MSBinding<Value> {
        MSBinding(get: {
            observedObject.wrappedValue[keyPath: keyPath]
        }, set: { newValue in
            observedObject.wrappedValue[keyPath: keyPath] = newValue
        })
    }
}
