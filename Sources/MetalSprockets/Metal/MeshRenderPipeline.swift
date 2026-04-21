import Metal
import MetalSprocketsSupport

// MARK: - MeshRenderPipeline

/// A render pipeline using mesh shaders for GPU-driven geometry generation.
///
/// Mesh shaders replace the traditional vertex shader stage with a more flexible
/// model where geometry is generated directly on the GPU. This enables advanced
/// techniques like GPU culling, LOD, and procedural geometry.
///
/// ## Overview
///
/// Create a mesh pipeline with mesh and fragment shaders:
///
/// ```swift
/// RenderPass {
///     MeshRenderPipeline(
///         meshShader: library.myMeshShader,
///         fragmentShader: library.myFragmentShader
///     ) {
///         MeshDraw { encoder in
///             encoder.drawMeshThreadgroups(
///                 MTLSize(width: 1, height: 1, depth: 1),
///                 threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1),
///                 threadsPerMeshThreadgroup: MTLSize(width: 32, height: 1, depth: 1)
///             )
///         }
///     }
/// }
/// ```
///
/// ## Object Shaders
///
/// Optionally add an object shader for per-object processing:
///
/// ```swift
/// MeshRenderPipeline(
///     objectShader: library.myObjectShader,
///     meshShader: library.myMeshShader,
///     fragmentShader: library.myFragmentShader
/// ) {
///     // Draw commands
/// }
/// ```
///
/// ## Topics
///
/// ### Related Types
/// - ``MeshShader``
/// - ``ObjectShader``
/// - ``RenderPipeline``
public struct MeshRenderPipeline <Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    public typealias Body = Never
    @MSEnvironment(\.device)
    var device

    @MSEnvironment(\.depthStencilState)
    var depthStencilState

    var label: String?
    var objectShader: ObjectShader?
    var meshShader: MeshShader
    var fragmentShader: FragmentShader
    var content: Content

    @MSState
    var reflection: Reflection?

    /// Creates a mesh render pipeline.
    ///
    /// - Parameters:
    ///   - label: An optional label for debugging.
    ///   - objectShader: An optional object shader for per-object processing.
    ///   - meshShader: The mesh shader that generates geometry.
    ///   - fragmentShader: The fragment shader for pixel coloring.
    ///   - content: Child elements (typically mesh draw commands).
    public init(label: String? = nil, objectShader: ObjectShader? = nil, meshShader: MeshShader, fragmentShader: FragmentShader, @ElementBuilder content: () throws -> Content) throws {
        self.label = label
        self.objectShader = objectShader
        self.meshShader = meshShader
        self.fragmentShader = fragmentShader
        self.content = try content()
    }

    func setupEnter(_ node: Node) throws {
        let environment = node.environmentValues

        let renderPassDescriptor = try environment.renderPassDescriptor.orThrow(.missingEnvironment(\.renderPassDescriptor)).copyWithType(MTLRenderPassDescriptor.self)
        let device = try device.orThrow(.missingEnvironment(\.device))

        let color0Texture = renderPassDescriptor.colorAttachments[0].texture
        let depthTexture = renderPassDescriptor.depthAttachment?.texture
        let stencilTexture = renderPassDescriptor.stencilAttachment?.texture

        let key = MeshRenderPipelineCache.Key(
            objectFunction: objectShader.map { ObjectIdentifier($0.function) },
            meshFunction: ObjectIdentifier(meshShader.function),
            fragmentFunction: ObjectIdentifier(fragmentShader.function),
            linkedFunctions: environment.linkedFunctions.map { ObjectIdentifier($0) },
            colorPixelFormat0: color0Texture?.pixelFormat ?? .invalid,
            colorSampleCount0: color0Texture?.sampleCount ?? 1,
            depthPixelFormat: depthTexture?.pixelFormat ?? .invalid,
            stencilPixelFormat: stencilTexture?.pixelFormat ?? .invalid,
            depthStencilDescriptor: environment.depthStencilDescriptor.map { ObjectIdentifier($0) },
            label: label
        )

        let cache = node.cache(MeshRenderPipelineCache.self) { MeshRenderPipelineCache() }
        if cache.key == key,
            let cachedPSO = cache.pipelineState,
            let cachedReflection = cache.reflection {
            node.environmentValues.renderPipelineState = cachedPSO
            node.environmentValues.reflection = cachedReflection
            self.reflection = cachedReflection
            if environment.depthStencilState == nil, let cachedDSS = cache.depthStencilState {
                node.environmentValues.depthStencilState = cachedDSS
            }
            return
        }

        // Cache miss: build a fresh descriptor and PSO.
        let meshRenderPipelineDescriptor = MTLMeshRenderPipelineDescriptor()
        meshRenderPipelineDescriptor.objectFunction = objectShader?.function
        meshRenderPipelineDescriptor.meshFunction = meshShader.function
        meshRenderPipelineDescriptor.fragmentFunction = fragmentShader.function

        if let linkedFunctions = environment.linkedFunctions {
            meshRenderPipelineDescriptor.objectLinkedFunctions = linkedFunctions
            meshRenderPipelineDescriptor.meshLinkedFunctions = linkedFunctions
            meshRenderPipelineDescriptor.fragmentLinkedFunctions = linkedFunctions
        }

        if let color0Texture {
            meshRenderPipelineDescriptor.colorAttachments[0].pixelFormat = color0Texture.pixelFormat
            // Set rasterSampleCount from the render pass texture for MSAA support
            meshRenderPipelineDescriptor.rasterSampleCount = color0Texture.sampleCount
        }
        if let depthTexture {
            meshRenderPipelineDescriptor.depthAttachmentPixelFormat = depthTexture.pixelFormat
        }
        if let stencilTexture {
            meshRenderPipelineDescriptor.stencilAttachmentPixelFormat = stencilTexture.pixelFormat
        }
        if let label {
            meshRenderPipelineDescriptor.label = label
        }

        let (renderPipelineState, rawReflection) = try device.makeRenderPipelineState(descriptor: meshRenderPipelineDescriptor, options: .bindingInfo)
        let reflection = Reflection(rawReflection.orFatalError(.resourceCreationFailure("Failed to create reflection.")))
        self.reflection = reflection

        var builtDepthStencilState: MTLDepthStencilState?
        if environment.depthStencilState == nil, let depthStencilDescriptor = environment.depthStencilDescriptor {
            builtDepthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
            node.environmentValues.depthStencilState = builtDepthStencilState
        }

        cache.key = key
        cache.pipelineState = renderPipelineState
        cache.reflection = reflection
        cache.depthStencilState = builtDepthStencilState

        node.environmentValues.renderPipelineState = renderPipelineState
        node.environmentValues.reflection = reflection
    }

    func workloadEnter(_ node: Node) throws {
        logger?.verbose?.info("Enter mesh render pipeline: \(label ?? "<unlabeled>") (\(node.element.debugName))")

        let renderCommandEncoder = try node.environmentValues.renderCommandEncoder.orThrow(.missingEnvironment(\.renderCommandEncoder))
        let renderPipelineState = try node.environmentValues.renderPipelineState.orThrow(.missingEnvironment(\.renderPipelineState))

        if let depthStencilState {
            renderCommandEncoder.setDepthStencilState(depthStencilState)
        }

        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
    }

    func workloadExit(_ node: Node) throws {
        logger?.verbose?.info("Exit mesh render pipeline: \(label ?? "<unlabeled>") (\(node.element.debugName))")
    }

    nonisolated func requiresSetup(comparedTo old: MeshRenderPipeline<Content>) -> Bool {
        // Always re-run setup; the per-node cache handles reuse. See #327 / #333.
        true
    }
}

private final class MeshRenderPipelineCache: NodeElementCache {
    struct Key: Hashable {
        let objectFunction: ObjectIdentifier?
        let meshFunction: ObjectIdentifier
        let fragmentFunction: ObjectIdentifier
        let linkedFunctions: ObjectIdentifier?
        let colorPixelFormat0: MTLPixelFormat
        let colorSampleCount0: Int
        let depthPixelFormat: MTLPixelFormat
        let stencilPixelFormat: MTLPixelFormat
        let depthStencilDescriptor: ObjectIdentifier?
        let label: String?
    }

    var key: Key?
    var pipelineState: MTLRenderPipelineState?
    var reflection: Reflection?
    var depthStencilState: MTLDepthStencilState?
}
