import Metal
@testable import MetalSprockets
import Testing

/// Third-pass batch of 1-to-3-line wins across small files.
@Suite("Easy Wins 3")
struct EasyWins3Tests {
    // MARK: MSBinding.==

    @Test("MSBinding equality compares identity, not value")
    func bindingEquality() {
        var storage = 0
        let a = MSBinding(get: { storage }, set: { storage = $0 })
        let b = MSBinding(get: { storage }, set: { storage = $0 })
        #expect(a != b) // Different identities even though they wrap the same storage.
        // Comparing `a` with itself via a second reference hits the equal-id branch.
        let aCopy = a
        #expect(a == aCopy)
    }

    // MARK: RenderPipelineDescriptorModifier.requiresSetup

    @Test("RenderPipelineDescriptorModifier.requiresSetup is true (conservative)")
    func renderPipelineDescriptorModifierRequiresSetup() {
        let a = RenderPipelineDescriptorModifier(content: EmptyElement()) { _ in }
        let b = RenderPipelineDescriptorModifier(content: EmptyElement()) { _ in }
        #expect(a.requiresSetup(comparedTo: b) == true)
    }

    // MARK: Element.printDump / dump

    @Test("Element.dump produces a hierarchical string")
    func elementDump() throws {
        struct Parent: Element {
            var body: some Element {
                EmptyElement()
                EmptyElement()
            }
        }
        let output = try Parent().dump()
        #expect(!output.isEmpty)
        // printDump is the stdout-printing twin; exercise it for coverage.
        try Parent().printDump()
    }

    // MARK: MSObservedObject equality

    @Test("MSObservedObject equality compares wrapped references")
    func observedObjectEquality() {
        final class Model: ObservableObject {}
        let modelA = Model()
        let modelB = Model()
        let a = MSObservedObject(wrappedValue: modelA)
        let b = MSObservedObject(wrappedValue: modelA)
        let c = MSObservedObject(wrappedValue: modelB)
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: isEqual fallback — covers the "not Equatable" branch returning false

    @Test("isEqual(Any, Any) returns false for non-Equatable values")
    func isEqualFallback() {
        // A class type that isn't Equatable hits the `rhs as? any Equatable` nil branch.
        final class NotEquatable {}
        let a: Any = NotEquatable()
        let b: Any = NotEquatable()
        // Internal function; still accessible via @testable.
        #expect(isEqual(a, b) == false)
    }

    // MARK: TupleElement.visitChildrenBodyless actually visits

    @Test("TupleElement.visitChildrenBodyless visits each child")
    func tupleElementVisit() {
        struct Leaf: Element {
            var body: some Element { EmptyElement() }
        }
        let tuple = TupleElement(Leaf(), Leaf(), Leaf())
        var visited = 0
        tuple.visitChildrenBodyless { _ in
            visited += 1
        }
        #expect(visited == 3)
    }

    // MARK: ForEach with Identifiable

    @Test("ForEach(Identifiable) initializer stores data and content")
    func forEachIdentifiable() {
        struct Item: Identifiable {
            let id: Int
        }
        let items = [Item(id: 1), Item(id: 2), Item(id: 3)]
        let forEach = ForEach(items) { _ in EmptyElement() }
        #expect(forEach.data.count == 3)
    }

    // MARK: Element.internalDescription

    @Test("Element.internalDescription returns the type name")
    func elementInternalDescription() {
        struct MyElement: Element {
            var body: some Element { EmptyElement() }
        }
        // internalDescription is an internal extension; reachable via @testable.
        let desc = MyElement().internalDescription
        #expect(desc.contains("MyElement"))
    }
}
