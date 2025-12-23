import CoreGraphics
import Metal
import MetalSprocketsSupport
import simd

// TODO: #54 instead of being typed <T> we need an "AnyParameter" and this needs to take a dictionary of AnyParameters
internal struct ParameterElementModifier<Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var parameters: [String: Parameter]
    var content: Content

    internal init<T>(functionType: MTLFunctionType? = nil, name: String, value: ParameterValue<T>, content: Content) {
        self.parameters = [name: .init(name: name, functionType: functionType, value: value)]
        self.content = content
    }

    func workloadEnter(_ node: Node) throws {
        let reflection = try node.environmentValues.reflection.orThrow(.missingEnvironment(\.reflection))
        let renderCommandEncoder = node.environmentValues.renderCommandEncoder
        let computeCommandEncoder = node.environmentValues.computeCommandEncoder
        for parameter in parameters.values {
            switch (renderCommandEncoder, computeCommandEncoder) {
            case (.some(let renderCommandEncoder), nil):
                try parameter.set(on: renderCommandEncoder, reflection: reflection)
            case (nil, .some(let computeCommandEncoder)):
                try parameter.set(on: computeCommandEncoder, reflection: reflection)
            case (.some, .some):
                preconditionFailure("Trying to process \(self) with both a render command encoder and a compute command encoder.")
            default:
                preconditionFailure("Trying to process `\(self) without a command encoder.")
            }
        }
    }

    nonisolated func requiresSetup(comparedTo old: ParameterElementModifier<Content>) -> Bool {
        // Parameter values changing never requires setup - they're only used in workload phase
        false
    }
}

// MARK: -

internal struct Parameter {
    var name: String
    var functionType: MTLFunctionType?
    var value: AnyParameterValue

    init<T>(name: String, functionType: MTLFunctionType? = nil, value: ParameterValue<T>) {
        self.name = name
        self.functionType = functionType
        self.value = AnyParameterValue(value)
    }

    func set(on encoder: MTLRenderCommandEncoder, reflection: Reflection) throws {
        try encoder.withDebugGroup("MTLRenderCommandEncoder(\(encoder.label.quoted)): \(name.quoted) = \(value)") {
            switch functionType {
            case .vertex:
                if let index = reflection.binding(forType: .vertex, name: name) {
                    encoder.setValue(value, index: index, functionType: .vertex)
                }
            case .fragment:
                if let index = reflection.binding(forType: .fragment, name: name) {
                    encoder.setValue(value, index: index, functionType: .fragment)
                }
            case .object:
                if let index = reflection.binding(forType: .object, name: name) {
                    encoder.setValue(value, index: index, functionType: .object)
                }
            case .mesh:
                if let index = reflection.binding(forType: .mesh, name: name) {
                    encoder.setValue(value, index: index, functionType: .mesh)
                }
            case nil:
                let vertexIndex = reflection.binding(forType: .vertex, name: name)
                let fragmentIndex = reflection.binding(forType: .fragment, name: name)
                let objectIndex = reflection.binding(forType: .object, name: name)
                let meshIndex = reflection.binding(forType: .mesh, name: name)
                let indices = [(vertexIndex, "vertex", MTLFunctionType.vertex), (fragmentIndex, "fragment", MTLFunctionType.fragment), (objectIndex, "object", MTLFunctionType.object), (meshIndex, "mesh", MTLFunctionType.mesh)].compactMap { index, name, type in index.map { ($0, name, type) } }
                switch indices.count {
                case 0:
                    logger?.info("Parameter \(name) not found in reflection \(reflection.debugDescription).")
                    try _throw(MetalSprocketsError.missingBinding(name))
                case 1:
                    let (index, _, type) = indices[0]
                    encoder.setValue(value, index: index, functionType: type)
                default:
                    let descriptions = indices.map { "\($0.1) (index: #\($0.0))" }.joined(separator: ", ")
                    preconditionFailure("Ambiguous parameter, found parameter named \(name) in multiple shaders: \(descriptions).")
                }
            default:
                fatalError("Invalid shader type \(functionType.debugDescription).")
            }
        }
    }

