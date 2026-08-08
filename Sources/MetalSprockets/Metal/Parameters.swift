import CoreGraphics
import Metal
import MetalSprocketsSupport
import MetalSupport
import simd

/// Collapses a chain of `.parameter()` modifiers into a single element, so binding N parameters costs one node
/// instead of N nested ones. See #54.
internal protocol ParameterCollecting {
    var parameters: [String: Parameter] { get }
    var parameterContent: any Element { get }
}

internal struct ParameterElementModifier<Content>: Element, WorkloadElement, BodylessContentElement, ParameterCollecting where Content: Element {
    var parameters: [String: Parameter]
    var content: Content

    internal init<T>(functionTypes: FunctionTypes = [], name: String, value: ParameterValue<T>, content: Content) {
        self.parameters = [name: .init(name: name, functionTypes: functionTypes, value: value)]
        self.content = content
    }

    var parameterContent: any Element {
        content
    }

    /// The parameters of this modifier plus every directly-nested one, and the first content element that isn't a
    /// parameter modifier. A binding closer to the content wins, matching the order nested modifiers would have
    /// encoded in.
    internal var collapsed: (parameters: [String: Parameter], content: any Element) {
        var merged = parameters
        var innermost: any Element = content
        while let next = innermost as? any ParameterCollecting {
            merged.merge(next.parameters) { _, nested in nested }
            innermost = next.parameterContent
        }
        return (merged, innermost)
    }

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(collapsed.content)
    }

    func workloadEnter(_ node: Node) throws {
        let reflection = try node.environmentValues.requireReflection(for: "parameter() modifiers")
        let renderCommandEncoder = node.environmentValues.renderCommandEncoder
        let computeCommandEncoder = node.environmentValues.computeCommandEncoder
        for parameter in collapsed.parameters.values {
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
    /// The stages to bind to. Empty means "work it out from reflection".
    var functionTypes: FunctionTypes
    var value: AnyParameterValue

    init<T>(name: String, functionTypes: FunctionTypes = [], value: ParameterValue<T>) {
        self.name = name
        self.functionTypes = functionTypes
        self.value = AnyParameterValue(value)
    }

    /// The render stages a parameter can be bound to, in the order reflection is searched.
    private static let renderStages: FunctionTypes = [.object, .mesh, .vertex, .fragment]

    func set(on encoder: MTLRenderCommandEncoder, reflection: Reflection) throws {
        try encoder.withDebugGroup("MTLRenderCommandEncoder(\(encoder.label.quoted)): \(name.quoted) = \(value)") {
            guard functionTypes.isEmpty else {
                let invalid = functionTypes.subtracting(Self.renderStages)
                guard invalid.isEmpty else {
                    try _throw(MetalSprocketsError.configurationError("Invalid function types \(invalid) for a render command encoder."))
                }
                for functionType in functionTypes.functionTypes {
                    if let index = reflection.binding(forType: functionType, name: name) {
                        encoder.setValue(value, index: index, functionType: functionType)
                    }
                }
                return
            }
            let indices = Self.renderStages.functionTypes.compactMap { functionType in
                reflection.binding(forType: functionType, name: name).map { (index: $0, functionType: functionType) }
            }
            switch indices.count {
            case 0:
                logger?.info("Parameter \(name) not found in reflection \(reflection.debugDescription).")
                try _throw(MetalSprocketsError.missingBinding(name))
            case 1:
                encoder.setValue(value, index: indices[0].index, functionType: indices[0].functionType)
            default:
                let descriptions = indices.map { "\($0.functionType) (index: #\($0.index))" }.joined(separator: ", ")
                preconditionFailure("Ambiguous parameter, found parameter named \(name) in multiple shaders: \(descriptions).")
            }
        }
    }

    func set(on encoder: MTLComputeCommandEncoder, reflection: Reflection) throws {
        guard functionTypes.isEmpty || functionTypes == .kernel else {
            try _throw(MetalSprocketsError.configurationError("Invalid function types \(functionTypes) for a compute command encoder."))
        }
        let index = try reflection.binding(forType: .kernel, name: name).orThrow(.missingBinding(name))
        encoder.setValue(value, index: index)
    }
}

// MARK: -

// MARK: - parameter Modifiers

/// Modifiers for binding values to shader parameters by name.
///
/// The `parameter` modifiers use Metal shader reflection to automatically find
/// the correct buffer index for a named shader parameter. This is a key feature
/// of MetalSprockets — it eliminates the need to manually track buffer indices
/// and keeps your Swift code in sync with your Metal shaders.
///
/// When both vertex and fragment shaders declare a parameter with the same name,
/// MetalSprockets will raise an error at runtime. Use the `functionType` parameter
/// to explicitly specify which shader stage should receive the value.
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
/// In your Metal shader, parameters are bound to buffers. The names must match
/// exactly between Swift and Metal:
///
/// ```metal
/// // Swift: .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
/// // Swift: .parameter("transform", value: modelViewProjection)
/// // Swift: .parameter("diffuseTexture", texture: myTexture)
///
/// fragment float4 myFragment(
///     constant float4 &color [[buffer(0)]],        // Matches "color"
///     constant float4x4 &transform [[buffer(1)]], // Matches "transform"
///     texture2d<float> diffuseTexture [[texture(0)]] // Matches "diffuseTexture"
/// ) { ... }
/// ```
///
/// ## Targeting Specific Stages
///
/// By default, parameters bind to whichever shader stage declares them.
/// Use `functionType` to explicitly target a stage, or `functionTypes` to target several at once:
///
/// ```swift
/// .parameter("time", functionType: .fragment, value: elapsedTime)
/// .parameter("uniforms", functionTypes: [.vertex, .fragment], value: uniforms)
/// ```
public extension Element {
    /// Binds a SIMD4<Float> value to a shader parameter.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], value: SIMD4<Float>) -> some Element {
        ParameterElementModifier(functionTypes: functionTypes, name: name, value: .value(value), content: self)
    }

    /// Binds a 4x4 matrix to a shader parameter.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], value: simd_float4x4) -> some Element {
        ParameterElementModifier(functionTypes: functionTypes, name: name, value: .value(value), content: self)
    }

    /// Binds a texture to a shader parameter.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], texture: MTLTexture?) -> some Element {
        ParameterElementModifier(functionTypes: functionTypes, name: name, value: ParameterValue<()>.texture(texture), content: self)
    }

    /// Binds a sampler state to a shader parameter.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], samplerState: MTLSamplerState) -> some Element {
        ParameterElementModifier(functionTypes: functionTypes, name: name, value: ParameterValue<()>.samplerState(samplerState), content: self)
    }

    /// Binds a buffer to a shader parameter.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], buffer: MTLBuffer, offset: Int = 0) -> some Element {
        ParameterElementModifier(functionTypes: functionTypes, name: name, value: ParameterValue<()>.buffer(buffer, offset), content: self)
    }

    /// Binds an array of values to a shader parameter.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], values: [some Any]) -> some Element {
        assert(_isPOD(type(of: values).Element.self), "Parameter values must be a POD type.")
        return ParameterElementModifier(functionTypes: functionTypes, name: name, value: .array(values), content: self)
    }

    /// Binds a value to a shader parameter.
    ///
    /// The value must be a plain-old-data type Metal can memcpy: `Float`, `Int`, SIMD types
    /// (`SIMD2<Float>`, `SIMD4<Float>`, etc.), matrices (`simd_float4x4`), and structs composed entirely of these.
    /// Use `values:` for arrays.
    ///
    /// > Important: The Swift type's memory layout must match the corresponding Metal type.
    /// Use `MemoryLayout<T>.stride` to verify sizes match your shader expectations.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], value: some Any) -> some Element {
        assert(Mirror(reflecting: value).displayStyle != .collection, "Use 'values:' parameter for arrays, not 'value:'.")
        assert(_isPOD(type(of: value)), "Parameter value must be a POD type.")
        return ParameterElementModifier(functionTypes: functionTypes, name: name, value: .value(value), content: self)
    }
}

