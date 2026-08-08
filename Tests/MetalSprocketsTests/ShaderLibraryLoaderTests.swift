import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import os
import Testing

/// Records lookups and always fails, so routing can be checked without a GPU.
private final class RecordingLoader: ShaderLoader {
    let libraryID: ShaderLibrary.ID
    let recorded = OSAllocatedUnfairLock<[String]>(initialState: [])

    init(id: ShaderLibrary.ID) {
        self.libraryID = id
    }

    func function(named name: String, type: MTLFunctionType, constants: FunctionConstants) throws -> MTLFunction {
        recorded.withLock { $0.append(name) }
        try _throw(MetalSprocketsError.resourceCreationFailure("no function '\(name)'"))
    }

    func declaredConstants(forFunctionNamed name: String) throws -> [String: FunctionConstantInfo] {
        [:]
    }
}

@Suite("ShaderLibrary backed by a custom loader")
struct ShaderLibraryLoaderTests {
    @Test("Library id comes from the loader")
    func testID() {
        let loader = RecordingLoader(id: .source("custom", nil))
        let library = ShaderLibrary(loader: loader)
        #expect(library.id == .source("custom", nil))
    }

    @Test("Lookups route through the loader, namespace included")
    func testRouting() {
        let loader = RecordingLoader(id: .source("custom", nil))
        let library = ShaderLibrary(loader: loader)
        #expect(throws: MetalSprocketsError.self) {
            _ = try library.function(type: VertexShader.self, named: "vs", namespace: "NS")
        }
        #expect(loader.recorded.withLock { $0 } == ["NS::vs"])
    }
}
