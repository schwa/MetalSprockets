import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("Shader type mismatches")
struct ShaderLibraryTypeMismatchTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    [[vertex]] float4 vertex_main() {
        return float4(0, 0, 0, 1);
    }

    [[fragment]] float4 fragment_main() {
        return float4(1, 0, 0, 1);
    }

    [[kernel]] void kernel_main(device float *out [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
        out[tid] = 1;
    }
    """

    /// A `ShaderProtocol` conformer declared outside the framework, used to check that lookup is fully generic.
    struct UnknownShader: ShaderProtocol, Equatable {
        static var functionType: MTLFunctionType { .vertex }
        var function: MTLFunction

        init(_ function: MTLFunction) {
            self.function = function
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.function === rhs.function
        }
    }

    private func library() throws -> ShaderLibrary {
        try ShaderLibrary(source: Self.source)
    }

    @Test func `asking for a vertex shader by a fragment name is rejected`() throws {
        let library = try library()
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: VertexShader.self, named: "fragment_main")
        }
    }

    @Test func `asking for a kernel by a vertex name is rejected`() throws {
        let library = try library()
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: ComputeKernel.self, named: "vertex_main")
        }
    }

    @Test func `asking for a fragment shader by a kernel name is rejected`() throws {
        let library = try library()
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: FragmentShader.self, named: "kernel_main")
        }
    }

    @Test func `a shader type declared outside the framework is supported`() throws {
        let library = try library()
        let shader = try library.function(type: UnknownShader.self, named: "vertex_main")
        #expect(shader.function.functionType == .vertex)
    }

    @Test func `an out-of-framework shader type still checks the function type`() throws {
        let library = try library()
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: UnknownShader.self, named: "fragment_main")
        }
    }

    @Test func `a missing function name is rejected`() throws {
        let library = try library()
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: VertexShader.self, named: "no_such_function")
        }
    }

    @Test func `the matching type is returned`() throws {
        let library = try library()
        let vertexShader = try library.function(type: VertexShader.self, named: "vertex_main")
        #expect(vertexShader.function.functionType == .vertex)
    }
}
