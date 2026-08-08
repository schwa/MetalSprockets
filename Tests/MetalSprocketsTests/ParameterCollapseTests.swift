import Metal
@testable import MetalSprockets
import simd
import Testing

@MainActor
@Suite("Parameter modifier collapsing")
struct ParameterCollapseTests {
    @Test func `a chain of parameter modifiers produces a single node`() throws {
        let element = EmptyElement()
            .parameter("a", value: SIMD4<Float>(1, 0, 0, 1))
            .parameter("b", value: SIMD4<Float>(0, 1, 0, 1))
            .parameter("c", value: simd_float4x4.identity)

        let system = System()
        try system.update(root: element)

        let parameterNodes = system.nodes.values.filter { $0.element is any ParameterCollecting }
        #expect(parameterNodes.count == 1)
    }

    @Test func `collapsing gathers every parameter in the chain`() throws {
        let element = EmptyElement()
            .parameter("a", value: SIMD4<Float>(1, 0, 0, 1))
            .parameter("b", value: SIMD4<Float>(0, 1, 0, 1))
            .parameter("c", value: simd_float4x4.identity)

        let modifier = try #require(element as? ParameterElementModifier<ParameterElementModifier<ParameterElementModifier<EmptyElement>>>)
        #expect(Set(modifier.collapsed.parameters.keys) == ["a", "b", "c"])
        #expect(modifier.collapsed.content is EmptyElement)
    }

    @Test func `the binding nearest the content wins for a repeated name`() throws {
        let element = EmptyElement()
            .parameter("color", functionType: .fragment, value: SIMD4<Float>(1, 0, 0, 1))
            .parameter("color", functionType: .vertex, value: SIMD4<Float>(0, 1, 0, 1))

        let modifier = try #require(element as? ParameterElementModifier<ParameterElementModifier<EmptyElement>>)
        #expect(modifier.collapsed.parameters.count == 1)
        #expect(modifier.collapsed.parameters["color"]?.functionType == .fragment)
    }

    @Test func `an intervening modifier stops the collapse`() throws {
        let element = EmptyElement()
            .parameter("a", value: SIMD4<Float>(1, 0, 0, 1))
            .environment(\.device, nil)
            .parameter("b", value: SIMD4<Float>(0, 1, 0, 1))

        let system = System()
        try system.update(root: element)

        let parameterNodes = system.nodes.values.filter { $0.element is any ParameterCollecting }
        #expect(parameterNodes.count == 2)
    }
}
