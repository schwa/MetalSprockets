import Metal
import MetalSprocketsSupport

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
    ///         .visibleFunctionTable("colorFunction", functions: [stitchedFunction])
    /// }
    /// .linkedFunctions([stitchedFunction])
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
        functions: [VisibleFunction]
    ) -> some Element {
        ParameterModifier(content: self) { $0.setFunctionTable(name, stage: functionType, functions: functions) }
    }

    /// Binds a visible function table containing a single function.
    ///
    /// Convenience method for binding a single visible function.
    ///
    /// ```swift
    /// .visibleFunctionTable("colorFunction", function: stitchedFunction)
    /// ```
    func visibleFunctionTable(
        _ name: String,
        functionType: MTLFunctionType? = nil,
        function: VisibleFunction
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
    ///         .visibleFunctionTable("colorFunction", function: stitchedFunction)
    /// }
    /// .linkedFunctions([stitchedFunction])
    /// ```
    ///
    /// - Parameter functions: The Metal functions to link into the pipeline.
    /// - Returns: A modified element with the linked functions set in the environment.
    func linkedFunctions(_ functions: [VisibleFunction]) -> some Element {
        environment(\.linkedFunctions, functions)
    }

    /// Links functions into one stage of a ``RenderPipeline``, in addition to any linked into all stages with
    /// ``linkedFunctions(_:)``. Function types other than `.vertex` and `.fragment` link into all stages.
    func linkedFunctions(_ functions: [VisibleFunction], functionType: MTLFunctionType) -> some Element {
        // swiftlint:disable:next discouraged_optional_collection
        let keyPath: WritableKeyPath<MSEnvironmentValues, [VisibleFunction]?> = switch functionType {
        case .vertex: \.vertexLinkedFunctions
        case .fragment: \.fragmentLinkedFunctions
        default: \.linkedFunctions
        }
        return environment(keyPath, functions)
    }
}

internal extension MSEnvironmentValues {
    // swiftlint:disable discouraged_optional_collection
    @MSEntry var vertexLinkedFunctions: [VisibleFunction]?
    @MSEntry var fragmentLinkedFunctions: [VisibleFunction]?
    // swiftlint:enable discouraged_optional_collection
}
