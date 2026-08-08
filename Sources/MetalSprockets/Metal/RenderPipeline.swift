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
public struct RenderPipeline <Content>: Element, SetupElement, WorkloadElement, BodylessContentElement where Content: Element {
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

        let attachmentFormats = try environment.renderAttachmentFormats.orThrow(.missingEnvironment(\.renderAttachmentFormats))
        // Copy so we never mutate a descriptor shared via the environment (see #334).
        let renderPipelineDescriptor = try environment.renderPipelineDescriptor.orThrow(.missingEnvironment(\.renderPipelineDescriptor)).copyWithType(MTLRenderPipelineDescriptor.self)
        let device = try device.orThrow(.missingEnvironment(\.device))
        try ShaderDeviceCheck.validate(
            [("vertex", vertexShader.function), ("fragment", fragmentShader.function)],
            device: device,
            label: label
        )

        // Configure the descriptor _before_ building the cache key. The key hashes the fully configured descriptor,
        // which is the only way changes made by a `renderPipelineDescriptorTransformer` (which are already baked into the
        // inherited descriptor) can be seen by the cache. See #359.
        renderPipelineDescriptor.vertexFunction = vertexShader.function
        renderPipelineDescriptor.fragmentFunction = fragmentShader.function

        if let linkedFunctions = environment.linkedFunctions {
            // TODO: #383 Support separate linked functions for vertex and fragment.
            renderPipelineDescriptor.vertexLinkedFunctions = linkedFunctions
            renderPipelineDescriptor.fragmentLinkedFunctions = linkedFunctions
        }

        if let vertexDescriptor = environment.vertexDescriptor {
            renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        }

        // Formats come from the environment by value, not from the render pass descriptor's
        // textures: texture identity churns per frame but formats are stable. See #327 / #333 / #363.
        // Explicitly configured formats on the pipeline descriptor win over these defaults.
        for (index, pixelFormat) in attachmentFormats.colorPixelFormats.enumerated() where pixelFormat != .invalid {
            if renderPipelineDescriptor.colorAttachments[index].pixelFormat == .invalid {
                renderPipelineDescriptor.colorAttachments[index].pixelFormat = pixelFormat
            }
        }

        // rasterSampleCount is not a "format" the caller configures per-attachment; it has to match
        // the render pass attachments for MSAA to work.
        if attachmentFormats.colorPixelFormat(at: 0) != .invalid {
            renderPipelineDescriptor.rasterSampleCount = attachmentFormats.rasterSampleCount
        }
        if renderPipelineDescriptor.depthAttachmentPixelFormat == .invalid {
            renderPipelineDescriptor.depthAttachmentPixelFormat = attachmentFormats.depthPixelFormat
        }
        if renderPipelineDescriptor.stencilAttachmentPixelFormat == .invalid {
            renderPipelineDescriptor.stencilAttachmentPixelFormat = attachmentFormats.stencilPixelFormat
        }
        if let label {
            renderPipelineDescriptor.label = label
        }

        let key = RenderPipelineCache.Key(
            vertexFunction: ObjectIdentifier(vertexShader.function),
            fragmentFunction: ObjectIdentifier(fragmentShader.function),
            linkedFunctions: environment.linkedFunctions.map { ObjectIdentifier($0) },
            // `renderPipelineDescriptor` is a private copy that nothing mutates from here on, so it is safe to keep
            // it inside a hashable key.
            descriptor: NSObjectValueKey(object: renderPipelineDescriptor),
            depthStencil: environment.depthStencilDescriptor.map(DepthStencilKey.init),
            label: label
        )

        let cache = node.cache(RenderPipelineCache.self) { RenderPipelineCache() }

        // A node's environment storage persists across frames (the parent environment is merged into it rather than
        // replacing it), so a depth-stencil state this node wrote on an earlier frame is still visible here. Only a
        // state inherited from an ancestor should win over the descriptor. See #358.
        let inheritedDepthStencilState = environment.depthStencilState.flatMap { state in
            state === cache.depthStencilState ? nil : state
        }

        if cache.key == key,
            let cachedPSO = cache.pipelineState,
            let cachedReflection = cache.reflection {
            node.environmentValues.renderPipelineState = cachedPSO
            node.environmentValues.reflection = cachedReflection
            self.reflection = cachedReflection
            if inheritedDepthStencilState == nil, let cachedDSS = cache.depthStencilState {
                node.environmentValues.depthStencilState = cachedDSS
            }
            return
        }

        // Cache miss: build a new PSO from the descriptor configured above.
        let (renderPipelineState, rawReflection) = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor, options: .bindingInfo)
        let reflection = Reflection(rawReflection.orFatalError(.resourceCreationFailure("Failed to create reflection.")))
        self.reflection = reflection

        var builtDepthStencilState: MTLDepthStencilState?
        if inheritedDepthStencilState == nil {
            // Assign unconditionally, so that dropping the descriptor also drops the state we wrote last frame.
            builtDepthStencilState = environment.depthStencilDescriptor.flatMap { device.makeDepthStencilState(descriptor: $0) }
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

/// Wraps an `NSObject` for value-based `Hashable` conformance using
/// `isEqual(_:)` / `hash`. Use instead of `ObjectIdentifier` when the
/// object may be recreated each frame with identical contents (e.g.
/// `MTLVertexDescriptor`, `MTLRenderPipelineDescriptor`). See #342.
///
/// > Important: the wrapped object must not be mutated while the key is alive.
private struct NSObjectValueKey<T: NSObject>: Hashable {
    let object: T
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.object.isEqual(rhs.object) }
    func hash(into hasher: inout Hasher) { hasher.combine(object.hash) }
}

private final class RenderPipelineCache: NodeElementCache {
    struct Key: Hashable {
        let vertexFunction: ObjectIdentifier
        let fragmentFunction: ObjectIdentifier
        let linkedFunctions: ObjectIdentifier?
        let descriptor: NSObjectValueKey<MTLRenderPipelineDescriptor>
        let depthStencil: DepthStencilKey?
        let label: String?
    }

    var key: Key?
    var pipelineState: MTLRenderPipelineState?
    var reflection: Reflection?
    var depthStencilState: MTLDepthStencilState?
}
