import Metal
import MetalSprocketsSupport

// MARK: - VisibleFunctionTableModifier

/// A modifier that binds a visible function table to a shader.
internal struct VisibleFunctionTableModifier<Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var name: String
    var functions: [MTLFunction]
    var functionType: MTLFunctionType?
    var content: Content

    @MSState
    var functionTable: MTLVisibleFunctionTable?

    @MSState
    var resolvedIndex: Int?

    @MSState
    var resolvedFunctionType: MTLFunctionType?

    func setupEnter(_ node: Node) throws {
        guard let pipelineState = node.environmentValues.renderPipelineState,
              let reflection = node.environmentValues.reflection else {
            // Not ready yet - will be set up when RenderPipeline runs
            return
        }

        try createFunctionTable(pipelineState: pipelineState, reflection: reflection)
    }

    func workloadEnter(_ node: Node) throws {
        let hint = "visibleFunctionTable('\(name)') must be placed inside a RenderPipeline content block, not as a modifier on RenderPipeline itself."
        guard let pipelineState = node.environmentValues.renderPipelineState else {
            throw MetalSprocketsError.withHint(.missingEnvironment("renderPipelineState"), hint: hint)
        }
        guard let reflection = node.environmentValues.reflection else {
            throw MetalSprocketsError.withHint(.missingEnvironment("reflection"), hint: hint)
        }

        // Create table if not already created during setup
        if functionTable == nil {
            try createFunctionTable(pipelineState: pipelineState, reflection: reflection)
        }

        guard let table = functionTable,
              let index = resolvedIndex,
              let resolvedType = resolvedFunctionType else {
            return
        }

        // Bind the table to the encoder
        if let encoder = node.environmentValues.renderCommandEncoder {
            switch resolvedType {
            case .vertex:
                encoder.setVertexVisibleFunctionTable(table, bufferIndex: index)
            case .fragment:
                encoder.setFragmentVisibleFunctionTable(table, bufferIndex: index)
            default:
                logger?.warning("Unsupported function type for visible function table: \(resolvedType.rawValue)")
            }
        } else if let encoder = node.environmentValues.computeCommandEncoder {
            encoder.setVisibleFunctionTable(table, bufferIndex: index)
        }
    }

    private func createFunctionTable(pipelineState: MTLRenderPipelineState, reflection: Reflection) throws {
        let (index, resolvedType) = try resolveBinding(name: name, functionType: functionType, reflection: reflection)

        resolvedIndex = index
        resolvedFunctionType = resolvedType

        let tableDescriptor = MTLVisibleFunctionTableDescriptor()
        tableDescriptor.functionCount = functions.count

        let stage: MTLRenderStages = resolvedType == .vertex ? .vertex : .fragment

        guard let table = pipelineState.makeVisibleFunctionTable(
            descriptor: tableDescriptor,
            stage: stage
        ) else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create visible function table for '\(name)'")
        }

        for (i, function) in functions.enumerated() {
            guard let handle = pipelineState.functionHandle(function: function, stage: stage) else {
                logger?.warning("Failed to get function handle for \(function.name)")
                continue
            }
            table.setFunction(handle, index: i)
        }

        functionTable = table
    }

    private func resolveBinding(name: String, functionType: MTLFunctionType?, reflection: Reflection) throws -> (Int, MTLFunctionType) {
        if let functionType {
            // Explicit function type specified
            guard let index = reflection.binding(forType: functionType, name: name) else {
                throw MetalSprocketsError.resourceCreationFailure("Visible function table '\(name)' not found in \(functionType) bindings")
            }
            return (index, functionType)
        } else {
            // Auto-detect from reflection
            let vertexIndex = reflection.binding(forType: .vertex, name: name)
            let fragmentIndex = reflection.binding(forType: .fragment, name: name)

            switch (vertexIndex, fragmentIndex) {
            case (.some(let index), nil):
                return (index, .vertex)
            case (nil, .some(let index)):
                return (index, .fragment)
            case (.some, .some):
                throw MetalSprocketsError.resourceCreationFailure("Visible function table '\(name)' found in both vertex and fragment - specify functionType explicitly")
            case (nil, nil):
                throw MetalSprocketsError.resourceCreationFailure("Visible function table '\(name)' not found in reflection")
            }
        }
    }

    nonisolated func requiresSetup(comparedTo old: VisibleFunctionTableModifier<Content>) -> Bool {
        // Require setup if name or functions changed
        name != old.name ||
            functions.count != old.functions.count ||
            !zip(functions, old.functions).allSatisfy { $0 === $1 }
    }
}

// MARK: - Element Extension

public extension Element {
    /// Binds a visible function table containing the specified functions.
    ///
    /// Use this modifier to bind stitched or visible functions to a shader.
    /// The binding index is resolved from reflection using the parameter name.
    ///
    /// ```swift
    /// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
    ///     Draw { encoder in ... }
    /// }
    /// .linkedFunctions([stitchedFunction.function])
    /// .visibleFunctionTable("colorFunction", functions: [stitchedFunction.function])
    /// ```
    ///
    /// - Parameters:
    ///   - name: The name of the visible function table parameter in the shader.
    ///   - functionType: The shader stage (`.vertex` or `.fragment`). If nil, auto-detected from reflection.
    ///   - functions: The Metal functions to include in the table.
    /// - Returns: A modified element with the visible function table bound.
    func visibleFunctionTable(
        _ name: String,
        functionType: MTLFunctionType? = nil,
        functions: [MTLFunction]
    ) -> some Element {
        VisibleFunctionTableModifier(
            name: name,
            functions: functions,
            functionType: functionType,
            content: self
        )
    }

    /// Binds a visible function table containing a single function.
    ///
    /// Convenience method for binding a single visible function.
    ///
    /// ```swift
    /// .visibleFunctionTable("colorFunction", function: stitchedFunction.function)
    /// ```
    func visibleFunctionTable(
        _ name: String,
        functionType: MTLFunctionType? = nil,
        function: MTLFunction
    ) -> some Element {
        visibleFunctionTable(name, functionType: functionType, functions: [function])
    }
}
