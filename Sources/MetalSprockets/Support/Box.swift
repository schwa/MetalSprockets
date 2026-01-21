/// Contain a value with-in a reference type.
@propertyWrapper
internal final class Box<Wrapped> {
    internal var wrappedValue: Wrapped

    internal init(_ wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }
}
