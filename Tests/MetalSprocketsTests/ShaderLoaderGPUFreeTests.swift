// The mock conforms to MTLFunction, whose requirements dictate optional collections and unimplementable members.
// swiftlint:disable discouraged_optional_collection unavailable_function
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import os
import Testing

/// A stand-in `MTLFunction` with no GPU behind it. Only identity, name and function type are meaningful; everything
/// else traps, because nothing under test should touch it.
private final class MockFunction: NSObject, MTLFunction {
    let name: String
    let functionType: MTLFunctionType
    nonisolated(unsafe) var label: String?

    init(name: String, functionType: MTLFunctionType) {
        self.name = name
        self.functionType = functionType
    }

    var device: MTLDevice { fatalError("unavailable") }
    var options: MTLFunctionOptions { [] }
    var patchType: MTLPatchType { .none }
    var patchControlPointCount: Int { -1 }
    var vertexAttributes: [MTLVertexAttribute]? { nil }
    var stageInputAttributes: [MTLAttribute]? { nil }
    var functionConstantsDictionary: [String: MTLFunctionConstant] { [:] }

    func makeArgumentEncoder(bufferIndex: Int) -> any MTLArgumentEncoder {
        fatalError("unavailable")
    }

    func makeArgumentEncoder(bufferIndex: Int, reflection: AutoreleasingUnsafeMutablePointer<MTLAutoreleasedArgument?>?) -> any MTLArgumentEncoder {
        fatalError("unavailable")
    }
}

/// A loader that manufactures `MockFunction`s, so cache and error paths can be exercised without a device.
private final class MockLoader: ShaderLoader {
    let libraryID: ShaderLibrary.ID = .source("mock", nil)
    /// Function names the loader knows about, and the type it reports for each.
    let known: [String: MTLFunctionType]
    private let state = OSAllocatedUnfairLock<(calls: Int, cache: [String: MockFunction])>(initialState: (0, [:]))

    init(known: [String: MTLFunctionType]) {
        self.known = known
    }

    var callCount: Int { state.withLock { $0.calls } }

    func function(named name: String, type: MTLFunctionType, constants: FunctionConstants) throws -> MTLFunction {
        guard let actualType = known[name] else {
            try _throw(MetalSprocketsError.resourceCreationFailure("Function '\(name)' not found in library (available: \(known.keys.sorted()))."))
        }
        return state.withLock { state in
            state.calls += 1
            if let cached = state.cache[name] {
                return cached
            }
            let function = MockFunction(name: name, functionType: actualType)
            state.cache[name] = function
            return function
        }
    }

    func declaredConstants(forFunctionNamed name: String) throws -> [String: FunctionConstantInfo] {
        [:]
    }
}

@Suite("GPU-free shader loading")
struct ShaderLoaderGPUFreeTests {
    @Test("Cache hit returns the same MTLFunction")
    func testCacheHitIdentity() throws {
        let cache = ShaderCache()
        let function = MockFunction(name: "vs", functionType: .vertex)
        let constants = FunctionConstants()
        #expect(cache.get(scopedName: "vs", functionType: .vertex, constants: constants) == nil)
        cache.set(scopedName: "vs", functionType: .vertex, constants: constants, function: function)
        let first = cache.get(scopedName: "vs", functionType: .vertex, constants: constants)
        let second = cache.get(scopedName: "vs", functionType: .vertex, constants: constants)
        #expect(first === function)
        #expect(second === function)
    }

    @Test("Cache keys distinguish function type and constants")
    func testCacheKeying() {
        let cache = ShaderCache()
        let function = MockFunction(name: "f", functionType: .vertex)
        cache.set(scopedName: "f", functionType: .vertex, constants: FunctionConstants(), function: function)
        #expect(cache.get(scopedName: "f", functionType: .fragment, constants: FunctionConstants()) == nil)
        var constants = FunctionConstants()
        constants["a"] = .bool(true)
        #expect(cache.get(scopedName: "f", functionType: .vertex, constants: constants) == nil)
    }

    @Test("Missing function surfaces the loader's diagnostic")
    func testMissingFunction() {
        let library = ShaderLibrary(loader: MockLoader(known: ["vs": .vertex]))
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: VertexShader.self, named: "nope")
        }
    }

    @Test("Type mismatch throws rather than wrapping the wrong shader type")
    func testTypeMismatch() {
        let library = ShaderLibrary(loader: MockLoader(known: ["vs": .vertex]))
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: FragmentShader.self, named: "vs")
        }
    }

    @Test("Namespaced lookup succeeds through the port")
    func testNamespacedLookup() throws {
        let loader = MockLoader(known: ["NS::vs": .vertex])
        let library = ShaderLibrary(loader: loader)
        let shader = try library.function(type: VertexShader.self, named: "vs", namespace: "NS")
        #expect(shader.function.name == "NS::vs")
        #expect(loader.callCount == 1)
    }
}
