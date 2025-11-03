import Metal
import MetalSprocketsSupport
internal import os

public final class ShaderCache: Sendable {
    private struct CacheKey: Hashable, Sendable {
        let scopedName: String
        let functionType: MTLFunctionType
        let constants: FunctionConstants

        func hash(into hasher: inout Hasher) {
            hasher.combine(scopedName)
            hasher.combine(functionType.rawValue)
            hasher.combine(constants)
        }
    }

    private let cache = OSAllocatedUnfairLock<[CacheKey: MTLFunction]>(initialState: [:])

    public init() {
        // Default initializer
    }

    func get(scopedName: String, functionType: MTLFunctionType, constants: FunctionConstants) -> MTLFunction? {
        let key = CacheKey(scopedName: scopedName, functionType: functionType, constants: constants)
        return cache.withLock { $0[key] }
    }

    func set(scopedName: String, functionType: MTLFunctionType, constants: FunctionConstants, function: MTLFunction) {
        let key = CacheKey(scopedName: scopedName, functionType: functionType, constants: constants)
        cache.withLock { $0[key] = function }
    }
}
