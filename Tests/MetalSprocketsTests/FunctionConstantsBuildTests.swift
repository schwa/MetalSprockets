import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@Suite("FunctionConstants buildMTLConstants")
struct FunctionConstantsBuildTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    constant bool useFeature [[function_constant(0)]];
    constant float scale [[function_constant(1)]];

    namespace MyNS {
        constant int count [[function_constant(2)]];
    }

    kernel void my_kernel(device float *out [[buffer(0)]],
                          uint tid [[thread_position_in_grid]]) {
        float v = useFeature ? 1.0 : 0.0;
        v = v * scale * float(MyNS::count);
        out[tid] = v;
    }

    kernel void no_constants_kernel(device float *out [[buffer(0)]],
                                    uint tid [[thread_position_in_grid]]) {
        out[tid] = 1.0;
    }
    """

    static let ambiguousSource = """
    #include <metal_stdlib>
    using namespace metal;

    namespace A {
        constant int shared [[function_constant(0)]];
    }
    namespace B {
        constant int shared [[function_constant(1)]];
    }

    kernel void dual(device int *out [[buffer(0)]],
                     uint tid [[thread_position_in_grid]]) {
        out[tid] = A::shared + B::shared;
    }
    """

    private func makeLibrary(source: String) throws -> MTLLibrary {
        let device = MTLCreateSystemDefaultDevice()!
        return try device.makeLibrary(source: source, options: nil)
    }

    @Test("Build with exact match constant name")
    func testBuildExactMatch() throws {
        let library = try makeLibrary(source: Self.source)
        var constants = FunctionConstants()
        constants["useFeature"] = .bool(true)
        constants["scale"] = .float(2.5)
        constants["MyNS::count"] = .int32(3)

        let mtlConstants = try constants.buildMTLConstants(for: library, functionName: "my_kernel")
        _ = mtlConstants
    }

    @Test("Build with namespace-suffix search")
    func testBuildNamespaceSuffixSearch() throws {
        let library = try makeLibrary(source: Self.source)
        var constants = FunctionConstants()
        constants["useFeature"] = .bool(false)
        constants["scale"] = .float(1.0)
        // Leave out the namespace prefix - `count` should resolve to MyNS::count via suffix search.
        constants["count"] = .int32(7)
        _ = try constants.buildMTLConstants(for: library, functionName: "my_kernel")
    }

    @Test("Missing function name throws")
    func testMissingFunctionThrows() throws {
        let library = try makeLibrary(source: Self.source)
        var constants = FunctionConstants()
        constants["useFeature"] = .bool(true)
        #expect(throws: MetalSprocketsError.self) {
            _ = try constants.buildMTLConstants(for: library, functionName: "does_not_exist")
        }
    }

    @Test("Unknown constant name throws")
    func testUnknownConstantThrows() throws {
        let library = try makeLibrary(source: Self.source)
        var constants = FunctionConstants()
        constants["unknownConstant"] = .int32(1)
        #expect(throws: MetalSprocketsError.self) {
            _ = try constants.buildMTLConstants(for: library, functionName: "my_kernel")
        }
    }

    @Test("Unknown namespaced constant throws")
    func testUnknownNamespacedConstantThrows() throws {
        let library = try makeLibrary(source: Self.source)
        var constants = FunctionConstants()
        constants["MyNS::missing"] = .int32(1)
        #expect(throws: MetalSprocketsError.self) {
            _ = try constants.buildMTLConstants(for: library, functionName: "my_kernel")
        }
    }

    @Test("Ambiguous constant throws")
    func testAmbiguousConstantThrows() throws {
        let library = try makeLibrary(source: Self.ambiguousSource)
        var constants = FunctionConstants()
        // Both A::shared and B::shared match suffix `shared`.
        constants["shared"] = .int32(1)
        #expect(throws: MetalSprocketsError.self) {
            _ = try constants.buildMTLConstants(for: library, functionName: "dual")
        }
    }

    @Test("Function with no constants silently skips")
    func testFunctionWithNoConstantsSkips() throws {
        let library = try makeLibrary(source: Self.source)
        var constants = FunctionConstants()
        constants["ghost"] = .int32(1)
        // no_constants_kernel has an empty functionConstantsDictionary - should not throw.
        _ = try constants.buildMTLConstants(for: library, functionName: "no_constants_kernel")
    }
}
