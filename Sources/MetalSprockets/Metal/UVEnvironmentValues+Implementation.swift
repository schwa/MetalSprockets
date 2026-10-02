import Metal
import MetalKit
import MetalSprocketsSupport
import ModelIO
import QuartzCore

#if os(visionOS)
import CompositorServices
#endif

public extension MSEnvironmentValues {
    // TODO: #106 This is messy and needs organisation and possibly deprecation of unused elements.
    @MSEntry var device: MTLDevice?
    /// The Metal 4 queue of the root rendering this tree.
    @MSEntry var commandQueue: (any MTL4CommandQueue)?
    /// The Metal 4 command buffer being recorded. Present only during the workload phase.
    @MSEntry var commandBuffer: (any MTL4CommandBuffer)?
    /// The open render encoder inside a ``RenderPass``. Present only during the workload phase.
    @MSEntry var renderCommandEncoder: (any MTL4RenderCommandEncoder)?
    @MSEntry var renderPassDescriptor: MTL4RenderPassDescriptor?
    @MSEntry var renderPipelineDescriptor: MTL4RenderPipelineDescriptor?
    @MSEntry var renderPipelineState: MTLRenderPipelineState?
    @MSEntry var vertexDescriptor: MTLVertexDescriptor?
    @MSEntry var depthStencilDescriptor: MTLDepthStencilDescriptor?
    @MSEntry var depthStencilState: MTLDepthStencilState?
    /// The open compute encoder inside a ``ComputePass``. Present only during the workload phase.
    @MSEntry var computeCommandEncoder: (any MTL4ComputeCommandEncoder)?
    @MSEntry var computePipelineState: MTLComputePipelineState?
    @MSEntry var reflection: Reflection?
    @MSEntry var colorAttachment0: (MTLTexture, Int)?
    @MSEntry var depthAttachment: MTLTexture?
    @MSEntry var stencilAttachment: MTLTexture?
    @MSEntry var currentDrawable: CAMetalDrawable?
    @MSEntry var drawableSize: CGSize?
    // nil preserves descriptor linkage; an empty array overrides it.
    // swiftlint:disable:next discouraged_optional_collection
    @MSEntry var linkedFunctions: [VisibleFunction]?
    @MSEntry var shaderStore: ShaderStore?

    /// The process-wide `MS_METAL_LOGGING` setting. On Metal 4 a log state covers a whole command buffer, so roots
    /// read this once rather than per subtree.
    @MSEntry var metalLoggingEnabled: Bool = SystemEnvironment.current.metalLoggingEnabled
}

public extension Element {
    /// Attaches a ``ShaderStore`` to this element and its descendants.
    ///
    /// ``ShaderLibrary`` values used inside the scope will share the attached
    /// store, deduplicating compiled Metal libraries and specialized functions
    /// across views that mount inside the same store.
    ///
    /// If no store is attached, ``RenderView`` provides a private one scoped to
    /// its own lifetime.
    func shaderStore(_ store: ShaderStore) -> some Element {
        environment(\.shaderStore, store)
    }
}

// MARK: - Resource Modifiers
//
// Convenience modifiers for the environment values a caller supplies (#280). The remaining keys — the command
// encoders, reflection, and the pipeline/depth-stencil *state* objects — are outputs published by elements during
// traversal, so they deliberately have no modifier: setting them by hand would lie to the elements downstream.

public extension Element {
    /// Sets the Metal device used by this element and its descendants.
    func device(_ device: MTLDevice) -> some Element {
        environment(\.device, device)
    }

    /// Sets the render pass descriptor used by ``RenderPass``.
    ///
    /// Also publishes the descriptor's attachment formats as
    /// ``MSEnvironmentValues/renderAttachmentFormats``.
    func renderPassDescriptor(_ renderPassDescriptor: MTL4RenderPassDescriptor) -> some Element {
        environment(\.renderPassDescriptor, renderPassDescriptor)
            .environment(\.renderAttachmentFormats, RenderAttachmentFormats(renderPassDescriptor))
    }

    /// Sets the base render pipeline descriptor pipelines are built from.
    func renderPipelineDescriptor(_ renderPipelineDescriptor: MTL4RenderPipelineDescriptor) -> some Element {
        environment(\.renderPipelineDescriptor, renderPipelineDescriptor)
    }

    /// Sets the drawable this frame presents to.
    func currentDrawable(_ currentDrawable: CAMetalDrawable?) -> some Element {
        environment(\.currentDrawable, currentDrawable)
    }

    /// Sets the size of the drawable, in pixels.
    func drawableSize(_ drawableSize: CGSize) -> some Element {
        environment(\.drawableSize, drawableSize)
    }
}

public extension Element {
    func colorAttachment0(_ texture: MTLTexture, index: Int) -> some Element {
        environment(\.colorAttachment0, (texture, index))
    }
    func depthAttachment(_ texture: MTLTexture) -> some Element {
        environment(\.depthAttachment, texture)
    }
    func stencilAttachment(_ texture: MTLTexture) -> some Element {
        environment(\.stencilAttachment, texture)
    }
}

// MARK: - Depth/Stencil Modifiers

public extension Element {
    /// Sets a custom depth/stencil descriptor for draws in this subtree.
    func depthStencilDescriptor(_ depthStencilDescriptor: MTLDepthStencilDescriptor) -> some Element {
        environment(\.depthStencilDescriptor, depthStencilDescriptor)
    }

    /// Configures depth testing for draws in this subtree.
    ///
    /// ```swift
    /// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
    ///     Draw { encoder in ... }
    /// }
    /// .depthCompare(function: .less, enabled: true)
    /// ```
    ///
    /// - Parameters:
    ///   - function: The comparison function (e.g., `.less`, `.lessEqual`).
    ///   - enabled: Whether depth writing is enabled.
    ///
    /// - Note: Also requires `.metalDepthStencilPixelFormat(.depth32Float)` on your `RenderView`.
    func depthCompare(function: MTLCompareFunction, enabled: Bool) -> some Element {
        depthStencilDescriptor(.init(depthCompareFunction: function, isDepthWriteEnabled: enabled))
    }
}

// MARK: - Vertex Descriptor Modifiers

public extension Element {
    /// Sets the vertex descriptor for interpreting vertex buffer data.
    ///
    /// ```swift
    /// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
    ///     Draw { encoder in ... }
    /// }
    /// .vertexDescriptor(MyVertex.descriptor)
    /// ```
    func vertexDescriptor(_ vertexDescriptor: MTLVertexDescriptor?) -> some Element {
        environment(\.vertexDescriptor, vertexDescriptor)
    }

    /// Sets the vertex descriptor from a Model I/O descriptor.
    func vertexDescriptor(_ vertexDescriptor: MDLVertexDescriptor) -> some Element {
        self.vertexDescriptor(MTKMetalVertexDescriptorFromModelIO(vertexDescriptor).orFatalError(.resourceCreationFailure("Failed to create MTLVertexDescriptor from MDLVertexDescriptor")))
    }
}

// MARK: - visionOS CompositorServices Support

#if os(visionOS)
public extension MSEnvironmentValues {
    /// The render context for CompositorServices immersive rendering.
    /// When set, ``RenderPass`` ends its encoder through `renderContext.endEncoding(commandEncoder:)`.
    @MSEntry var immersiveRenderContext: LayerRenderer.Drawable.RenderContext?
}

public extension Element {
    /// Sets the immersive render context for CompositorServices rendering.
    func immersiveRenderContext(_ renderContext: LayerRenderer.Drawable.RenderContext?) -> some Element {
        environment(\.immersiveRenderContext, renderContext)
    }
}
#endif
