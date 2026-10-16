@testable import MetalSprockets
import Testing

@MainActor
@Suite("Comparison cache")
struct ComparisonCacheTests {
    private struct WithClosure: Element {
        var value = 1
        var action: () -> Void = {}
        var body: some Element { EmptyElement() }
    }

    private struct PlainFields: Element {
        var value = 1
        var name = "a"
        var body: some Element { EmptyElement() }
    }

    private struct WithOptionalClosure: Element {
        var action: (() -> Void)?
        var body: some Element { EmptyElement() }
    }

    private struct WithAnyField: Element {
        var payload: Any
        var body: some Element { EmptyElement() }
    }

    @Test func `a struct holding a closure is never equal`() {
        #expect(ComparisonCache.isNeverEqual(WithClosure()))
        #expect(isEqual(WithClosure(), WithClosure()) == false)
    }

    private struct Wrapper: Element {
        var id = 1
        var inner: WithClosure
        var body: some Element { EmptyElement() }
    }

    @Test func `a struct wrapping a never-equal struct is never equal`() {
        #expect(ComparisonCache.isNeverEqual(Wrapper(inner: WithClosure())))
        #expect(isEqual(Wrapper(inner: WithClosure()), Wrapper(inner: WithClosure())) == false)
    }

    @Test func `a struct with only comparable fields is compared field by field`() {
        #expect(ComparisonCache.isNeverEqual(PlainFields()) == false)
        #expect(isEqual(PlainFields(), PlainFields()))
        #expect(isEqual(PlainFields(), PlainFields(value: 2)) == false)
    }

    @Test func `an optional closure field does not make a type never equal`() {
        #expect(ComparisonCache.isNeverEqual(WithOptionalClosure()) == false)
        #expect(isEqual(WithOptionalClosure(), WithOptionalClosure()))
        let first = WithOptionalClosure { /* distinct closure */ }
        let second = WithOptionalClosure { /* distinct closure */ }
        #expect(isEqual(first, second) == false)
    }

    @Test func `equatable and class facts are cached per type`() {
        #expect(ComparisonCache.info(for: 1).isEquatable)
        #expect(ComparisonCache.info(for: PlainFields()).isEquatable == false)
        #expect(ComparisonCache.info(for: PlainFields()).isClass == false)
    }

    // The cache decides from the first value; for an `Any` field that only costs an extra rebuild.
    @Test func `a cached never-equal answer for an Any field errs towards rebuilding`() {
        let closure: () -> Void = { /* not comparable */ }
        #expect(ComparisonCache.isNeverEqual(WithAnyField(payload: closure)))
        #expect(isEqual(WithAnyField(payload: 1), WithAnyField(payload: 1)) == false)
    }
}
