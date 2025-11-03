import Metal
import MetalSprocketsSupport

@dynamicMemberLookup
public struct ShaderNamespace {
    let library: ShaderLibrary
    let namespace: String

    public init(library: ShaderLibrary, namespace: String) {
        self.library = library
        self.namespace = namespace
    }

    public func function<T>(named name: String, type: T.Type, constants: FunctionConstants = FunctionConstants()) throws -> T where T: ShaderProtocol {
        try library.function(type: type, named: name, namespace: namespace, constants: constants)
    }

    public func requiredFunction<T>(named name: String, type: T.Type, constants: FunctionConstants = FunctionConstants()) -> T where T: ShaderProtocol {
        library.requiredFunction(type: type, named: name, namespace: namespace, constants: constants)
    }
}

public extension ShaderNamespace {
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
