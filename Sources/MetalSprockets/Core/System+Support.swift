internal extension System {
    func withCurrentSystem<R>(_ closure: () throws -> R) rethrows -> R {
        try System.$current.withValue(self, operation: closure)
    }
}
