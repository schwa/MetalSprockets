#if os(visionOS)
import ARKit
@preconcurrency import CompositorServices
import Metal
import MetalSprockets
import simd
import SwiftUI

public struct ImmersiveRenderPass<Content: Element>: Element {
    let context: ImmersiveContext
    let label: String?
    let content: Content

    public init(context: ImmersiveContext, label: String? = nil, @ElementBuilder content: () throws -> Content) rethrows {
        self.context = context
        self.label = label
        self.content = try content()
    }

    public var body: some Element {
        get throws {
            try RenderPass(label: label) {
                Draw { encoder in
                    if context.isProgressive {
                        context.renderContext.drawMaskOnStencilAttachment(commandEncoder: encoder, value: context.stencilValue)
                        encoder.setStencilReferenceValue(UInt32(context.stencilValue))
                    }
                }
                content
            }
        }
    }
}
#endif
