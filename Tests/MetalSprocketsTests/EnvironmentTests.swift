@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

extension MSEnvironmentValues {
    @MSEntry
    var exampleValue: String = "<default>"

    @MSEntry
    var exampleOptional: Int?
}

@MainActor
@Suite
struct EnvironmentTests {
    // Existing behaviour, kept by the boxed storage (#515): nil is a value and hides the inherited one.
    @Test func `writing nil to an optional key stores nil over the inherited value`() {
        var parent = MSEnvironmentValues()
        parent.exampleOptional = 1
        var child = MSEnvironmentValues()
        child.inherit(from: parent)
        child.exampleOptional = 2
        #expect(child.exampleOptional == 2)
        child.exampleOptional = nil
        #expect(child.exampleOptional == nil)
    }

    @Test func `the parameter set inherits like any other value`() {
        var parent = MSEnvironmentValues()
        var set = ParameterSet()
        set.set("a", value: Float(1))
        parent.parameterSet = set
        var child = MSEnvironmentValues()
        child.inherit(from: parent)
        #expect(child.parameterSet != nil)
        #expect(child.inheritedParameterSet != nil)
        child.parameterSet = nil
        #expect(child.parameterSet == nil)
        #expect(child.inheritedParameterSet != nil)
        child.removeInheritedValues()
        #expect(child.inheritedParameterSet == nil)
        var grandchild = MSEnvironmentValues()
        grandchild.inherit(from: child)
        #expect(grandchild.parameterSet == nil)
    }

    @Test func `values of every kind round-trip through storage`() {
        var values = MSEnvironmentValues()
        values.exampleValue = "set"
        values.exampleOptional = 3
        #expect(values.exampleValue == "set")
        #expect(values.exampleOptional == 3)
        #expect(MSEnvironmentValues().exampleValue == "<default>")
    }

    @Test
    func testEnvironment1() throws {
        struct Example1: Element {
            var body: some Element {
                EnvironmentReader(keyPath: \.exampleValue) { Example2(value: $0) }
                    .environment(\.exampleValue, "Hello world")
            }
        }

        struct Example2: Element, BodylessElement {
            typealias Body = Never
            var value: String
        }

        let root = Example1()
        let system = System()
        try system.update(root: root)

        let element = system.element(at: [0, 0, 0, 0], type: Example2.self)

        #expect(element!.value == "Hello world")
    }

    @Test
    func testEnvironment2() throws {
        struct Example1: Element {
            var body: some Element {
                Example2()
                    .environment(\.exampleValue, "Hello world")
            }
        }

        struct Example2: Element {
            @MSEnvironment(\.exampleValue)
            var value
            var body: some Element {
                Example3(value: value)
            }
        }

        struct Example3: Element, BodylessElement {
            typealias Body = Never
            var value: String
        }

        let system = System()
        try system.update(root: Example1())
        let element = system.element(at: [0, 0, 0, 0], type: Example3.self)
        #expect(element!.value == "Hello world")
    }

    @Test("transformEnvironment modifies the inherited value")
    func testTransformEnvironment() throws {
        struct Example1: Element {
            var body: some Element {
                Example2()
                    .transformEnvironment(\.exampleValue) { value in
                        value += " world"
                    }
                    .environment(\.exampleValue, "Hello")
            }
        }

        struct Example2: Element {
            @MSEnvironment(\.exampleValue)
            var value
            var body: some Element {
                Example3(value: value)
            }
        }

        struct Example3: Element, BodylessElement {
            typealias Body = Never
            var value: String
        }

        let system = System()
        try system.update(root: Example1())
        let element = system.element(at: [0, 0, 0, 0, 0], type: Example3.self)
        #expect(element?.value == "Hello world")
    }
}
