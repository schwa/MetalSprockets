import Metal
import MetalSprocketsSupport

// MARK: - RenderPipeline

/// Configures a Metal render pipeline state with vertex and fragment shaders.
///
/// `RenderPipeline` binds shaders and creates the pipeline state object that the GPU
/// uses to process vertices and fragments.
///
/// > Important: `RenderPipeline` must be placed inside a ``RenderPass``. A render pass
/// provides the render targets and creates the command encoder that the pipeline uses.
/// See ``RenderPass`` for the difference between passes and pipelines.
///
/// ## Overview
///
/// Create a render pipeline inside a render pass by specifying vertex and fragment shaders:
///
/// ```swift
/// let library = try ShaderLibrary(bundle: .main)
///
/// RenderPass {
///     RenderPipeline(
///         vertexShader: library.myVertexShader,
///         fragmentShader: library.myFragmentShader
///     ) {
///         Draw { encoder in
///             // Issue draw commands
///         }
///     }
/// }
/// ```
///
/// ## Vertex Descriptors
///
/// Use the `.vertexDescriptor()` modifier to specify how vertex data is laid out:
///
/// ```swift
/// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///     Draw { encoder in ... }
/// }
/// .vertexDescriptor(MyVertex.descriptor)
/// ```
///
/// ## Depth Testing
///
/// Enable depth testing with the `.depthCompare()` modifier:
///
/// ```swift
/// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///     Draw { encoder in ... }
/// }
/// .depthCompare(function: .less, enabled: true)
/// ```
///
/// ## Parameters
///
/// Use the `.parameter()` modifier to bind values to shader uniforms by name:
///
/// ```swift
/// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///     Draw { encoder in ... }
/// }
/// .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
/// ```
///
/// ## Topics
///
/// ### Related Elements
/// - ``RenderPass``
/// - ``Draw``
/// - ``ShaderLibrary``
public struct RenderPipeline <Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    public typealias Body = Never
    @MSEnvironment(\.device)
    var device

    @MSEnvironment(\.depthStencilState)
    var depthStencilState

    var label: String?
    var vertexShader: VertexShader
    var fragmentShader: FragmentShader
    var content: Content

    @MSState
    var reflection: Reflection?

    /// Creates a render pipeline with the specified shaders and content.
    ///
    /// - Parameters:
    ///   - label: An optional label for debugging (visible in GPU frame capture).
    ///   - vertexShader: The vertex shader function to use.
    ///   - fragmentShader: The fragment shader function to use.
    ///   - content: A closure that returns child elements (typically ``Draw`` elements).
    public init(label: String? = nil, vertexShader: VertexShader, fragmentShader: FragmentShader, @ElementBuilder content: () throws -> Content) throws {
        self.label = label
        self.vertexShader = vertexShader
        self.fragmentShader = fragmentShader
        self.content = try content()
    }

    func setupEnter(_ node: Node) throws {
        let environment = node.environmentValues

        let renderPassDescriptor = try environment.renderPassDescriptor.orThrow(.missingEnvironment(\.renderPassDescriptor)).copyWithType(MTLRenderPassDescriptor.self)

        let renderPipelineDescriptor = try environment.renderPipelineDescriptor.orThrow(.missingEnvironment(\.renderPipelineDescriptor))
        renderPipelineDescriptor.vertexFunction = vertexShader.function
        renderPipelineDescriptor.fragmentFunction = fragmentShader.function

        if let linkedFunctions = node.environmentValues.linkedFunctions {
            // TODO: How do we handle separate linked functions for vertex and fragment? [FILE ME]
            renderPipelineDescriptor.vertexLinkedFunctions = linkedFunctions
            renderPipelineDescriptor.fragmentLinkedFunctions = linkedFunctions
        }

        if let vertexDescriptor = environment.vertexDescriptor {
            renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        }

        // Only set pixel formats if they haven't been explicitly configured
        // TODO: #95 This is copying everything from the render pass descriptor. But really we should be getting this entirely from the environment.
        if renderPipelineDescriptor.colorAttachments[0].pixelFormat == .invalid,
            let colorAttachment0Texture = renderPassDescriptor.colorAttachments[0].texture {
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = colorAttachment0Texture.pixelFormat
        }

        // Set rasterSampleCount from the render pass texture for MSAA support
        if let colorAttachment0Texture = renderPassDescriptor.colorAttachments[0].texture {
            renderPipelineDescriptor.rasterSampleCount = colorAttachment0Texture.sampleCount
        }
        if renderPipelineDescriptor.depthAttachmentPixelFormat == .invalid,
            let depthAttachmentTexture = renderPassDescriptor.depthAttachment?.texture {
            renderPipelineDescriptor.depthAttachmentPixelFormat = depthAttachmentTexture.pixelFormat
        }
        if renderPipelineDescriptor.stencilAttachmentPixelFormat == .invalid,
            let stencilAttachmentTexture = renderPassDescriptor.stencilAttachment?.texture {
            renderPipelineDescriptor.stencilAttachmentPixelFormat = stencilAttachmentTexture.pixelFormat
        }
        if let label {
            renderPipelineDescriptor.label = label
        }
        let device = try device.orThrow(.missingEnvironment(\.device))
        let (renderPipelineState, reflection) = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor, options: .bindingInfo)
        self.reflection = .init(reflection.orFatalError(.resourceCreationFailure("Failed to create reflection.")))

        if environment.depthStencilState == nil, let depthStencilDescriptor = environment.depthStencilDescriptor {
            let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
            node.environmentValues.depthStencilState = depthStencilState
        }

        node.environmentValues.renderPipelineState = renderPipelineState
        node.environmentValues.reflection = self.reflection
    }

    func workloadEnter(_ node: Node) throws {
        logger?.verbose?.info("Start render pipeline: \(label ?? "<unlabeled>") (\(node.element.debugName))")

        let renderCommandEncoder = try node.environmentValues.renderCommandEncoder.orThrow(.missingEnvironment(\.renderCommandEncoder))
        let renderPipelineState = try node.environmentValues.renderPipelineState.orThrow(.missingEnvironment(\.renderPipelineState))

        if let depthStencilState {
            renderCommandEncoder.setDepthStencilState(depthStencilState)
        }

        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
    }

    func workloadExit(_ node: Node) throws {
        logger?.verbose?.info("Exit render pipeline: \(label ?? "<unlabeled>") (\(node.element.debugName))")
    }

    func requiresSetup(comparedTo old: RenderPipeline<Content>) -> Bool {
        vertexShader != old.vertexShader || fragmentShader != old.fragmentShader
    }
}
