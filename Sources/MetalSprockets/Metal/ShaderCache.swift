private import os
import Metal

internal final class ShaderCache: Sendable {
    static let shared = ShaderCache()

    typealias Key = Composite<ShaderLibrary, String, FunctionConstants?>
    typealias Value = ShaderProtocol

    private let shaders = OSAllocatedUnfairLock(initialState: [Key: Value]())

    func get(library: ShaderLibrary, name: String, functionConstants: FunctionConstants?) -> ShaderProtocol? {
        let key = Key(library, name, functionConstants)
        return shaders.withLock { $0[key] }
    }

    func set(library: ShaderLibrary, name: String, functionConstants: FunctionConstants?, shader: ShaderProtocol) {
        let key = Key(library, name, functionConstants)
        shaders.withLock { $0[key] = shader }
    }
}
