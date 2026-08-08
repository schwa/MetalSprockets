import Metal
import MetalSprocketsSupport

// MARK: - ShaderLoader

/// The port through which ``ShaderLibrary`` obtains `MTLFunction` values.
///
/// The shipping implementation is ``MetalShaderLoader``, which wraps an
/// `MTLLibrary` plus a ``ShaderCache``. Tests and hosts that want an isolated
/// or synthetic shader source can supply their own conformance.
public protocol ShaderLoader: Sendable {
    /// Identity of the underlying library, used to dedupe libraries in a ``ShaderStore``.
    var libraryID: ShaderLibrary.ID { get }

    /// Returns the (possibly cached) function named `name`, specialized with `constants`.
    ///
    /// - Parameters:
    ///   - name: The fully scoped function name, e.g. `MyNamespace::myFunction`.
    ///   - type: The expected function type; part of the cache key.
    ///   - constants: Function constants to specialize with.
    func function(named name: String, type: MTLFunctionType, constants: FunctionConstants) throws -> MTLFunction
}

// MARK: - MetalShaderLoader

/// The real ``ShaderLoader``: an `MTLLibrary` plus a cache of specialized functions.
public final class MetalShaderLoader: ShaderLoader, Sendable {
    /// The wrapped Metal library.
    public let library: MTLLibrary
    /// The cache of already-specialized functions.
    public let cache: ShaderCache
    public let libraryID: ShaderLibrary.ID

    /// Creates a loader over `library`, identified by `id`.
    public init(library: MTLLibrary, id: ShaderLibrary.ID) {
        self.library = library
        self.libraryID = id
        self.cache = ShaderCache()
    }

    public func function(named name: String, type: MTLFunctionType, constants: FunctionConstants) throws -> MTLFunction {
        if let cached = cache.get(scopedName: name, functionType: type, constants: constants) {
            return cached
        }
        let function: MTLFunction
        if constants.isEmpty {
            guard let basicFunction = library.makeFunction(name: name) else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function '\(name)' not found in library (available: \(library.functionNames))."))
            }
            function = basicFunction
        } else {
            // `buildMTLConstants` introspects the unspecialized function; `makeFunction` then applies the constants.
            let mtlConstants = try constants.buildMTLConstants(for: library, functionName: name)
            function = try library.makeFunction(name: name, constantValues: mtlConstants)
        }
        cache.set(scopedName: name, functionType: type, constants: constants, function: function)
        return function
    }
}
