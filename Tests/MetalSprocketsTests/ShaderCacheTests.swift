import Metal
import Testing
@testable import MetalSprockets

struct ShaderCacheTests {
    // MARK: - Test Helpers

    private static let simpleComputeSource = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void testKernel(device float* output [[buffer(0)]],
                          uint id [[thread_position_in_grid]]) {
        output[id] = float(id);
    }
    """

    private static let simpleVertexSource = """
    #include <metal_stdlib>
    using namespace metal;

    vertex float4 testVertex(uint vertexID [[vertex_id]]) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }
    """

    private func makeTestLibrary(source: String) throws -> ShaderLibrary {
        try ShaderLibrary(source: source)
    }

    private func makeTestShader(library: ShaderLibrary, name: String) throws -> ComputeKernel {
        try library.function(named: name, type: ComputeKernel.self)
    }

    // MARK: - Basic Functionality Tests

    @Test("Cache stores and retrieves shader")
    func basicGetSet() throws {
        let cache = ShaderCache()
        let library = try makeTestLibrary(source: Self.simpleComputeSource)
        let shader = try makeTestShader(library: library, name: "testKernel")

        // Initially should be nil
        #expect(cache.get(library: library, name: "testKernel", functionConstants: nil) == nil)

        // Set shader
        cache.set(library: library, name: "testKernel", functionConstants: nil, shader: shader)

        // Should now retrieve the shader
        let retrieved = cache.get(library: library, name: "testKernel", functionConstants: nil)
        #expect(retrieved != nil)
        #expect(retrieved?.function === shader.function)
    }

    @Test("Cache miss returns nil")
    func cacheMiss() throws {
        let cache = ShaderCache()
        let library = try makeTestLibrary(source: Self.simpleComputeSource)

        // Getting non-existent shader should return nil
        let result = cache.get(library: library, name: "nonExistent", functionConstants: nil)
        #expect(result == nil)
    }

    @Test("Multiple shaders with different names")
    func multipleShadersPerLibrary() throws {
        let cache = ShaderCache()
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void kernel1(device float* output [[buffer(0)]]) {
            output[0] = 1.0;
        }

        kernel void kernel2(device float* output [[buffer(0)]]) {
            output[0] = 2.0;
        }
        """

        let library = try makeTestLibrary(source: source)
        let shader1 = try makeTestShader(library: library, name: "kernel1")
        let shader2 = try makeTestShader(library: library, name: "kernel2")

        cache.set(library: library, name: "kernel1", functionConstants: nil, shader: shader1)
        cache.set(library: library, name: "kernel2", functionConstants: nil, shader: shader2)

        let retrieved1 = cache.get(library: library, name: "kernel1", functionConstants: nil)
        let retrieved2 = cache.get(library: library, name: "kernel2", functionConstants: nil)

        #expect(retrieved1?.function === shader1.function)
        #expect(retrieved2?.function === shader2.function)
        #expect(retrieved1?.function !== retrieved2?.function)
    }

    @Test("Multiple shaders from different libraries")
    func multipleShadersFromDifferentLibraries() throws {
        let cache = ShaderCache()
        let library1 = try makeTestLibrary(source: Self.simpleComputeSource)
        let library2 = try makeTestLibrary(source: Self.simpleComputeSource)

        let shader1 = try makeTestShader(library: library1, name: "testKernel")
        let shader2 = try makeTestShader(library: library2, name: "testKernel")

        cache.set(library: library1, name: "testKernel", functionConstants: nil, shader: shader1)
        cache.set(library: library2, name: "testKernel", functionConstants: nil, shader: shader2)

        let retrieved1 = cache.get(library: library1, name: "testKernel", functionConstants: nil)
        let retrieved2 = cache.get(library: library2, name: "testKernel", functionConstants: nil)

        #expect(retrieved1?.function === shader1.function)
        #expect(retrieved2?.function === shader2.function)
    }

    // MARK: - Function Constants Tests

    @Test("Shader with nil function constants")
    func nilFunctionConstants() throws {
        let cache = ShaderCache()
        let library = try makeTestLibrary(source: Self.simpleComputeSource)
        let shader = try makeTestShader(library: library, name: "testKernel")

        cache.set(library: library, name: "testKernel", functionConstants: nil, shader: shader)

        let retrieved = cache.get(library: library, name: "testKernel", functionConstants: nil)
        #expect(retrieved?.function === shader.function)
    }

    @Test("Shader with non-nil function constants")
    func nonNilFunctionConstants() throws {
        let cache = ShaderCache()
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        constant bool useOptimization [[function_constant(0)]];

        kernel void testKernel(device float* output [[buffer(0)]]) {
            if (useOptimization) {
                output[0] = 1.0;
            } else {
                output[0] = 0.0;
            }
        }
        """

        let library = try makeTestLibrary(source: source)

        var constants1 = FunctionConstants()
        constants1["useOptimization"] = .bool(true)

        var constants2 = FunctionConstants()
        constants2["useOptimization"] = .bool(false)

        let shader1 = try library.function(named: "testKernel", type: ComputeKernel.self, constants: constants1)
        let shader2 = try library.function(named: "testKernel", type: ComputeKernel.self, constants: constants2)

        cache.set(library: library, name: "testKernel", functionConstants: constants1, shader: shader1)
        cache.set(library: library, name: "testKernel", functionConstants: constants2, shader: shader2)

        let retrieved1 = cache.get(library: library, name: "testKernel", functionConstants: constants1)
        let retrieved2 = cache.get(library: library, name: "testKernel", functionConstants: constants2)

        #expect(retrieved1?.function === shader1.function)
        #expect(retrieved2?.function === shader2.function)
        #expect(retrieved1?.function !== retrieved2?.function)
    }

    @Test("Different function constants create separate cache entries")
    func separateCacheEntriesForDifferentConstants() throws {
        let cache = ShaderCache()
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        constant int multiplier [[function_constant(0)]];

        kernel void testKernel(device float* output [[buffer(0)]]) {
            output[0] = float(multiplier);
        }
        """

        let library = try makeTestLibrary(source: source)

        var constants1 = FunctionConstants()
        constants1["multiplier"] = .int32(2)

        var constants2 = FunctionConstants()
        constants2["multiplier"] = .int32(4)

        let shader1 = try library.function(named: "testKernel", type: ComputeKernel.self, constants: constants1)
        let shader2 = try library.function(named: "testKernel", type: ComputeKernel.self, constants: constants2)

        cache.set(library: library, name: "testKernel", functionConstants: constants1, shader: shader1)
        cache.set(library: library, name: "testKernel", functionConstants: constants2, shader: shader2)

        // Both should be retrievable independently
        let retrieved1 = cache.get(library: library, name: "testKernel", functionConstants: constants1)
        let retrieved2 = cache.get(library: library, name: "testKernel", functionConstants: constants2)

        #expect(retrieved1?.function === shader1.function)
        #expect(retrieved2?.function === shader2.function)

        // Wrong constants should miss
        var wrongConstants = FunctionConstants()
        wrongConstants["multiplier"] = .int32(8)
        let missed = cache.get(library: library, name: "testKernel", functionConstants: wrongConstants)
        #expect(missed == nil)
    }

    // MARK: - Overwrite Tests

    @Test("Overwriting existing cache entry")
    func overwriteExistingEntry() throws {
        let cache = ShaderCache()
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        constant bool flag [[function_constant(0)]];

        kernel void testKernel(device float* output [[buffer(0)]]) {
            output[0] = flag ? 1.0 : 0.0;
        }
        """

        let library = try makeTestLibrary(source: source)

        // Create two different shaders with different function constants
        var constants1 = FunctionConstants()
        constants1["flag"] = .bool(true)

        var constants2 = FunctionConstants()
        constants2["flag"] = .bool(false)

        let shader1 = try library.function(named: "testKernel", type: ComputeKernel.self, constants: constants1)
        let shader2 = try library.function(named: "testKernel", type: ComputeKernel.self, constants: constants2)

        // Set first shader with constants1
        cache.set(library: library, name: "testKernel", functionConstants: constants1, shader: shader1)

        let retrieved1 = cache.get(library: library, name: "testKernel", functionConstants: constants1)
        #expect(retrieved1?.function === shader1.function)

        // Overwrite with second shader (still using constants1 as key)
        cache.set(library: library, name: "testKernel", functionConstants: constants1, shader: shader2)

        let retrieved2 = cache.get(library: library, name: "testKernel", functionConstants: constants1)
        #expect(retrieved2?.function === shader2.function)
    }

    // MARK: - Singleton Tests

    @Test("Shared singleton instance")
    func sharedSingleton() throws {
        let library = try makeTestLibrary(source: Self.simpleComputeSource)
        let shader = try makeTestShader(library: library, name: "testKernel")

        // Set using shared instance
        ShaderCache.shared.set(library: library, name: "testKernel", functionConstants: nil, shader: shader)

        // Get using shared instance
        let retrieved = ShaderCache.shared.get(library: library, name: "testKernel", functionConstants: nil)
        #expect(retrieved?.function === shader.function)
    }

    @Test("Shared instance is same across accesses")
    func sharedInstanceConsistency() {
        let instance1 = ShaderCache.shared
        let instance2 = ShaderCache.shared

        #expect(instance1 === instance2)
    }

    // MARK: - Edge Cases

    @Test("Empty name string")
    func emptyName() throws {
        let cache = ShaderCache()
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void testKernel(device float* output [[buffer(0)]]) {
            output[0] = 1.0;
        }
        """

        let library = try makeTestLibrary(source: source)
        let shader = try makeTestShader(library: library, name: "testKernel")

        // Cache should handle empty name string without crashing
        cache.set(library: library, name: "", functionConstants: nil, shader: shader)
        let retrieved = cache.get(library: library, name: "", functionConstants: nil)

        #expect(retrieved?.function === shader.function)
    }

    @Test("Empty function constants")
    func emptyFunctionConstants() throws {
        let cache = ShaderCache()
        let library = try makeTestLibrary(source: Self.simpleComputeSource)
        let shader = try makeTestShader(library: library, name: "testKernel")

        let emptyConstants = FunctionConstants()

        cache.set(library: library, name: "testKernel", functionConstants: emptyConstants, shader: shader)
        let retrieved = cache.get(library: library, name: "testKernel", functionConstants: emptyConstants)

        #expect(retrieved?.function === shader.function)
    }
}
