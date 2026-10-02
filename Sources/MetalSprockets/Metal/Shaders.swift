import Metal
import MetalSprocketsSupport
import MetalSupport

// MARK: - ShaderProtocol

/// A protocol for types that wrap Metal shader functions.
///
/// All shader types (``VertexShader``, ``FragmentShader``, ``ComputeKernel``, etc.)
/// conform to this protocol, providing a common interface for shader access.
///
/// ## Loading Shaders
///
/// The preferred way to load shaders is through ``ShaderLibrary``:
///
/// ```swift
/// let library = try ShaderLibrary(bundle: .main)
/// let vertexShader: VertexShader = library.myVertexFunction
/// let fragmentShader: FragmentShader = library.myFragmentFunction
/// ```
///
/// ## Topics
///
/// ### Shader Types
/// - ``VertexShader``
/// - ``FragmentShader``
/// - ``ComputeKernel``
/// - ``ObjectShader``
/// - ``MeshShader``
/// - ``VisibleFunction``
public protocol ShaderProtocol: Equatable {
    /// The Metal function type this shader represents.
    static var functionType: MTLFunctionType { get }

    /// The underlying Metal function.
    var function: MTLFunction { get }

    var reference: ShaderFunction { get }

    /// Creates a shader from a function with explicit library provenance.
    init(_ reference: ShaderFunction) throws
}

public extension ShaderProtocol {
    var function: MTLFunction { reference.metalFunction }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.reference == rhs.reference
    }

    /// Compiles a shader from Metal source.
    ///
    /// - Parameter device: The device to compile on. Defaults to the system default device, which is only the right
    ///   choice when the renderer uses that device too (see #55).
    init(source: String, logging: Bool = false, device: MTLDevice? = nil) throws {
        let device = device ?? _MTLCreateSystemDefaultDevice()
        let options = MTLCompileOptions()
        options.enableLogging = logging
        let library = try device.makeLibrary(source: source, options: options)
        let function = try library.functionNames.compactMap { library.makeFunction(name: $0) }.first { $0.functionType == Self.functionType }.orThrow(.resourceCreationFailure("Failed to create function"))
        try self.init(ShaderFunction(library: library, name: function.name, type: Self.functionType))
    }

    /// Looks a shader up by name.
    ///
    /// - Parameters:
    ///   - library: The library to search. When `nil`, `device`'s default library is used.
    ///   - device: The device whose default library is searched. Defaults to the system default device, which is only
    ///     the right choice when the renderer uses that device too (see #55).
    init(library: MTLLibrary? = nil, name: String, constants: FunctionConstants = FunctionConstants(), specializedName: String? = nil, device: MTLDevice? = nil) throws {
        let library = try library ?? (device ?? _MTLCreateSystemDefaultDevice()).makeDefaultLibrary().orThrow(.resourceCreationFailure("Failed to create default library"))
        if let device, library.device !== device {
            throw MetalSprocketsError.configurationError("Shader library and requested device do not match")
        }
        try self.init(ShaderFunction(library: library, name: name, type: Self.functionType, constants: constants, specializedName: specializedName))
    }
}

// MARK: - ComputeKernel

/// A compute shader (kernel) function for GPGPU workloads.
///
/// Use with ``ComputePipeline`` inside a ``ComputePass``:
///
/// ```swift
/// let kernel: ComputeKernel = library.myComputeKernel
///
/// ComputePass {
///     ComputePipeline(computeKernel: kernel) {
///         ComputeDispatch { encoder, state in
///             // Dispatch compute work
///         }
///     }
/// }
/// ```
public struct ComputeKernel: ShaderProtocol {
    public static let functionType: MTLFunctionType = .kernel
    public let reference: ShaderFunction

    public init(_ reference: ShaderFunction) throws {
        try reference.validate(type: Self.functionType)
        self.reference = reference
    }
}

// MARK: - VertexShader

/// A vertex shader function that processes vertices in a render pipeline.
///
/// Vertex shaders transform vertex positions and pass data to fragment shaders.
/// Use with ``RenderPipeline``:
///
/// ```swift
/// let vertexShader: VertexShader = library.myVertexShader
///
/// RenderPipeline(vertexShader: vertexShader, fragmentShader: fs) {
///     Draw { encoder in ... }
/// }
/// ```
public struct VertexShader: ShaderProtocol {
    public static let functionType: MTLFunctionType = .vertex
    public let reference: ShaderFunction

    public init(_ reference: ShaderFunction) throws {
        try reference.validate(type: Self.functionType)
        self.reference = reference
    }
}

// MARK: - FragmentShader

/// A fragment shader function that computes pixel colors.
///
/// Fragment shaders run once per pixel to determine the final color.
/// Use with ``RenderPipeline``:
///
/// ```swift
/// let fragmentShader: FragmentShader = library.myFragmentShader
///
/// RenderPipeline(vertexShader: vs, fragmentShader: fragmentShader) {
///     Draw { encoder in ... }
/// }
/// ```
public struct FragmentShader: ShaderProtocol {
    public static let functionType: MTLFunctionType = .fragment
    public let reference: ShaderFunction

    public init(_ reference: ShaderFunction) throws {
        try reference.validate(type: Self.functionType)
        self.reference = reference
    }
}

// MARK: - ObjectShader

/// An object shader function for mesh shader pipelines.
///
/// Object shaders generate per-object data that mesh shaders consume.
/// Use with ``MeshRenderPipeline`` for GPU-driven geometry generation.
///
/// ```swift
/// let objectShader: ObjectShader = library.myObjectShader
/// let meshShader: MeshShader = library.myMeshShader
///
/// MeshRenderPipeline(objectShader: objectShader, meshShader: meshShader, fragmentShader: fs) {
///     // Mesh draw commands
/// }
/// ```
public struct ObjectShader: ShaderProtocol {
    public static let functionType: MTLFunctionType = .object
    public let reference: ShaderFunction

    public init(_ reference: ShaderFunction) throws {
        try reference.validate(type: Self.functionType)
        self.reference = reference
    }
}

// MARK: - MeshShader

/// A mesh shader function for GPU-driven geometry generation.
///
/// Mesh shaders generate vertices and primitives directly on the GPU,
/// replacing the traditional vertex shader stage. Use with ``MeshRenderPipeline``.
///
/// ```swift
/// let meshShader: MeshShader = library.myMeshShader
///
/// MeshRenderPipeline(meshShader: meshShader, fragmentShader: fs) {
///     // Mesh draw commands
/// }
/// ```
public struct MeshShader: ShaderProtocol {
    public static let functionType: MTLFunctionType = .mesh
    public let reference: ShaderFunction

    public init(_ reference: ShaderFunction) throws {
        try reference.validate(type: Self.functionType)
        self.reference = reference
    }
}

// MARK: - VisibleFunction

/// A visible function that can be called from other shaders.
///
/// Visible functions enable dynamic function calls from shaders,
/// useful for ray tracing intersection functions, callable shaders,
/// and mesh shader pipelines.
///
/// - Note: TODO - Not really a "Shader". Sounds like we have a grand renaming coming.
public struct VisibleFunction: ShaderProtocol {
    public static let functionType: MTLFunctionType = .visible
    public let reference: ShaderFunction

    public init(_ reference: ShaderFunction) throws {
        try reference.validate(type: Self.functionType)
        self.reference = reference
    }
}
