@preconcurrency import Metal
import MetalSprocketsSupport

// MARK: - ShaderLibrary

/// A type-safe wrapper around a Metal shader library.
///
/// `ShaderLibrary` provides convenient access to shader functions compiled from
/// `.metal` files. Use dynamic member lookup to access shaders by name.
///
/// ## Loading from Bundle
///
/// Load shaders compiled into your app bundle:
///
/// ```swift
/// let library = try ShaderLibrary(bundle: .main)
/// let vertexShader: VertexShader = library.myVertexFunction
/// let fragmentShader: FragmentShader = library.myFragmentFunction
/// ```
///
/// ## Loading from Source
///
/// Compile shaders from source at runtime (useful for prototyping):
///
/// ```swift
/// let source = """
/// #include <metal_stdlib>
/// using namespace metal;
///
/// vertex float4 vertexMain(uint id [[vertex_id]]) {
///     return float4(0, 0, 0, 1);
/// }
/// """
/// let library = try ShaderLibrary(source: source)
/// ```
///
/// ## Accessing Shaders
///
/// Use dynamic member lookup with type annotation to get the correct shader type:
///
/// ```swift
/// let vs: VertexShader = library.vertexMain
/// let fs: FragmentShader = library.fragmentMain
/// let kernel: ComputeKernel = library.computeMain
/// ```
///
/// ## Namespaced Functions
///
/// Access functions in C++ namespaces:
///
/// ```swift
/// let namespaced = library.namespaced("MyNamespace")
/// let shader: VertexShader = namespaced.myFunction
/// ```
///
/// ## Topics
///
/// ### Shader Types
/// - ``VertexShader``
/// - ``FragmentShader``
/// - ``ComputeKernel``
/// - ``MeshShader``
/// - ``ObjectShader``
@dynamicMemberLookup
public struct ShaderLibrary: Identifiable {
    public enum ID: Hashable, @unchecked Sendable {
        case bundle(Bundle)
        case library(MTLLibrary)
        case source(String, MTLCompileOptions?)
    }

    final class State: Sendable {
        let library: MTLLibrary
        let cache: ShaderCache
        let id: ShaderLibrary.ID

        init(library: MTLLibrary, id: ShaderLibrary.ID) {
            self.library = library
            self.id = id
            self.cache = ShaderCache()
        }
    }

    private let state: State
    public var id: ID { state.id }
    var library: MTLLibrary { state.library }
    var cache: ShaderCache { state.cache }
}

public extension ShaderLibrary {
    /// Creates a shader library from an existing Metal library.
    ///
    /// - Parameter library: The `MTLLibrary` to wrap.
    init(library: MTLLibrary) {
        let id = ID.library(library)
        self.state = LibraryRegistry.shared.getOrCreate(id: id) { library }
    }

    /// Creates a shader library from a bundle's compiled Metal library.
    ///
    /// This loads the `default.metallib` compiled from `.metal` files in the bundle.
    /// Falls back to a `debug.metallib` if present.
    ///
    /// - Parameter bundle: The bundle containing the compiled Metal library.
    /// - Throws: ``MetalSprocketsError/resourceCreationFailure(_:)`` if the library cannot be loaded.
    init(bundle: Bundle) throws {
        let id = ID.bundle(bundle)
        self.state = try LibraryRegistry.shared.getOrCreate(id: id) {
            let device = _MTLCreateSystemDefaultDevice()

            if let url = bundle.url(forResource: "debug", withExtension: "metallib"), let library = try? device.makeLibrary(URL: url) {
                return library
            }
            if let library = try? device.makeDefaultLibrary(bundle: bundle) {
                return library
            }
            try _throw(MetalSprocketsError.resourceCreationFailure("Failed to load default library from bundle."))
        }
    }

    /// Creates a shader library by compiling Metal source code at runtime.
    ///
    /// Use this for prototyping or dynamically generated shaders. For production,
    /// prefer pre-compiled `.metal` files loaded via ``init(bundle:)``.
    ///
    /// - Parameters:
    ///   - source: The Metal Shading Language source code to compile.
    ///   - options: Optional compile options.
    /// - Throws: An error if compilation fails.
    init(source: String, options: MTLCompileOptions? = nil) throws {
        let id = ID.source(source, options)
        self.state = try LibraryRegistry.shared.getOrCreate(id: id) {
            let device = _MTLCreateSystemDefaultDevice()
            return try device.makeLibrary(source: source, options: options)
        }
    }
}

public extension ShaderLibrary {
    func requiredFunction<T>(type: T.Type, named name: String, namespace: String? = nil, constants: FunctionConstants = FunctionConstants()) -> T where T: ShaderProtocol {
        do {
            return try function(type: type, named: name, namespace: namespace, constants: constants)

        }
        catch {
            fatalError("Failed to load required function '\(name)': \(error)")
        }
    }

    func function<T>(type: T.Type, named name: String, namespace: String? = nil, constants: FunctionConstants = FunctionConstants()) throws -> T where T: ShaderProtocol {
        let scopedNamed = namespace.map { "\($0)::\(name)" } ?? name
        let expectedType = T.functionType

        // Check cache first
        let function: MTLFunction
        if let cachedFunction = cache.get(scopedName: scopedNamed, functionType: expectedType, constants: constants) {
            function = cachedFunction
        } else {
            // Cache miss - load the function
            if !constants.isEmpty {
                // Build the constant values using the unspecialized function for introspection
                let mtlConstants = try constants.buildMTLConstants(for: library, functionName: scopedNamed)

                // Now create the SPECIALIZED function with the constants applied
                function = try library.makeFunction(name: scopedNamed, constantValues: mtlConstants)
            } else {
                // No constants, just get the function directly
                guard let basicFunction = library.makeFunction(name: scopedNamed) else {
                    try _throw(MetalSprocketsError.resourceCreationFailure("Function '\(scopedNamed)' not found in library (available: \(library.functionNames))."))
                }
                function = basicFunction
            }

            // Cache the loaded function
            cache.set(scopedName: scopedNamed, functionType: expectedType, constants: constants, function: function)
        }
        switch type {
        // TODO: #86 Clean this up.
        case is VertexShader.Type:
            guard function.functionType == .vertex else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not a vertex function."))
            }
            return (VertexShader(function) as? T).orFatalError(.resourceCreationFailure("Failed to create VertexShader."))
        case is FragmentShader.Type:
            guard function.functionType == .fragment else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not a fragment function."))
            }
            return (FragmentShader(function) as? T).orFatalError(.resourceCreationFailure("Failed to create FragmentShader."))
        case is ComputeKernel.Type:
            guard function.functionType == .kernel else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not a kernel function."))
            }
            return (ComputeKernel(function) as? T).orFatalError(.resourceCreationFailure("Failed to create ComputeKernel."))

        case is VisibleFunction.Type:
            guard function.functionType == .visible else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not a visible function."))
            }
            return (VisibleFunction(function) as? T).orFatalError(.resourceCreationFailure("Failed to create ComputeKernel."))
        case is ObjectShader.Type:
            guard function.functionType == .object else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not an object function."))
            }
            return (ObjectShader(function) as? T).orFatalError(.resourceCreationFailure("Failed to create ObjectShader."))
        case is MeshShader.Type:
            guard function.functionType == .mesh else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not a mesh function."))
            }
            return (MeshShader(function) as? T).orFatalError(.resourceCreationFailure("Failed to create MeshShader."))
        default:
            try _throw(MetalSprocketsError.resourceCreationFailure("Unknown shader type \(type)."))
        }
    }
}

public extension ShaderLibrary {
    subscript(dynamicMember name: String) -> ComputeKernel {
        get throws {
            try function(type: ComputeKernel.self, named: name, )
        }
    }

    subscript(dynamicMember name: String) -> VertexShader {
        get throws {
            try function(type: VertexShader.self, named: name, )
        }
    }

    subscript(dynamicMember name: String) -> FragmentShader {
        get throws {
            try function(type: FragmentShader.self, named: name, )
        }
    }

    func namespaced(_ name: String) -> ShaderNamespace {
        ShaderNamespace(library: self, namespace: name)
    }
}

// MARK: - ShaderLibrary.ID Extensions

public extension ShaderLibrary.ID {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .bundle(let bundle):
            hasher.combine("bundle")
            hasher.combine(bundle.bundleURL)
        case .library(let library):
            hasher.combine("library")
            hasher.combine(ObjectIdentifier(library))
        case .source(let source, _):
            hasher.combine("source")
            hasher.combine(source)
        }
    }

    static func == (lhs: ShaderLibrary.ID, rhs: ShaderLibrary.ID) -> Bool {
        switch (lhs, rhs) {
        case let (.bundle(lBundle), .bundle(rBundle)):
            return lBundle.bundleURL == rBundle.bundleURL
        case let (.library(lLibrary), .library(rLibrary)):
            return lLibrary === rLibrary
        case let (.source(lSource, _), .source(rSource, _)):
            return lSource == rSource
        default:
            return false
        }
    }
}
