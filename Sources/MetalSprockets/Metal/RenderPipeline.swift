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
        // Copy so we never mutate a descriptor shared via the environment (see #334).
        let renderPipelineDescriptor = try environment.renderPipelineDescriptor.orThrow(.missingEnvironment(\.renderPipelineDescriptor)).copyWithType(MTLRenderPipelineDescriptor.self)
        let device = try device.orThrow(.missingEnvironment(\.device))

        // Collect the values that actually affect the PSO. Pixel formats come
        // from the render-pass textures by value (texture identity churns per
        // frame but formats are stable). See #327 / #333.
        let color0Texture = renderPassDescriptor.colorAttachments[0].texture
        let depthTexture = renderPassDescriptor.depthAttachment?.texture
        let stencilTexture = renderPassDescriptor.stencilAttachment?.texture

        let key = RenderPipelineCache.Key(
            vertexFunction: ObjectIdentifier(vertexShader.function),
            fragmentFunction: ObjectIdentifier(fragmentShader.function),
            linkedFunctions: environment.linkedFunctions.map { ObjectIdentifier($0) },
            vertexDescriptor: environment.vertexDescriptor.map { ObjectIdentifier($0) },
            colorPixelFormat0: color0Texture?.pixelFormat ?? .invalid,
            colorSampleCount0: color0Texture?.sampleCount ?? 1,
            depthPixelFormat: depthTexture?.pixelFormat ?? .invalid,
            stencilPixelFormat: stencilTexture?.pixelFormat ?? .invalid,
            depthStencil: environment.depthStencilDescriptor.map(DepthStencilKey.init),
            label: label
        )

        let cache = node.cache(RenderPipelineCache.self) { RenderPipelineCache() }
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

        // Cache miss: (re)configure the descriptor and build a new PSO.
        renderPipelineDescriptor.vertexFunction = vertexShader.function
        renderPipelineDescriptor.fragmentFunction = fragmentShader.function

        if let linkedFunctions = environment.linkedFunctions {
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
            let color0Texture {
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = color0Texture.pixelFormat
        }

        // Set rasterSampleCount from the render pass texture for MSAA support
        if let color0Texture {
            renderPipelineDescriptor.rasterSampleCount = color0Texture.sampleCount
        }
        if renderPipelineDescriptor.depthAttachmentPixelFormat == .invalid,
            let depthTexture {
            renderPipelineDescriptor.depthAttachmentPixelFormat = depthTexture.pixelFormat
        }
        if renderPipelineDescriptor.stencilAttachmentPixelFormat == .invalid,
            let stencilTexture {
            renderPipelineDescriptor.stencilAttachmentPixelFormat = stencilTexture.pixelFormat
        }
        if let label {
            renderPipelineDescriptor.label = label
        }

        let (renderPipelineState, rawReflection) = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor, options: .bindingInfo)
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
        logger?.verbose?.info("Enter render pipeline: \(label ?? "<unlabeled>") (\(node.element.debugName))")

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
        // Always re-run setup. The per-node cache inside setupEnter decides
        // whether to rebuild the underlying PSO based on its actual inputs,
        // including environment values (linkedFunctions, descriptors, pixel
        // formats) that we can't see from here. Setup is cheap on a cache hit.
        true
    }
}

private final class RenderPipelineCache: NodeElementCache {
    struct Key: Hashable {
        let vertexFunction: ObjectIdentifier
        let fragmentFunction: ObjectIdentifier
        let linkedFunctions: ObjectIdentifier?
        let vertexDescriptor: ObjectIdentifier?
        let colorPixelFormat0: MTLPixelFormat
        let colorSampleCount0: Int
        let depthPixelFormat: MTLPixelFormat
        let stencilPixelFormat: MTLPixelFormat
        let depthStencil: DepthStencilKey?
        let label: String?
    }

    var key: Key?
    var pipelineState: MTLRenderPipelineState?
    var reflection: Reflection?
    var depthStencilState: MTLDepthStencilState?
}
