import Metal
import MetalSprocketsSupport

@dynamicMemberLookup
public struct ShaderLibrary {
    var library: MTLLibrary

    public init(library: MTLLibrary) {
        self.library = library
    }

    public init(bundle: Bundle) throws {
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
    }

    public init(source: String, options: MTLCompileOptions? = nil) throws {
        let device = _MTLCreateSystemDefaultDevice()

        self.library = try device.makeLibrary(source: source, options: options)
    }


    public func function<T>(named name: String, type: T.Type, namespace: String? = nil, constants: FunctionConstants = FunctionConstants()) throws -> T where T: ShaderProtocol {
        logger?.verbose?.log("Loading function '\(name)' from library \(library.label ?? "<unnamed>")")

        let scopedNamed = namespace.map { "\($0)::\(name)" } ?? name

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

    func namespaced(_ name: String) -> ShaderNamespace {
        ShaderNamespace(library: self, namespace: name)
    }
}
