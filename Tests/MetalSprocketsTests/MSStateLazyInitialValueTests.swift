@testable import MetalSprockets
import Testing

// #578: declaration defaults are evaluated once per element identity; init assignments still work.
@MainActor
@Suite("MSState lazy initial value")
struct MSStateLazyInitialValueTests {
    final class Counter {
        var evaluations = 0
        func make(_ value: Int) -> Int {
            evaluations += 1
            return value
        }
    }

    nonisolated(unsafe) static var counter = Counter()

    struct Lazy: Element {
        @MSState var value = MSStateLazyInitialValueTests.counter.make(7)
        @MSState var typed: Int = MSStateLazyInitialValueTests.counter.make(8)
        @MSState var optional: Int?

        var body: some Element {
            _ = value
            _ = typed
            _ = optional
            return EmptyElement()
        }
    }

    struct Assigned: Element {
        let seed: Int
        @MSState var value: Int
        @MSState var withDefault = 1

        init(seed: Int) {
            self.seed = seed
            self.value = seed
            self.withDefault = seed * 2
        }

        var body: some Element {
            _ = value
            return EmptyElement()
        }
    }

    @Test func `declaration defaults are evaluated once across rebuilds`() throws {
        Self.counter = Counter()
        let system = System()
        for _ in 0..<5 {
            try system.update(root: Lazy())
        }
        #expect(Self.counter.evaluations == 2)
    }

    @Test func `assigning in init still works`() throws {
        let element = Assigned(seed: 3)
        let system = System()
        try system.update(root: element)
        system.withCurrentSystem {
            #expect(element.value == 3)
            #expect(element.withDefault == 6)
        }
    }

    @Test func `projected value is a binding`() throws {
        let element = Lazy()
        let system = System()
        try system.update(root: element)
        system.withCurrentSystem {
            element.$value.wrappedValue = 42
            #expect(element.value == 42)
            element.$optional.wrappedValue = 1
            #expect(element.optional == 1)
        }
    }
}
