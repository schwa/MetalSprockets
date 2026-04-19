import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@Suite("ShaderLibrary more coverage")
struct ShaderLibraryMoreTests {
    static let constantSource = """
    #include <metal_stdlib>
    using namespace metal;

    constant float scale [[function_constant(0)]];

    kernel void scaled_kernel(
        device float *out [[buffer(0)]],
        uint tid [[thread_position_in_grid]]
    ) {
        out[tid] = scale * float(tid);
    }

    [[visible]] float visible_helper(float x) {
        return x * 2.0;
    }
    """

    @Test("function(named:constants:) exercises the specialized-function path")
    func specializedFunctionWithConstants() throws {
        let library = try ShaderLibrary(source: Self.constantSource)
        var constants = FunctionConstants()
        constants["scale"] = .float(3.0)

        let kernel = try library.function(type: ComputeKernel.self, named: "scaled_kernel", constants: constants)
        #expect(kernel.function.functionType == .kernel)
    }

    @Test("Looking up a visible function via the VisibleFunction branch succeeds")
    func visibleFunctionLookup() throws {
        let library = try ShaderLibrary(source: Self.constantSource)
        let vis = try library.function(type: VisibleFunction.self, named: "visible_helper")
        #expect(vis.function.functionType == .visible)
    }

    @Test("Requesting the wrong shader type for a VisibleFunction throws")
    func visibleFunctionWrongTypeThrows() throws {
        let library = try ShaderLibrary(source: Self.constantSource)
        // scaled_kernel is a kernel, asking for it as a VisibleFunction should throw.
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: VisibleFunction.self, named: "scaled_kernel")
        }
    }

    @Test("Requesting an ObjectShader for a kernel function throws")
    func objectShaderWrongTypeThrows() throws {
        let library = try ShaderLibrary(source: Self.constantSource)
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: ObjectShader.self, named: "scaled_kernel")
        }
    }

    @Test("Requesting a MeshShader for a kernel function throws")
    func meshShaderWrongTypeThrows() throws {
        let library = try ShaderLibrary(source: Self.constantSource)
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: MeshShader.self, named: "scaled_kernel")
        }
    }
}
