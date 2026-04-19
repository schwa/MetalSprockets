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
        guard let reflection = node.environmentValues.reflection else {
            // Not ready yet - will be set up when the enclosing pipeline runs
            return
        }
        if let pipelineState = node.environmentValues.renderPipelineState {
            try createFunctionTable(renderPipelineState: pipelineState, reflection: reflection)
        } else if let pipelineState = node.environmentValues.computePipelineState {
            try createFunctionTable(computePipelineState: pipelineState, reflection: reflection)
        }
    }

    func workloadEnter(_ node: Node) throws {
        let hint = "visibleFunctionTable('\(name)') must be placed inside a RenderPipeline or ComputePipeline content block, not as a modifier on the pipeline itself."
        guard let reflection = node.environmentValues.reflection else {
            throw MetalSprocketsError.withHint(.missingEnvironment("reflection"), hint: hint)
        }

        // Create table if not already created during setup
        if functionTable == nil {
            if let pipelineState = node.environmentValues.renderPipelineState {
                try createFunctionTable(renderPipelineState: pipelineState, reflection: reflection)
            } else if let pipelineState = node.environmentValues.computePipelineState {
                try createFunctionTable(computePipelineState: pipelineState, reflection: reflection)
            } else {
                throw MetalSprocketsError.withHint(.missingEnvironment("renderPipelineState or computePipelineState"), hint: hint)
            }
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

    private func createFunctionTable(renderPipelineState: MTLRenderPipelineState, reflection: Reflection) throws {
        let (index, resolvedType) = try resolveBinding(name: name, functionType: functionType, reflection: reflection, supportedTypes: [.vertex, .fragment])

        resolvedIndex = index
        resolvedFunctionType = resolvedType

        let tableDescriptor = MTLVisibleFunctionTableDescriptor()
        tableDescriptor.functionCount = functions.count

        let stage: MTLRenderStages = resolvedType == .vertex ? .vertex : .fragment

        guard let table = renderPipelineState.makeVisibleFunctionTable(
            descriptor: tableDescriptor,
            stage: stage
        ) else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create visible function table for '\(name)'")
        }

        for (i, function) in functions.enumerated() {
            guard let handle = renderPipelineState.functionHandle(function: function, stage: stage) else {
                logger?.warning("Failed to get function handle for \(function.name)")
                continue
            }
            table.setFunction(handle, index: i)
        }

        functionTable = table
    }

    private func createFunctionTable(computePipelineState: MTLComputePipelineState, reflection: Reflection) throws {
        let (index, resolvedType) = try resolveBinding(name: name, functionType: functionType, reflection: reflection, supportedTypes: [.kernel])

        resolvedIndex = index
        resolvedFunctionType = resolvedType

        let tableDescriptor = MTLVisibleFunctionTableDescriptor()
        tableDescriptor.functionCount = functions.count

        guard let table = computePipelineState.makeVisibleFunctionTable(descriptor: tableDescriptor) else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create visible function table for '\(name)'")
        }

        for (i, function) in functions.enumerated() {
            guard let handle = computePipelineState.functionHandle(function: function) else {
                logger?.warning("Failed to get function handle for \(function.name)")
                continue
            }
            table.setFunction(handle, index: i)
        }

        functionTable = table
    }

    private func resolveBinding(name: String, functionType: MTLFunctionType?, reflection: Reflection, supportedTypes: [MTLFunctionType]) throws -> (Int, MTLFunctionType) {
        if let functionType {
            guard supportedTypes.contains(functionType) else {
                throw MetalSprocketsError.resourceCreationFailure("Visible function table '\(name)' specified functionType \(functionType) which is not valid for this pipeline")
            }
            guard let index = reflection.binding(forType: functionType, name: name) else {
                throw MetalSprocketsError.resourceCreationFailure("Visible function table '\(name)' not found in \(functionType) bindings")
            }
            return (index, functionType)
        }
        // Auto-detect from reflection. Prefer the supported types for this pipeline.
        let matches = supportedTypes.compactMap { type -> (Int, MTLFunctionType)? in
            reflection.binding(forType: type, name: name).map { ($0, type) }
        }
        switch matches.count {
        case 0:
            throw MetalSprocketsError.resourceCreationFailure("Visible function table '\(name)' not found in reflection")
        case 1:
            return matches[0]
        default:
            throw MetalSprocketsError.resourceCreationFailure("Visible function table '\(name)' found in multiple function types (\(matches.map(\.1)))) - specify functionType explicitly")
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
    /// The modifier works inside both ``RenderPipeline`` and ``ComputePipeline``
    /// content blocks. For render pipelines, pass `.vertex` or `.fragment` (or
    /// omit `functionType` to auto-detect from reflection). For compute
    /// pipelines, the function type is always `.kernel`.
    ///
    /// ```swift
    /// // Render pipeline
    /// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
    ///     Draw { encoder in ... }
    ///         .visibleFunctionTable("colorFunction", functions: [stitchedFunction.function])
    /// }
    /// .linkedFunctions([stitchedFunction.function])
    ///
    /// // Compute pipeline
    /// ComputePipeline(computeKernel: kernel) {
    ///     ComputeDispatch(threadsPerGrid: size, threadsPerThreadgroup: tg)
    ///         .visibleFunctionTable("snippetFunctions", functions: [snippetFunction])
    /// }
    /// .environment(\.linkedFunctions, linkedFunctions)
    /// ```
    ///
    /// - Parameters:
    ///   - name: The name of the visible function table parameter in the shader.
    ///   - functionType: The shader stage (`.vertex`, `.fragment`, or `.kernel`). If nil, auto-detected from reflection.
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

    /// Attaches a set of linked Metal functions for pipeline compilation.
    ///
    /// Use this modifier when your pipeline needs to call `[[visible]]` functions
    /// (including stitched functions) at runtime via a `visible_function_table`.
    /// The functions must be linked into the pipeline's descriptor so Metal can
    /// produce function handles for them.
    ///
    /// This value is read by ``RenderPipeline``, ``MeshRenderPipeline``, and
    /// ``ComputePass`` when building their pipeline descriptors. Apply this modifier
    /// to the pipeline — not to a child ``Draw`` — so the linked functions are
    /// available during pipeline state creation.
    ///
    /// ```swift
    /// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
    ///     Draw { encoder in ... }
    ///         .visibleFunctionTable("colorFunction", function: stitchedFunction.function)
    /// }
    /// .linkedFunctions([stitchedFunction.function])
    /// ```
    ///
    /// - Parameter functions: The Metal functions to link into the pipeline.
    /// - Returns: A modified element with the linked functions set in the environment.
    func linkedFunctions(_ functions: [MTLFunction]) -> some Element {
        let linked = MTLLinkedFunctions()
        linked.functions = functions
        return environment(\.linkedFunctions, linked)
    }
}
