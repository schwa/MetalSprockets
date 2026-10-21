@testable import MetalSprockets
import Testing

/// Chains of plain `.environment(keyPath, value)` writers share one node (#518).
@MainActor
@Suite
struct EnvironmentWriterCollapseTests {
    struct Leaf: Element, BodylessElement {
        typealias Body = Never
    }

    private func environment(ofLeafIn root: some Element) throws -> (System, MSEnvironmentValues) {
        let system = System()
        try system.update(root: root)
        let leaf = try #require(system.nodes.values.first { $0.element is Leaf })
        return (system, leaf.environmentValues)
    }

    @Test func `a chain of plain writers is one node`() throws {
        let (system, values) = try environment(ofLeafIn: Leaf().environment(\.exampleValue, "inner").environment(\.exampleOptional, 1).environment(\.exampleValue, "outer"))
        #expect(system.nodes.count == 2)
        // The writer nearest the content wins, as with separate nodes.
        #expect(values.exampleValue == "inner")
        #expect(values.exampleOptional == 1)
    }

    @Test func `transformEnvironment keeps its own node and reads the inherited value`() throws {
        let (system, values) = try environment(ofLeafIn: Leaf()
            .transformEnvironment(\.exampleValue) { $0 += "+transform" }
            .environment(\.exampleOptional, 1)
            .environment(\.exampleValue, "outer"))
        #expect(system.nodes.count == 3)
        #expect(values.exampleValue == "outer+transform")
        #expect(values.exampleOptional == 1)
    }

    @Test func `a changed inner value requires setup`() throws {
        func chain(_ inner: Int?) -> any PlainEnvironmentWriterChain {
            // swiftlint:disable:next force_cast
            Leaf().environment(\.exampleOptional, inner).environment(\.exampleValue, "outer") as! any PlainEnvironmentWriterChain
        }
        #expect(chain(1).chainRequiresSetup(comparedTo: chain(1) as! any Element) == false)
        #expect(chain(1).chainRequiresSetup(comparedTo: chain(2) as! any Element))
    }

    @Test func `a reused node drops a key the chain no longer writes`() throws {
        struct Root: Element {
            var writesOptional: Bool
            var body: some Element {
                Leaf().environment(\.exampleOptional, writesOptional ? 1 : nil).environment(\.exampleValue, "outer")
            }
        }
        let system = System()
        try system.update(root: Root(writesOptional: true))
        try system.update(root: Root(writesOptional: false))
        let leaf = try #require(system.nodes.values.first { $0.element is Leaf })
        #expect(leaf.environmentValues.exampleOptional == nil)
        #expect(leaf.environmentValues.exampleValue == "outer")
    }
}
