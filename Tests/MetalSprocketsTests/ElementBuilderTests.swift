@testable import MetalSprockets
import Testing

/// Hits the `ElementBuilder` entry points that aren't exercised by normal
/// `@ElementBuilder` usage in the rest of the test suite.
@Suite("ElementBuilder Tests")
struct ElementBuilderTests {
    struct Leaf: Element {
        var body: some Element { EmptyElement() }
    }

    @Test("buildBlock() with no elements returns EmptyElement")
    func emptyBuildBlock() {
        let result = ElementBuilder.buildBlock()
        // Concrete type is EmptyElement; exercise the overload.
        _ = result
    }

    @Test("buildIf(nil) returns nil")
    func buildIfNil() {
        let result: Leaf? = ElementBuilder.buildIf(nil)
        #expect(result == nil)
    }

    @Test("buildIf(content) returns the content")
    func buildIfSome() {
        let result = ElementBuilder.buildIf(Leaf())
        #expect(result != nil)
    }

    @Test("buildLimitedAvailability wraps content in AnyElement")
    func buildLimitedAvailability() {
        let any = ElementBuilder.buildLimitedAvailability(Leaf())
        _ = any
    }
}
