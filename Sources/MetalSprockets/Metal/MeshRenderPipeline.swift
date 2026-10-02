import Metal
import MetalSprocketsSupport

// MARK: - MeshRenderPipeline

/// A render pipeline using object (optional), mesh and fragment shaders, compiled through the Metal 4 compiler.
///
/// Mesh shaders replace the vertex stage with GPU-driven geometry generation. Issue work with ``Draw`` and
/// `drawMeshThreadgroups`. Parameters reach the object, mesh and fragment stages through their argument tables.
///
/// ```swift
/// RenderPass {
///     MeshRenderPipeline(objectShader: object, meshShader: mesh, fragmentShader: fragment) {
///         Draw { encoder in
///             encoder.drawMeshThreadgroups(
///                 threadgroupsPerGrid: MTLSize(width: 1, height: 1, depth: 1),
///                 threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1),
///                 threadsPerMeshThreadgroup: MTLSize(width: 32, height: 1, depth: 1)
///             )
///         }
///         .parameter("scale", functionType: .object, value: Float(1))
///     }
/// }
/// ```
///
/// Requires mesh-shader support (Apple GPU Family 7 or Mac 2); other devices report a capability error.
///
/// ## Topics
///
/// ### Related Types
/// - ``MeshShader``
/// - ``ObjectShader``
/// - ``RenderPipeline``
public struct MeshRenderPipeline <Content>: Element, SetupElement, BodylessContentElement where Content: Element {
    public typealias Body = Never

    var label: String?
    var objectShader: ObjectShader?
    var meshShader: MeshShader
    var fragmentShader: FragmentShader
    var content: Content

    public init(label: String? = nil, objectShader: ObjectShader? = nil, meshShader: MeshShader, fragmentShader: FragmentShader, @ElementBuilder content: () throws -> Content) throws {
        self.label = label
        self.objectShader = objectShader
        self.meshShader = meshShader
        self.fragmentShader = fragmentShader
        self.content = try content()
    }

    func setupEnter(_ node: Node) throws {
        let environment = node.environmentValues
        let context = try environment.metalContext.orThrow(.missingEnvironment("metalContext"))
        let pass = try environment.activeRenderPassDescriptor.orThrow(.withHint(.missingEnvironment(\.renderPassDescriptor), hint: "Place MeshRenderPipeline inside a RenderPass."))
        let formats = PassFormats(pass)
        let configuration = MeshRenderPipelineConfiguration(
            object: objectShader,
            mesh: meshShader,
            fragment: fragmentShader,
            colorPixelFormats: formats.color,
            depthPixelFormat: formats.depth,
            stencilPixelFormat: formats.stencil,
            rasterSampleCount: formats.sampleCount,
            linkedFunctions: environment.linkedFunctions ?? [],
            label: label
        )
        let pipeline = try context.pipelines.meshRenderPipeline(configuration)
        node.environmentValues.renderPipeline = pipeline
        node.environmentValues.renderPipelineState = pipeline.state
        node.environmentValues.reflection = pipeline.reflection
    }

    nonisolated func requiresSetup(comparedTo old: MeshRenderPipeline<Content>) -> Bool {
        // Always re-run setup; the context cache decides whether anything recompiles.
        true
    }
}
