import Metal
import MetalSprocketsSupport

public struct Reflection {
    public struct Key: Hashable {
        public var functionType: MTLFunctionType
        public var name: String
    }

    private var bindings: [Key: Int] = [:]

    public func binding(forType functionType: MTLFunctionType, name: String) -> Int? {
        bindings[.init(functionType: functionType, name: name)]
    }
}

extension Reflection {
    init(_ renderPipelineReflection: MTLRenderPipelineReflection) {
        for binding in renderPipelineReflection.fragmentBindings {
            bindings[.init(functionType: .fragment, name: binding.name)] = binding.index
        }
        for binding in renderPipelineReflection.vertexBindings {
            bindings[.init(functionType: .vertex, name: binding.name)] = binding.index
        }
        for binding in renderPipelineReflection.objectBindings {
            bindings[.init(functionType: .object, name: binding.name)] = binding.index
        }
        for binding in renderPipelineReflection.meshBindings {
            bindings[.init(functionType: .mesh, name: binding.name)] = binding.index
        }
    }
}

internal extension MSEnvironmentValues {
    /// The reflection published by the enclosing pipeline during setup.
    ///
    /// `reflection` is an output slot: only ``RenderPipeline``, ``MeshRenderPipeline`` and
    /// ``ComputePipeline`` write it, and only from `setupEnter`. Anything that resolves named
    /// shader bindings must therefore be a *descendant* of one of those elements. Use this instead
    /// of reading `reflection` directly so the failure carries that explanation.
    ///
    /// - Parameter usage: How the caller is described to the user, e.g. `"parameter() modifiers"`.
    func requireReflection(for usage: String) throws -> Reflection {
        guard let reflection else {
            let hint = "\(usage) must be placed inside a RenderPipeline or ComputePipeline content block, not as a modifier on the pipeline itself."
            throw MetalSprocketsError.withHint(.missingEnvironment("reflection"), hint: hint)
        }
        return reflection
    }
}

extension Reflection {
    init(_ computePipelineReflection: MTLComputePipelineReflection) {
        for binding in computePipelineReflection.bindings {
            bindings[.init(functionType: .kernel, name: binding.name)] = binding.index
        }
    }
}

extension Reflection: CustomDebugStringConvertible {
    public var debugDescription: String {
        bindings.debugDescription
    }
}

extension Reflection.Key: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Key(type: .\(functionType) name: \"\(name)\")"
    }
}

extension MTLFunctionType: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .vertex:
            return "vertex"
        case .fragment:
            return "fragment"
        case .kernel:
            return "kernel"
        case .visible:
            return "visible"
        case .intersection:
            return "intersection"
        case .mesh:
            return "mesh"
        case .object:
            return "object"
        @unknown default:
            return "unknown"
        }
    }
}
