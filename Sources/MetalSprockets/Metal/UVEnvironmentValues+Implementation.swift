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
    @MSEntry var commandQueue: MTLCommandQueue?
    @MSEntry var commandBuffer: MTLCommandBuffer?
    @MSEntry var renderCommandEncoder: MTLRenderCommandEncoder?
    @MSEntry var renderPassDescriptor: MTLRenderPassDescriptor?
    @MSEntry var renderPipelineDescriptor: MTLRenderPipelineDescriptor?
    @MSEntry var renderPipelineState: MTLRenderPipelineState?
    @MSEntry var vertexDescriptor: MTLVertexDescriptor?
    @MSEntry var depthStencilDescriptor: MTLDepthStencilDescriptor?
    @MSEntry var depthStencilState: MTLDepthStencilState?
    @MSEntry var computeCommandEncoder: MTLComputeCommandEncoder?
    @MSEntry var computePipelineState: MTLComputePipelineState?
    @MSEntry var reflection: Reflection?
    @MSEntry var colorAttachment0: (MTLTexture, Int)?
    @MSEntry var depthAttachment: MTLTexture?
    @MSEntry var stencilAttachment: MTLTexture?
    @MSEntry var currentDrawable: CAMetalDrawable?
    @MSEntry var drawableSize: CGSize?
    @MSEntry var blitCommandEncoder: MTLBlitCommandEncoder?
    @MSEntry var linkedFunctions: MTLLinkedFunctions?
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
    /// Sets a custom depth/stencil descriptor.
    func depthStencilDescriptor(_ depthStencilDescriptor: MTLDepthStencilDescriptor) -> some Element {
        environment(\.depthStencilDescriptor, depthStencilDescriptor)
    }

    /// Configures depth testing for the render pipeline.
    ///
    /// Enable depth testing for 3D rendering:
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
    /// The vertex descriptor tells Metal how to map vertex buffer data
    /// to shader input attributes.
    ///
    /// ```swift
    /// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
    ///     Draw { encoder in ... }
    /// }
    /// .vertexDescriptor(MyVertex.descriptor)
    /// ```
    ///
    /// - Parameter vertexDescriptor: The Metal vertex descriptor.
    func vertexDescriptor(_ vertexDescriptor: MTLVertexDescriptor?) -> some Element {
        environment(\.vertexDescriptor, vertexDescriptor)
    }

    /// Sets the vertex descriptor from a Model I/O descriptor.
    ///
    /// Useful when loading meshes from Model I/O:
    ///
    /// ```swift
    /// .vertexDescriptor(mdlMesh.vertexDescriptor)
    /// ```
    func vertexDescriptor(_ vertexDescriptor: MDLVertexDescriptor) -> some Element {
        self.vertexDescriptor(MTKMetalVertexDescriptorFromModelIO(vertexDescriptor).orFatalError(.resourceCreationFailure("Failed to create MTLVertexDescriptor from MDLVertexDescriptor")))
    }
}

// MARK: - visionOS CompositorServices Support

#if os(visionOS)
public extension MSEnvironmentValues {
    /// The render context for CompositorServices immersive rendering.
    /// When set, RenderPass will use `renderContext.endEncoding(commandEncoder:)` instead of `encoder.endEncoding()`.
    @MSEntry var immersiveRenderContext: LayerRenderer.Drawable.RenderContext?
}

public extension Element {
    /// Sets the immersive render context for CompositorServices rendering.
    /// This enables proper integration with visionOS immersive spaces.
    func immersiveRenderContext(_ renderContext: LayerRenderer.Drawable.RenderContext?) -> some Element {
        environment(\.immersiveRenderContext, renderContext)
    }
}
#endif