// MARK: - Single-stage conveniences

public extension Element {
    /// Binds a SIMD4<Float> value to a shader parameter in one stage.
    func parameter(_ name: String, functionType: MTLFunctionType?, value: SIMD4<Float>) -> some Element {
        parameter(name, functionTypes: .init(functionType), value: value)
    }

    /// Binds a 4x4 matrix to a shader parameter in one stage.
    func parameter(_ name: String, functionType: MTLFunctionType?, value: simd_float4x4) -> some Element {
        parameter(name, functionTypes: .init(functionType), value: value)
    }

    /// Binds a texture to a shader parameter in one stage.
    func parameter(_ name: String, functionType: MTLFunctionType?, texture: MTLTexture?) -> some Element {
        parameter(name, functionTypes: .init(functionType), texture: texture)
    }

    /// Binds a sampler state to a shader parameter in one stage.
    func parameter(_ name: String, functionType: MTLFunctionType?, samplerState: MTLSamplerState) -> some Element {
        parameter(name, functionTypes: .init(functionType), samplerState: samplerState)
    }

    /// Binds a buffer to a shader parameter in one stage.
    func parameter(_ name: String, functionType: MTLFunctionType?, buffer: MTLBuffer, offset: Int = 0) -> some Element {
        parameter(name, functionTypes: .init(functionType), buffer: buffer, offset: offset)
    }

    /// Binds an array of values to a shader parameter in one stage.
    func parameter(_ name: String, functionType: MTLFunctionType?, values: [some Any]) -> some Element {
        parameter(name, functionTypes: .init(functionType), values: values)
    }

    /// Binds a value to a shader parameter in one stage.
    func parameter(_ name: String, functionType: MTLFunctionType?, value: some Any) -> some Element {
        parameter(name, functionTypes: .init(functionType), value: value)
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
