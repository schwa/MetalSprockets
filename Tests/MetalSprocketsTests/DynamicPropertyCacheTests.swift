@testable import MetalSprockets
import Testing

@MainActor
@Suite("Dynamic property cache")
struct DynamicPropertyCacheTests {
    private struct Plain: Element {
        var value = 1
        var body: some Element { EmptyElement() }
    }

    private struct Stateful: Element {
        @MSState var count = 0
        var body: some Element { EmptyElement() }
    }

    private struct WithOptional: Element {
        var maybe: Int?
        var body: some Element { EmptyElement() }
    }

    @Test func `a type without dynamic properties is skipped`() {
        #expect(DynamicPropertyCache.mayHaveDynamicProperties(Plain()) == false)
        #expect(DynamicPropertyCache.mayHaveDynamicProperties(Plain(value: 2)) == false)
    }

    @Test func `a type with a dynamic property is always visited`() {
        #expect(DynamicPropertyCache.mayHaveDynamicProperties(Stateful()))
        #expect(DynamicPropertyCache.mayHaveDynamicProperties(Stateful()))
    }

    // Not cached, so this only checks the answer; existing @MSState tests cover state through configureNode.
    @Test func `a type with an optional field reports no dynamic properties`() {
        #expect(DynamicPropertyCache.mayHaveDynamicProperties(WithOptional()) == false)
        #expect(DynamicPropertyCache.mayHaveDynamicProperties(WithOptional(maybe: 3)) == false)
    }
}
