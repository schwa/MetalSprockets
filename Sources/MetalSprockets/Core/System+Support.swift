internal extension System {
    func withCurrentSystem<R>(_ closure: () throws -> R) rethrows -> R {
        try Self.$current.withValue(self, operation: closure)
    }
}
