import Metal
import MetalSprocketsSupport

// MARK: - RenderPipeline

/// A render pipeline compiled through the Metal 4 compiler for the enclosing ``RenderPass``.
///
/// Attachment formats and sample count come from the pass. Vertex layout comes from
/// ``Element/vertexDescriptor(_:)-(MTLVertexDescriptor?)``, linked functions from ``Element/linkedFunctions(_:)``,
/// and any other pipeline state (such as blending) from ``Element/renderPipelineDescriptorTransformer(_:)``.
/// Pipelines are cached by their complete identity, so steady-state frames never recompile.
///
/// ```swift
/// try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///     Draw { encoder in
///         encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
///     }
///     .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
/// }
/// .vertexDescriptor(vs.inferredVertexDescriptor())
/// ```
public struct RenderPipeline <Content>: Element, SetupElement, BodylessContentElement where Content: Element {
    public typealias Body = Never

    var label: String?
    var vertexShader: VertexShader
    var fragmentShader: FragmentShader
    var content: Content

    public init(label: String? = nil, vertexShader: VertexShader, fragmentShader: FragmentShader, @ElementBuilder content: () throws -> Content) throws {
        self.label = label
        self.vertexShader = vertexShader
        self.fragmentShader = fragmentShader
        self.content = try content()
    }

    func setupEnter(_ node: Node) throws {
        let environment = node.environmentValues
        let context = try environment.metalContext.orThrow(.missingEnvironment("metalContext"))
        let pass = try environment.activeRenderPassDescriptor.orThrow(.withHint(.missingEnvironment("renderPassDescriptor"), hint: "Place RenderPipeline inside a RenderPass."))
        let formats = PassFormats(pass)
        let configuration = RenderPipelineConfiguration(
            vertex: vertexShader,
            fragment: fragmentShader,
            colorPixelFormats: formats.color,
            depthPixelFormat: formats.depth,
            stencilPixelFormat: formats.stencil,
            rasterSampleCount: formats.sampleCount,
            vertexDescriptor: environment.vertexDescriptor,
            linkedFunctions: environment.linkedFunctions ?? [],
            baseDescriptor: environment.renderPipelineDescriptor,
            label: label
        )
        // The context cache makes re-running setup cheap and recompiles only when identity changes.
        let pipeline = try context.pipelines.renderPipeline(configuration)
        node.environmentValues.renderPipeline = pipeline
        node.environmentValues.renderPipelineState = pipeline.state
        node.environmentValues.reflection = pipeline.reflection
    }

    nonisolated func requiresSetup(comparedTo old: RenderPipeline<Content>) -> Bool {
        // Always re-run setup; the context cache decides whether anything recompiles.
        true
    }
}