    func set(on encoder: MTLComputeCommandEncoder, reflection: Reflection) throws {
        guard functionType == .kernel || functionType == nil else {
            try _throw(MetalSprocketsError.configurationError("Invalid function type \(functionType.debugDescription)."))
        }
        let index = try reflection.binding(forType: .kernel, name: name).orThrow(.missingBinding(name))
        encoder.setValue(value, index: index)
    }
}

// MARK: -

// MARK: - parameter Modifiers

/// Modifiers for binding values to shader parameters by name.
///
/// The `parameter` modifiers use reflection to automatically find the
/// correct buffer index for a named shader parameter. This eliminates
/// the need to manually track buffer indices.
///
/// ## Overview
///
/// Bind values to shader uniforms by name:
///
/// ```swift
/// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///     Draw { encoder in ... }
/// }
/// .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
/// .parameter("transform", value: modelViewProjection)
/// .parameter("diffuseTexture", texture: myTexture)
/// ```
///
/// ## Shader Side
///
/// In your Metal shader, parameters are bound to buffers:
///
/// ```metal
/// fragment float4 myFragment(
///     constant float4 &color [[buffer(0)]],
///     constant float4x4 &transform [[buffer(1)]],
///     texture2d<float> diffuseTexture [[texture(0)]]
/// ) { ... }
/// ```
///
/// ## Targeting Specific Stages
///
/// By default, parameters bind to whichever shader stage declares them.
/// Use `functionType` to explicitly target a stage:
///
/// ```swift
/// .parameter("time", functionType: .fragment, value: elapsedTime)
/// ```
public extension Element {
    /// Binds a SIMD4<Float> value to a shader parameter.
    func parameter(_ name: String, functionType: MTLFunctionType? = nil, value: SIMD4<Float>) -> some Element {
        ParameterElementModifier(functionType: functionType, name: name, value: .value(value), content: self)
    }

    /// Binds a 4x4 matrix to a shader parameter.
    func parameter(_ name: String, functionType: MTLFunctionType? = nil, value: simd_float4x4) -> some Element {
        ParameterElementModifier(functionType: functionType, name: name, value: .value(value), content: self)
    }

    /// Binds a texture to a shader parameter.
    func parameter(_ name: String, functionType: MTLFunctionType? = nil, texture: MTLTexture?) -> some Element {
        ParameterElementModifier(functionType: functionType, name: name, value: ParameterValue<()>.texture(texture), content: self)
    }

    /// Binds a sampler state to a shader parameter.
    func parameter(_ name: String, functionType: MTLFunctionType? = nil, samplerState: MTLSamplerState) -> some Element {
        ParameterElementModifier(functionType: functionType, name: name, value: ParameterValue<()>.samplerState(samplerState), content: self)
    }

    /// Binds a buffer to a shader parameter.
    func parameter(_ name: String, functionType: MTLFunctionType? = nil, buffer: MTLBuffer, offset: Int = 0) -> some Element {
        ParameterElementModifier(functionType: functionType, name: name, value: ParameterValue<()>.buffer(buffer, offset), content: self)
    }

    /// Binds an array of values to a shader parameter.
    func parameter(_ name: String, functionType: MTLFunctionType? = nil, values: [some Any]) -> some Element {
        assert(isPODArray(values), "Parameter values must be a POD type.")
        return ParameterElementModifier(functionType: functionType, name: name, value: .array(values), content: self)
    }

    /// Binds a value to a shader parameter.
    ///
    /// The value must be a plain-old-data (POD) type like Float, Int, SIMD types, or structs of POD types.
    func parameter(_ name: String, functionType: MTLFunctionType? = nil, value: some Any) -> some Element {
        assert(!isArray(value), "Use 'values:' parameter for arrays, not 'value:'.")
        assert(isPOD(value), "Parameter value must be a POD type.")
        return ParameterElementModifier(functionType: functionType, name: name, value: .value(value), content: self)
    }
}

extension String {
    var quoted: String {
        "\"\(self)\""
    }
}

extension Optional<String> {
    var quoted: String {
        switch self {
        case .none:
            return "nil"
        case .some(let string):
            return string.quoted
        }
    }
}
