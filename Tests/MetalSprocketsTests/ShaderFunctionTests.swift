import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@Suite("Shader function provenance")
struct ShaderFunctionTests {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    constant uint amount [[function_constant(0)]];
    kernel void specialized(device uint *output [[buffer(0)]]) { output[0] = amount; }
    kernel void plain(device uint *output [[buffer(0)]]) { output[0] = 1; }
    [[visible]] uint transform(uint value) { return value + amount; }
    """

    @Test
    func identityIncludesLibraryAndConstants() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(source: Self.source, options: nil)
        let otherLibrary = try device.makeLibrary(source: Self.source, options: nil)
        let first = try ShaderFunction(library: library, name: "plain", type: .kernel)
        let equivalent = try ShaderFunction(library: library, name: "plain", type: .kernel)
        let other = try ShaderFunction(library: otherLibrary, name: "plain", type: .kernel)
        #expect(first == equivalent)
        #expect(first != other)
        #expect(Set([first, equivalent, other]).count == 2)
        var constants = FunctionConstants()
        constants["amount"] = .uint32(3)
        let specialized = try ShaderFunction(library: library, name: "specialized", type: .kernel, constants: constants)
        constants["amount"] = .uint32(7)
        let changed = try ShaderFunction(library: library, name: "specialized", type: .kernel, constants: constants)
        #expect(specialized != changed)
        #expect(specialized.library === library)
        #expect(specialized.metalFunction.device === device)
    }

    @Test
    func linkedSpecializationsRequireDistinctExportNames() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(source: Self.source, options: nil)
        var constants = FunctionConstants()
        constants["amount"] = .uint32(3)
        let first = try VisibleFunction(library: library, name: "transform", constants: constants)
        let firstNamed = try VisibleFunction(library: library, name: "transform", constants: constants, specializedName: "transformThree")
        constants["amount"] = .uint32(7)
        let second = try VisibleFunction(library: library, name: "transform", constants: constants)
        let secondNamed = try VisibleFunction(library: library, name: "transform", constants: constants, specializedName: "transformSeven")
        #expect(throws: MetalSprocketsError.self) {
            try ShaderDeviceCheck.validateLinkedFunctions([first, second], device: device, label: nil)
        }
        try ShaderDeviceCheck.validateLinkedFunctions([firstNamed, secondNamed], device: device, label: nil)
        #expect(first != firstNamed)
        #expect(firstNamed.function.name == "transformThree")
        #expect(throws: MetalSprocketsError.self) {
            try VisibleFunction(library: library, name: "transform", constants: constants, specializedName: "")
        }
    }

    @Test
    func namespaceValidationRejectsAmbiguityAndDuplicateAliases() throws {
        let namespaced = FunctionConstantInfo(name: "NS::amount", index: 0, dataType: .uint, required: true)
        var constants = FunctionConstants()
        constants["amount"] = .uint32(3)
        _ = try constants.validatedMTLConstants(declared: [namespaced.name: namespaced], functionName: "test")
        constants["NS::amount"] = .uint32(7)
        #expect(throws: MetalSprocketsError.self) {
            try constants.validatedMTLConstants(declared: [namespaced.name: namespaced], functionName: "test")
        }
        constants = FunctionConstants()
        constants["amount"] = .uint32(3)
        let other = FunctionConstantInfo(name: "Other::amount", index: 1, dataType: .uint, required: true)
        #expect(throws: MetalSprocketsError.self) {
            try constants.validatedMTLConstants(declared: [namespaced.name: namespaced, other.name: other], functionName: "test")
        }
    }

    @Test
    func invalidFunctionAndConstantInputsThrow() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(source: Self.source, options: nil)
        #expect(throws: MetalSprocketsError.self) {
            try ShaderFunction(library: library, name: "missing", type: .kernel)
        }
        #expect(throws: MetalSprocketsError.self) {
            try ShaderFunction(library: library, name: "plain", type: .vertex)
        }
        #expect(throws: MetalSprocketsError.self) {
            try ShaderFunction(library: library, name: "specialized", type: .kernel)
        }
        var constants = FunctionConstants()
        constants["amount"] = .float(3)
        #expect(throws: MetalSprocketsError.self) {
            try ShaderFunction(library: library, name: "specialized", type: .kernel, constants: constants)
        }
        constants = FunctionConstants()
        constants["unknown"] = .uint32(3)
        #expect(throws: MetalSprocketsError.self) {
            try ShaderFunction(library: library, name: "specialized", type: .kernel, constants: constants)
        }
        let optimizedOut = try ShaderFunction(library: library, name: "plain", type: .kernel, constants: constants)
        #expect(optimizedOut.constants == constants)
    }
}
