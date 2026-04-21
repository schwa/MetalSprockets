import Foundation
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@Suite
struct ShaderLibraryTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]]
    ) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant float4 &color [[buffer(0)]]
    ) {
        return color;
    }

    kernel void compute_main(
        device uint *out [[buffer(0)]],
        uint tid [[thread_position_in_grid]]
    ) {
        out[tid] = tid;
    }
    """

    static let namespacedSource = """
    #include <metal_stdlib>
    using namespace metal;

    namespace MyNS {
        kernel void my_kernel(
            device uint *out [[buffer(0)]],
            uint tid [[thread_position_in_grid]]
        ) {
            out[tid] = tid;
        }
    }
    """

    // MARK: - Construction

    @Test
    func testInitFromSource() throws {
        let library = try ShaderLibrary(source: Self.source)
        if case .source(let s, _) = library.id {
            #expect(s == Self.source)
        } else {
            Issue.record("Expected .source ID")
        }
    }

    @Test
    func testInitFromMTLLibrary() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let mtlLibrary = try device.makeLibrary(source: Self.source, options: nil)
        let library = ShaderLibrary(library: mtlLibrary)
        if case .library(let wrapped) = library.id {
            #expect(wrapped === mtlLibrary)
        } else {
            Issue.record("Expected .library ID")
        }
    }

    @Test
    func testInitFromEmptyBundleThrows() throws {
        // An empty bundle (tmp dir) has no default.metallib.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("EmptyBundle-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let bundle = try #require(Bundle(url: tmp))
        #expect(throws: MetalSprocketsError.self) {
            _ = try ShaderLibrary(bundle: bundle)
        }
    }

    // MARK: - Function lookup

    @Test
    func testFunctionByType() throws {
        let library = try ShaderLibrary(source: Self.source)
        let vs: VertexShader = try library.function(type: VertexShader.self, named: "vertex_main")
        #expect(vs.function.functionType == .vertex)
        let fs: FragmentShader = try library.function(type: FragmentShader.self, named: "fragment_main")
        #expect(fs.function.functionType == .fragment)
        let kernel: ComputeKernel = try library.function(type: ComputeKernel.self, named: "compute_main")
        #expect(kernel.function.functionType == .kernel)
    }

    @Test
    func testDynamicMemberLookup() throws {
        let library = try ShaderLibrary(source: Self.source)
        let vs: VertexShader = try library.vertex_main
        #expect(vs.function.name == "vertex_main")
        let fs: FragmentShader = try library.fragment_main
        #expect(fs.function.name == "fragment_main")
        let ck: ComputeKernel = try library.compute_main
        #expect(ck.function.name == "compute_main")
    }

    @Test
    func testRequiredFunction() throws {
        let library = try ShaderLibrary(source: Self.source)
        let vs = library.requiredFunction(type: VertexShader.self, named: "vertex_main")
        #expect(vs.function.name == "vertex_main")
    }

    @Test
    func testMissingFunctionThrows() throws {
        let library = try ShaderLibrary(source: Self.source)
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: VertexShader.self, named: "does_not_exist")
        }
    }

    @Test
    func testWrongFunctionTypeThrows() throws {
        let library = try ShaderLibrary(source: Self.source)
        #expect(throws: MetalSprocketsError.self) {
            // vertex_main is a vertex function, not a fragment
            _ = try library.function(type: FragmentShader.self, named: "vertex_main")
        }
    }

    @Test
    func testFunctionIsCached() throws {
        let library = try ShaderLibrary(source: Self.source)
        let a: VertexShader = try library.function(type: VertexShader.self, named: "vertex_main")
        let b: VertexShader = try library.function(type: VertexShader.self, named: "vertex_main")
        // Cached MTLFunction should be identical object.
        #expect(a.function === b.function)
    }

    // MARK: - Namespacing

    @Test
    func testNamespacedFunction() throws {
        let library = try ShaderLibrary(source: Self.namespacedSource)
        let namespaced = library.namespaced("MyNS")
        let kernel: ComputeKernel = try namespaced.my_kernel
        #expect(kernel.function.functionType == .kernel)
    }

    @Test
    func testNamespacedFunctionByTypedMethod() throws {
        let library = try ShaderLibrary(source: Self.namespacedSource)
        let namespaced = library.namespaced("MyNS")
        let kernel = try namespaced.function(named: "my_kernel", type: ComputeKernel.self)
        #expect(kernel.function.functionType == .kernel)
    }

    @Test
    func testNamespacedRequiredFunction() throws {
        let library = try ShaderLibrary(source: Self.namespacedSource)
        let namespaced = library.namespaced("MyNS")
        let kernel = namespaced.requiredFunction(named: "my_kernel", type: ComputeKernel.self)
        #expect(kernel.function.functionType == .kernel)
    }

    // MARK: - ID equality / hashing

    @Test
    func testSourceIDEquality() throws {
        let a = try ShaderLibrary(source: Self.source)
        let b = try ShaderLibrary(source: Self.source)
        #expect(a.id == b.id)
        var hasher1 = Hasher()
        var hasher2 = Hasher()
        a.id.hash(into: &hasher1)
        b.id.hash(into: &hasher2)
        #expect(hasher1.finalize() == hasher2.finalize())
    }

    @Test
    func testSameSourceOutsideStoreHasSeparateLibraries() throws {
        // Without an ambient ShaderStore, two ShaderLibrary values built from
        // the same source compile independently. No process-global cache.
        let a = try ShaderLibrary(source: Self.source)
        let b = try ShaderLibrary(source: Self.source)
        #expect(a.library !== b.library)
    }

    @Test
    func testSharedStoreDedupesAdoptedLibraries() throws {
        // When two independently-compiled ShaderLibrary values are adopted by
        // the same ShaderStore, the second adoption returns the first's State.
        let store = ShaderStore()
        let stateA = ShaderLibrary.State(library: try MTLCreateSystemDefaultDevice()!.makeLibrary(source: Self.source, options: nil), id: .source(Self.source, nil))
        let stateB = ShaderLibrary.State(library: try MTLCreateSystemDefaultDevice()!.makeLibrary(source: Self.source, options: nil), id: .source(Self.source, nil))
        let adoptedA = store.adopt(stateA)
        let adoptedB = store.adopt(stateB)
        #expect(adoptedA === adoptedB)
        #expect(adoptedA === stateA)
    }

    @Test
    @MainActor
    func testAmbientStoreAdoptsOnFirstUseInSystem() throws {
        // Resolves ShaderLibrary.library from inside an EnvironmentReader (which
        // executes with a live activeNodeStack) and verifies both libraries end
        // up pointing at the same State after adoption by a shared store.
        let store = ShaderStore()
        let libA = try ShaderLibrary(source: Self.source)
        let libB = try ShaderLibrary(source: Self.source)

        // Sanity: they start with distinct MTLLibrary instances.
        #expect(libA.library !== libB.library)

        final class Captured: @unchecked Sendable { var a: MTLLibrary?; var b: MTLLibrary? }
        let captured = Captured()

        @MainActor
        func makeBody() -> EmptyElement {
            captured.a = libA.library
            captured.b = libB.library
            return EmptyElement()
        }

        let system = System()
        let root = EnvironmentReader(keyPath: \.shaderStore) { _ in
            makeBody()
        }
        .environment(\.shaderStore, store)

        try system.update(root: root)

        #expect(captured.a != nil)
        #expect(captured.a === captured.b)
    }

    @Test
    func testStoreDoesNotShareAcrossStores() throws {
        // Separate stores don't share state.
        let storeA = ShaderStore()
        let storeB = ShaderStore()
        let state1 = ShaderLibrary.State(library: try MTLCreateSystemDefaultDevice()!.makeLibrary(source: Self.source, options: nil), id: .source(Self.source, nil))
        let state2 = ShaderLibrary.State(library: try MTLCreateSystemDefaultDevice()!.makeLibrary(source: Self.source, options: nil), id: .source(Self.source, nil))
        #expect(storeA.adopt(state1) === state1)
        #expect(storeB.adopt(state2) === state2)
    }

    @Test
    func testBundleAndSourceIDsNotEqual() throws {
        let src = ShaderLibrary.ID.source("x", nil)
        let bundleID = ShaderLibrary.ID.bundle(.main)
        #expect(src != bundleID)
    }

    @Test
    func testLibraryIDEquality() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let mtl1 = try device.makeLibrary(source: Self.source, options: nil)
        let mtl2 = try device.makeLibrary(source: Self.source, options: nil)
        #expect(ShaderLibrary.ID.library(mtl1) == .library(mtl1))
        #expect(ShaderLibrary.ID.library(mtl1) != .library(mtl2))
    }
}
