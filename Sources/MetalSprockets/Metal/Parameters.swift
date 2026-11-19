import CoreGraphics
import Metal
import MetalSprocketsSupport
import simd

// MARK: - parameter Modifiers
//
// Parameters are resolved by name against the enclosing pipeline's reflection and written into fresh, zero-initialized
// Metal 4 argument tables for every draw or dispatch. Inner modifiers override outer ones; siblings never see them.
//
// An empty stage filter binds every stage that declares the name. Values are copied into per-submission scratch
// storage, so they must be `BitwiseCopyable`.

public extension Element {
    func parameter(_ name: String, functionTypes: FunctionTypes = [], value: SIMD4<Float>) -> ParameterModifier<Self> {
        ParameterModifier(content: self) { $0.set(name, value: value, stages: functionTypes) }
    }

    func parameter(_ name: String, functionTypes: FunctionTypes = [], value: simd_float4x4) -> ParameterModifier<Self> {
        ParameterModifier(content: self) { $0.set(name, value: value, stages: functionTypes) }
    }

    /// Binds a texture. `nil` clears the slot.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], texture: MTLTexture?) -> ParameterModifier<Self> {
        ParameterModifier(content: self) { $0.set(name, texture: texture, stages: functionTypes) }
    }

    /// Binds an array texture argument (`array<texture2d<...>, N>`) by name, filling consecutive slots.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], textures: [MTLTexture]) -> ParameterModifier<Self> {
        ParameterModifier(content: self) { $0.set(name, textures: textures, stages: functionTypes) }
    }

    /// Binds a sampler. Metal 4 binds samplers by resource ID, so create it with `supportArgumentBuffers = true`.
    /// `nil` skips the binding, so the shader need not declare it.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], samplerState: MTLSamplerState?) -> ParameterModifier<Self> {
        ParameterModifier(content: self) { parameters in
            if let samplerState {
                parameters.set(name, sampler: samplerState, stages: functionTypes)
            }
        }
    }

    /// `nil` skips the binding, so the shader need not declare it.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], buffer: MTLBuffer?, offset: Int = 0) -> ParameterModifier<Self> {
        ParameterModifier(content: self) { parameters in
            if let buffer {
                parameters.set(name, buffer: buffer, offset: offset, stages: functionTypes)
            }
        }
    }

    /// Binds an argument buffer to a `constant Struct &` or `constant Struct *` parameter with one address, and keeps it
    /// and the resources its fields point to resident for the submission.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], argumentBuffer: ArgumentBuffer) -> ParameterModifier<Self> {
        ParameterModifier(content: self) { $0.set(name, argumentBuffer: argumentBuffer, stages: functionTypes) }
    }

    /// Binds an instance or primitive acceleration structure and keeps it resident for the submission. `nil` skips the
    /// binding, so the shader need not declare it.
    func parameter(_ name: String, functionTypes: FunctionTypes = [], accelerationStructure: (any MTLAccelerationStructure)?) -> ParameterModifier<Self> {
        ParameterModifier(content: self) { parameters in
            if let accelerationStructure {
                parameters.set(name, accelerationStructure: accelerationStructure, stages: functionTypes)
            }
        }
    }

    /// Binds an array of values to a shader parameter.
    ///
    /// The element type must be a plain-old-data type Metal can memcpy. This is checked at runtime because C/Metal
    /// header structs imported through a clang module cannot statically declare `BitwiseCopyable` conformance.
    func parameter<Value>(_ name: String, functionTypes: FunctionTypes = [], values: [Value]) -> ParameterModifier<Self> {
        assert(_isPOD(Value.self), "Parameter values must be a POD type.")
        return ParameterModifier(content: self) { $0.set(name, values: values, stages: functionTypes) }
    }

    /// Binds a value to a shader parameter.
    ///
    /// The value must be a plain-old-data type Metal can memcpy: `Float`, `Int`, SIMD types (`SIMD4<Float>`, etc.),
    /// matrices (`simd_float4x4`), and structs composed entirely of these. Use `values:` for arrays.
    ///
    /// POD-ness is checked at runtime because C/Metal header structs imported through a clang module cannot statically
    /// declare `BitwiseCopyable` conformance.
    func parameter<Value>(_ name: String, functionTypes: FunctionTypes = [], value: Value) -> ParameterModifier<Self> {
        assert(_isPOD(Value.self), "Parameter value must be a POD type.")
        return ParameterModifier(content: self) { $0.set(name, value: value, stages: functionTypes) }
    }
}

// MARK: - Several parameters in one modifier

/// Shader parameters collected for ``Element/parameters(_:)``. Each `set` matches the `.parameter` overload with the
/// same labels. A later call overrides an earlier call with the same name.
public struct ShaderParameters {
    internal var parameterSet = ParameterSet()

    public mutating func set(_ name: String, functionTypes: FunctionTypes = [], texture: MTLTexture?) {
        parameterSet.set(name, texture: texture, stages: functionTypes)
    }

    public mutating func set(_ name: String, functionTypes: FunctionTypes = [], textures: [MTLTexture]) {
        parameterSet.set(name, textures: textures, stages: functionTypes)
    }

    public mutating func set(_ name: String, functionTypes: FunctionTypes = [], samplerState: MTLSamplerState?) {
        if let samplerState {
            parameterSet.set(name, sampler: samplerState, stages: functionTypes)
        }
    }

