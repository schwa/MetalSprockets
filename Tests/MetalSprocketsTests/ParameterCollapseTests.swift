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
        #expect(Set(modifier.collapsed.parameters.keys.map(\.name)) == ["a", "b", "c"])
        #expect(modifier.collapsed.content is EmptyElement)
    }

    @Test func `the binding nearest the content wins for a repeated name in the same stage`() throws {
        let element = EmptyElement()
            .parameter("color", functionType: .fragment, value: SIMD4<Float>(1, 0, 0, 1))
            .parameter("color", functionType: .fragment, value: SIMD4<Float>(0, 1, 0, 1))

        let modifier = try #require(element as? ParameterElementModifier<ParameterElementModifier<EmptyElement>>)
        #expect(modifier.collapsed.parameters.count == 1)
    }

    // The same name bound once per stage is a normal pattern (SkyboxRenderPipeline binds
    // inverseViewProjectionMatrix to both vertex and fragment). Collapsing must keep both. See #382.
    @Test func `the same name in different stages survives collapsing`() throws {
        let element = EmptyElement()
            .parameter("matrix", functionType: .vertex, value: simd_float4x4.identity)
            .parameter("matrix", functionType: .fragment, value: simd_float4x4.identity)

        let modifier = try #require(element as? ParameterElementModifier<ParameterElementModifier<EmptyElement>>)
        let stages = Set(modifier.collapsed.parameters.values.filter { $0.name == "matrix" }.map(\.functionTypes))
        #expect(stages == [.init(.vertex), .init(.fragment)])
    }

    @Test func `bitwise-copyable structs bind as single values`() throws {
        struct Uniforms: BitwiseCopyable {
            var transform: simd_float4x4
            var tint: SIMD4<Float>
        }

        let element = EmptyElement().parameter("uniforms", value: Uniforms(transform: .identity, tint: [1, 0, 0, 1]))
        let modifier = try #require(element as? ParameterElementModifier<EmptyElement>)
        #expect(modifier.parameters.keys.contains { $0.name == "uniforms" })
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
