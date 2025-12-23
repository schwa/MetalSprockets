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

        let meshRenderPipelineDescriptor = MTLMeshRenderPipelineDescriptor()
        meshRenderPipelineDescriptor.objectFunction = objectShader?.function
        meshRenderPipelineDescriptor.meshFunction = meshShader.function
        meshRenderPipelineDescriptor.fragmentFunction = fragmentShader.function

        if let linkedFunctions = node.environmentValues.linkedFunctions {
            meshRenderPipelineDescriptor.objectLinkedFunctions = linkedFunctions
            meshRenderPipelineDescriptor.meshLinkedFunctions = linkedFunctions
            meshRenderPipelineDescriptor.fragmentLinkedFunctions = linkedFunctions
        }

        if let colorAttachment0Texture = renderPassDescriptor.colorAttachments[0].texture {
            meshRenderPipelineDescriptor.colorAttachments[0].pixelFormat = colorAttachment0Texture.pixelFormat
        }
        if let depthAttachmentTexture = renderPassDescriptor.depthAttachment?.texture {
            meshRenderPipelineDescriptor.depthAttachmentPixelFormat = depthAttachmentTexture.pixelFormat
        }
        if let stencilAttachmentTexture = renderPassDescriptor.stencilAttachment?.texture {
            meshRenderPipelineDescriptor.stencilAttachmentPixelFormat = stencilAttachmentTexture.pixelFormat
        }
        if let label {
            meshRenderPipelineDescriptor.label = label
        }
        let device = try device.orThrow(.missingEnvironment(\.device))
        let (renderPipelineState, reflection) = try device.makeRenderPipelineState(descriptor: meshRenderPipelineDescriptor, options: .bindingInfo)
        self.reflection = .init(reflection.orFatalError(.resourceCreationFailure("Failed to create reflection.")))

        if environment.depthStencilState == nil, let depthStencilDescriptor = environment.depthStencilDescriptor {
            let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
            node.environmentValues.depthStencilState = depthStencilState
        }

        node.environmentValues.renderPipelineState = renderPipelineState
        node.environmentValues.reflection = self.reflection
    }

    func workloadEnter(_ node: Node) throws {
        logger?.verbose?.info("Start mesh render pipeline: \(label ?? "<unlabeled>") (\(node.element.debugName))")

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
        false
    }
}
