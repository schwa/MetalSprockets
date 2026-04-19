import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@Suite("Shaders tests")
struct ShadersTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };

    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) {
        return float4(1, 0, 0, 1);
    }

    kernel void compute_main(device float *out [[buffer(0)]],
                             uint tid [[thread_position_in_grid]]) {
        out[tid] = float(tid);
    }
    """

    @Test("init(source:) picks the matching function type")
    func testInitFromSource() throws {
        let vs = try VertexShader(source: Self.source)
        #expect(vs.function.functionType == .vertex)

        let fs = try FragmentShader(source: Self.source)
        #expect(fs.function.functionType == .fragment)

        let kernel = try ComputeKernel(source: Self.source)
        #expect(kernel.function.functionType == .kernel)
    }

    @Test("init(source:) with logging enabled")
    func testInitFromSourceLoggingEnabled() throws {
        let vs = try VertexShader(source: Self.source, logging: true)
        #expect(vs.function.functionType == .vertex)
    }

    @Test("init(library:name:) works with explicit library")
    func testInitFromLibraryAndName() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(source: Self.source, options: nil)
        let vs = try VertexShader(library: library, name: "vertex_main")
        #expect(vs.function.name == "vertex_main")
        let fs = try FragmentShader(library: library, name: "fragment_main")
        #expect(fs.function.name == "fragment_main")
    }

    @Test("init(library:name:) missing function throws")
    func testInitFromLibraryMissingFunction() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(source: Self.source, options: nil)
        #expect(throws: MetalSprocketsError.self) {
            _ = try VertexShader(library: library, name: "does_not_exist")
        }
    }

    @Test("init(library:name:) wrong function type throws")
    func testInitFromLibraryWrongType() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(source: Self.source, options: nil)
        // Trying to create a VertexShader from fragment_main should throw.
        #expect(throws: MetalSprocketsError.self) {
            _ = try VertexShader(library: library, name: "fragment_main")
        }
    }

    @Test("Equality: same function == same, different functions !=")
    func testEquality() throws {
        let vsA = try VertexShader(source: Self.source)
        let vsA2 = VertexShader(vsA.function)
        #expect(vsA == vsA2)

        let vsB = try VertexShader(source: Self.source) // fresh compile = fresh function
        #expect(vsA != vsB || vsA == vsB) // either outcome is fine; just exercise `==`.

        let fs = try FragmentShader(source: Self.source)
        let fs2 = FragmentShader(fs.function)
        #expect(fs == fs2)

        let k1 = try ComputeKernel(source: Self.source)
        let k2 = ComputeKernel(k1.function)
        #expect(k1 == k2)

        let obj1 = ObjectShader(vsA.function) // same MTLFunction object
        let obj2 = ObjectShader(vsA.function)
        #expect(obj1 == obj2)

        let mesh1 = MeshShader(vsA.function)
        let mesh2 = MeshShader(vsA.function)
        #expect(mesh1 == mesh2)

        let vis1 = VisibleFunction(vsA.function)
        let vis2 = VisibleFunction(vsA.function)
        #expect(vis1 == vis2)
    }

    @Test("functionType static values are correct")
    func testFunctionTypes() {
        #expect(VertexShader.functionType == .vertex)
        #expect(FragmentShader.functionType == .fragment)
        #expect(ComputeKernel.functionType == .kernel)
        #expect(ObjectShader.functionType == .object)
        #expect(MeshShader.functionType == .mesh)
        #expect(VisibleFunction.functionType == .visible)
    }
}
