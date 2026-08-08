@testable import MetalSprockets
import Testing

/// Hits the `ElementBuilder` entry points that aren't exercised by normal
/// `@ElementBuilder` usage in the rest of the test suite.
@Suite("ElementBuilder Tests")
struct ElementBuilderTests {
    struct Leaf: Element {
        var body: some Element { EmptyElement() }
    }

    struct OtherLeaf: Element {
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

    @Test("buildEither(first:) stores the true branch")
    func buildEitherFirst() {
        let content: _ConditionalContent<Leaf, OtherLeaf> = ElementBuilder.buildEither(first: Leaf())
        #expect(content.first != nil)
        #expect(content.second == nil)
    }

    @Test("buildEither(second:) stores the false branch")
    func buildEitherSecond() {
        let content: _ConditionalContent<Leaf, OtherLeaf> = ElementBuilder.buildEither(second: OtherLeaf())
        #expect(content.first == nil)
        #expect(content.second != nil)
    }

    @Test("buildEither visits only the selected branch")
    func buildEitherVisitsSelectedBranch() throws {
        let first: _ConditionalContent<Leaf, OtherLeaf> = ElementBuilder.buildEither(first: Leaf())
        var visited: [String] = []
        try first.visitChildrenBodyless { visited.append("\(type(of: $0))") }
        #expect(visited == ["Leaf"])

        let second: _ConditionalContent<Leaf, OtherLeaf> = ElementBuilder.buildEither(second: OtherLeaf())
        visited = []
        try second.visitChildrenBodyless { visited.append("\(type(of: $0))") }
        #expect(visited == ["OtherLeaf"])
    }

    @Test("Switching branches requires setup")
    func buildEitherRequiresSetupOnBranchSwitch() {
        let first: _ConditionalContent<Leaf, OtherLeaf> = ElementBuilder.buildEither(first: Leaf())
        let sameFirst: _ConditionalContent<Leaf, OtherLeaf> = ElementBuilder.buildEither(first: Leaf())
        let second: _ConditionalContent<Leaf, OtherLeaf> = ElementBuilder.buildEither(second: OtherLeaf())
        #expect(first.requiresSetup(comparedTo: sameFirst) == false)
        #expect(first.requiresSetup(comparedTo: second) == true)
    }
}
