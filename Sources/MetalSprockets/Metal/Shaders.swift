import Metal
import MetalSprocketsSupport

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
    
    /// Creates a shader from a Metal function.
    init(_ function: MTLFunction)
}

public extension ShaderProtocol {
    init(source: String, logging: Bool = false) throws {
        let device = _MTLCreateSystemDefaultDevice()
        let options = MTLCompileOptions()
        options.enableLogging = logging
        let library = try device.makeLibrary(source: source, options: options)
        let function = try library.functionNames.compactMap { library.makeFunction(name: $0) }.first { $0.functionType == Self.functionType }.orThrow(.resourceCreationFailure("Failed to create function"))
        self.init(function)
    }

    init(library: MTLLibrary? = nil, name: String) throws {
        let library = try library ?? _MTLCreateSystemDefaultDevice().makeDefaultLibrary().orThrow(.resourceCreationFailure("Failed to create default library"))
        let function = try library.makeFunction(name: name).orThrow(.resourceCreationFailure("Failed to create function"))
        if function.functionType != .kernel {
            try _throw(MetalSprocketsError.resourceCreationFailure("Function type is not kernel"))
        }
        self.init(function)
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
    public var function: MTLFunction

    public init(_ function: MTLFunction) {
        self.function = function
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.function === rhs.function
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
    public var function: MTLFunction

    public init(_ function: MTLFunction) {
        self.function = function
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.function === rhs.function
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
    public var function: MTLFunction

    public init(_ function: MTLFunction) {
        self.function = function
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.function === rhs.function
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
    public var function: MTLFunction

    public init(_ function: MTLFunction) {
        self.function = function
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.function === rhs.function
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
    public var function: MTLFunction

    public init(_ function: MTLFunction) {
        self.function = function
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.function === rhs.function
    }
}

// MARK: - VisibleFunction

/// A visible function that can be called from other shaders.
///
/// Visible functions enable dynamic function calls from shaders,
/// useful for ray tracing intersection functions, callable shaders,
/// and mesh shader pipelines.
// TODO: Not really a "Shader". Sounds like we have a grand renaming coming. [FILE ISSUE]
public struct VisibleFunction: ShaderProtocol {
    public static let functionType: MTLFunctionType = .visible
    public var function: MTLFunction

    public init(_ function: MTLFunction) {
        self.function = function
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.function === rhs.function
    }
}
