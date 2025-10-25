import Metal
import MetalKit
import ModelIO
import QuartzCore
import MetalSprocketsSupport

public extension MSEnvironmentValues {
    // TODO: #114 This is messy and needs organisation and possibly deprecation of unused elements.
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

public extension Element {
    func depthStencilDescriptor(_ depthStencilDescriptor: MTLDepthStencilDescriptor) -> some Element {
        environment(\.depthStencilDescriptor, depthStencilDescriptor)
    }

    func depthCompare(function: MTLCompareFunction, enabled: Bool) -> some Element {
        depthStencilDescriptor(.init(depthCompareFunction: function, isDepthWriteEnabled: enabled))
    }
}

public extension Element {
    func vertexDescriptor(_ vertexDescriptor: MTLVertexDescriptor?) -> some Element {
        environment(\.vertexDescriptor, vertexDescriptor)
    }

    func vertexDescriptor(_ vertexDescriptor: MDLVertexDescriptor) -> some Element {
        self.vertexDescriptor(MTKMetalVertexDescriptorFromModelIO(vertexDescriptor).orFatalError(.resourceCreationFailure("Failed to create MTLVertexDescriptor from MDLVertexDescriptor")))
    }
}
