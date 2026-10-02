import Metal
import MetalSprockets
import Testing

private struct CustomKernel: ShaderProtocol {
    static let functionType: MTLFunctionType = .kernel
    let reference: ShaderFunction

    init(_ reference: ShaderFunction) {
        self.reference = reference
    }
}

private final class CustomShaderLoader: ShaderLoader {
    let library: any MTLLibrary
    var libraryID: ShaderLibrary.ID { .library(library) }

    init(library: any MTLLibrary) {
        self.library = library
    }

    func shaderFunction(named name: String, type: MTLFunctionType, constants: FunctionConstants) throws -> ShaderFunction {
        try ShaderFunction(library: library, name: name, type: type, constants: constants)
    }

    func declaredConstants(forFunctionNamed name: String) throws -> [String: FunctionConstantInfo] {
        let function = try #require(library.makeFunction(name: name))
        return function.functionConstantInfos
    }
}

@Suite("Public shader provenance contracts")
struct ShaderProvenancePublicTests {
    @Test(.requiresMetal4)
    func customLoadersAndConformersPreservePipelineIdentity() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let runner = try Runner(device: device)
        let output = try #require(device.makeBuffer(length: 4, options: .storageModeShared))
        for libraryValue in [UInt32(10), UInt32(100)] {
            let library = try device.makeLibrary(source: """
            #include <metal_stdlib>
            using namespace metal;
            constant uint amount [[function_constant(0)]];
            kernel void evaluate(device uint *output [[buffer(0)]]) { output[0] = amount + \(libraryValue); }
            """, options: nil)
            let loader = CustomShaderLoader(library: library)
            let shaders = ShaderLibrary(loader: loader)
            for amount in [UInt32(3), UInt32(7), UInt32(3)] {
                var constants = FunctionConstants()
                constants["amount"] = .uint32(amount)
                let custom = try shaders.function(type: CustomKernel.self, named: "evaluate", constants: constants)
                #expect(custom.reference.library === library)
                #expect(custom.reference.constants == constants)
                #expect(custom.function.functionType == .kernel)
                #expect(try loader.function(named: "evaluate", type: .kernel, constants: constants).functionType == .kernel)
                let kernel = try ComputeKernel(custom.reference)
                let content = try ComputePass {
                    try ComputePipeline(computeKernel: kernel) {
                        try ComputeDispatch(threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1))
                            .parameter("output", buffer: output)
                    }
                }
                for _ in 0..<2 {
                    try runner.run(content)
                    #expect(output.contents().load(as: UInt32.self) == amount + libraryValue)
                }
            }
        }
    }
}