    public mutating func set(_ name: String, functionTypes: FunctionTypes = [], buffer: MTLBuffer?, offset: Int = 0) {
        if let buffer {
            parameterSet.set(name, buffer: buffer, offset: offset, stages: functionTypes)
        }
    }

    public mutating func set(_ name: String, functionTypes: FunctionTypes = [], argumentBuffer: ArgumentBuffer) {
        parameterSet.set(name, argumentBuffer: argumentBuffer, stages: functionTypes)
    }

    public mutating func set(_ name: String, functionTypes: FunctionTypes = [], accelerationStructure: (any MTLAccelerationStructure)?) {
        if let accelerationStructure {
            parameterSet.set(name, accelerationStructure: accelerationStructure, stages: functionTypes)
        }
    }

    public mutating func set<Value>(_ name: String, functionTypes: FunctionTypes = [], values: [Value]) {
        assert(_isPOD(Value.self), "Parameter values must be a POD type.")
        parameterSet.set(name, values: values, stages: functionTypes)
    }

    public mutating func set<Value>(_ name: String, functionTypes: FunctionTypes = [], value: Value) {
        assert(_isPOD(Value.self), "Parameter value must be a POD type.")
        parameterSet.set(name, value: value, stages: functionTypes)
    }
}

public extension Element {
    /// Binds several shader parameters with one modifier instead of a chain of `.parameter` calls.
    ///
    /// ```swift
    /// Draw { ... }
    ///     .parameters { parameters in
    ///         parameters.set("baseColor", texture: baseColor)
    ///         parameters.set("baseColorSampler", samplerState: sampler)
    ///         parameters.set("material", value: material)
    ///     }
    /// ```
    func parameters(_ build: (inout ShaderParameters) -> Void) -> ParameterModifier<Self> {
        var parameters = ShaderParameters()
        build(&parameters)
        let parameterSet = parameters.parameterSet
        return ParameterModifier(content: self) { $0.append(contentsOf: parameterSet) }
    }
}

// MARK: - Single-stage conveniences

public extension Element {
    func parameter(_ name: String, functionType: MTLFunctionType?, value: SIMD4<Float>) -> ParameterModifier<Self> {
        parameter(name, functionTypes: .init(functionType), value: value)
    }

    func parameter(_ name: String, functionType: MTLFunctionType?, value: simd_float4x4) -> ParameterModifier<Self> {
        parameter(name, functionTypes: .init(functionType), value: value)
    }

    func parameter(_ name: String, functionType: MTLFunctionType?, texture: MTLTexture?) -> ParameterModifier<Self> {
        parameter(name, functionTypes: .init(functionType), texture: texture)
    }

    func parameter(_ name: String, functionType: MTLFunctionType?, textures: [MTLTexture]) -> ParameterModifier<Self> {
        parameter(name, functionTypes: .init(functionType), textures: textures)
    }

    func parameter(_ name: String, functionType: MTLFunctionType?, samplerState: MTLSamplerState?) -> ParameterModifier<Self> {
        parameter(name, functionTypes: .init(functionType), samplerState: samplerState)
    }

    func parameter(_ name: String, functionType: MTLFunctionType?, buffer: MTLBuffer?, offset: Int = 0) -> ParameterModifier<Self> {
        parameter(name, functionTypes: .init(functionType), buffer: buffer, offset: offset)
    }

    func parameter(_ name: String, functionType: MTLFunctionType?, argumentBuffer: ArgumentBuffer) -> ParameterModifier<Self> {
        parameter(name, functionTypes: .init(functionType), argumentBuffer: argumentBuffer)
    }

    func parameter(_ name: String, functionType: MTLFunctionType?, accelerationStructure: (any MTLAccelerationStructure)?) -> ParameterModifier<Self> {
        parameter(name, functionTypes: .init(functionType), accelerationStructure: accelerationStructure)
    }

    func parameter<Value>(_ name: String, functionType: MTLFunctionType?, values: [Value]) -> ParameterModifier<Self> {
        parameter(name, functionTypes: .init(functionType), values: values)
    }

    func parameter<Value>(_ name: String, functionType: MTLFunctionType?, value: Value) -> ParameterModifier<Self> {
        parameter(name, functionTypes: .init(functionType), value: value)
    }
}

// MARK: - Vertex inputs

public extension Element {
    /// Binds a `[[stage_in]]` vertex buffer to the given vertex-descriptor layout (buffer) index.
    ///
    /// Replaces `setVertexBuffer(_:offset:index:)` inside `Draw` closures on Metal 4.
    func vertexBuffer(_ buffer: MTLBuffer, index: Int, offset: Int = 0) -> ParameterModifier<Self> {
        ParameterModifier(content: self) { $0.setVertexBuffer(buffer, layoutIndex: index, offset: offset) }
    }

    /// Copies small vertex data into scratch storage and binds it to the given layout (buffer) index.
    ///
    /// Replaces `setVertexBytes(_:length:index:)` inside `Draw` closures on Metal 4.
    func vertexValues<Value>(_ values: [Value], index: Int) -> ParameterModifier<Self> {
        assert(_isPOD(Value.self), "Vertex values must be a POD type.")
        return ParameterModifier(content: self) { $0.setVertexValues(values, layoutIndex: index) }
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
