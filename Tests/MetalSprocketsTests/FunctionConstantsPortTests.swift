import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

/// A ``ShaderLoader`` that only knows about declared constants; function lookup is unsupported.
private struct StubConstantsLoader: ShaderLoader {
    var libraryID: ShaderLibrary.ID = .source("stub", nil)
    var declared: [String: FunctionConstantInfo]

    func function(named name: String, type: MTLFunctionType, constants: FunctionConstants) throws -> MTLFunction {
        try _throw(MetalSprocketsError.resourceCreationFailure("unsupported"))
    }

    func declaredConstants(forFunctionNamed name: String) throws -> [String: FunctionConstantInfo] {
        guard name == "kernelUnderTest" else {
            try _throw(MetalSprocketsError.configurationError("Function '\(name)' not found in library"))
        }
        return declared
    }
}

@Suite("Constant resolution through the ShaderLoader port")
struct FunctionConstantsPortTests {
    private func info(_ name: String, _ index: Int, _ type: MTLDataType = .int) -> FunctionConstantInfo {
        FunctionConstantInfo(name: name, index: index, dataType: type, required: true)
    }

    private func loader(_ declared: [String: FunctionConstantInfo]) -> StubConstantsLoader {
        StubConstantsLoader(declared: declared)
    }

    @Test("Exact and namespace-suffix names resolve without a live library")
    func testResolution() throws {
        let loader = loader([
            "useFeature": info("useFeature", 0, .bool),
            "MyNS::count": info("MyNS::count", 1)
        ])
        var constants = FunctionConstants()
        constants["useFeature"] = .bool(true)
        constants["count"] = .int32(3)
        _ = try loader.constantValues(forFunctionNamed: "kernelUnderTest", constants: constants)
    }

    @Test("Ambiguous namespaced constant throws")
    func testAmbiguous() throws {
        let loader = loader([
            "A::shared": info("A::shared", 0),
            "B::shared": info("B::shared", 1)
        ])
        var constants = FunctionConstants()
        constants["shared"] = .int32(1)
        #expect(throws: MetalSprocketsError.self) {
            _ = try loader.constantValues(forFunctionNamed: "kernelUnderTest", constants: constants)
        }
    }

    @Test("Unknown constant throws when the function declares others")
    func testUnknownConstant() throws {
        let loader = loader(["known": info("known", 0)])
        var constants = FunctionConstants()
        constants["unknown"] = .int32(1)
        #expect(throws: MetalSprocketsError.self) {
            _ = try loader.constantValues(forFunctionNamed: "kernelUnderTest", constants: constants)
        }
    }

    @Test("Function declaring no constants skips silently")
    func testNoDeclaredConstants() throws {
        let loader = loader([:])
        var constants = FunctionConstants()
        constants["ghost"] = .int32(1)
        _ = try loader.constantValues(forFunctionNamed: "kernelUnderTest", constants: constants)
    }

    @Test("Missing function throws")
    func testMissingFunction() throws {
        let loader = loader([:])
        #expect(throws: MetalSprocketsError.self) {
            _ = try loader.declaredConstants(forFunctionNamed: "nope")
        }
    }
}
