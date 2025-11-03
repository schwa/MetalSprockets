import Metal
import MetalSprocketsSupport

@dynamicMemberLookup
public struct ShaderLibrary: Sendable {
    var library: MTLLibrary
    var namespace: String?

    public init(library: MTLLibrary, namespace: String? = nil) {
        self.library = library
        self.namespace = namespace
    }

    public init(bundle: Bundle, namespace: String? = nil) throws {
        let device = _MTLCreateSystemDefaultDevice()

        if let url = bundle.url(forResource: "debug", withExtension: "metallib"), let library = try? device.makeLibrary(URL: url) {
            self.library = library
        }
        else {
            if let library = try? device.makeDefaultLibrary(bundle: bundle) {
                self.library = library
            }
            else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Failed to load default library from bundle."))
            }
        }
        self.namespace = namespace
    }

    public init(source: String, options: MTLCompileOptions? = nil, namespace: String? = nil) throws {
        let device = _MTLCreateSystemDefaultDevice()

        self.library = try device.makeLibrary(source: source, options: options)
        self.namespace = namespace
    }


    public func function<T>(named name: String, type: T.Type, constants: FunctionConstants = FunctionConstants()) throws -> T where T: ShaderProtocol {
        let scopedNamed = namespace.map { "\($0)::\(name)" } ?? name
        let cacheKey = constants.isEmpty ? nil : constants

        // Check cache first
        if let cached = ShaderCache.shared.get(library: self, name: scopedNamed, functionConstants: cacheKey) {
            if let result = cached as? T {
                logger?.verbose?.log("Loaded function '\(name)' from cache")
                return result
            }
            else {
                logger?.verbose?.log("Loading function '\(name)' (cache miss)")

            }
        }

        logger?.verbose?.log("Loading function '\(name)' from library \(library.label ?? "<unnamed>")")

        let function: MTLFunction

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

        let shader: ShaderProtocol
        switch type {
        // TODO: #86 Clean this up.
        case is VertexShader.Type:
            guard function.functionType == .vertex else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not a vertex function."))
            }
            shader = VertexShader(function)
        case is FragmentShader.Type:
            guard function.functionType == .fragment else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not a fragment function."))
            }
            shader = FragmentShader(function)
        case is ComputeKernel.Type:
            guard function.functionType == .kernel else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not a kernel function."))
            }
            shader = ComputeKernel(function)

        case is VisibleFunction.Type:
            guard function.functionType == .visible else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not a visible function."))
            }
            shader = VisibleFunction(function)
        case is ObjectShader.Type:
            guard function.functionType == .object else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not an object function."))
            }
            shader = ObjectShader(function)
        case is MeshShader.Type:
            guard function.functionType == .mesh else {
                try _throw(MetalSprocketsError.resourceCreationFailure("Function \(scopedNamed) is not a mesh function."))
            }
            shader = MeshShader(function)
        default:
            try _throw(MetalSprocketsError.resourceCreationFailure("Unknown shader type \(type)."))
        }

        // Store in cache before returning
        ShaderCache.shared.set(library: self, name: scopedNamed, functionConstants: cacheKey, shader: shader)

        return (shader as? T).orFatalError(.resourceCreationFailure("Failed to cast shader to \(type)."))
    }
}

extension ShaderLibrary: Equatable {
    public static func == (lhs: ShaderLibrary, rhs: ShaderLibrary) -> Bool {
        lhs.library === rhs.library && lhs.namespace == rhs.namespace
    }
}

extension ShaderLibrary: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(library))
        hasher.combine(namespace)
    }
}

public extension ShaderLibrary {
    subscript(dynamicMember name: String) -> ComputeKernel {
        get throws {
            try function(named: name, type: ComputeKernel.self)
        }
    }

    subscript(dynamicMember name: String) -> VertexShader {
        get throws {
            try function(named: name, type: VertexShader.self)
        }
    }

    subscript(dynamicMember name: String) -> FragmentShader {
        get throws {
            try function(named: name, type: FragmentShader.self)
        }
    }
}

// MARK:

