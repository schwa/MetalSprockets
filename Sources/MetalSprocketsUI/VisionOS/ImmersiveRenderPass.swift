#if os(visionOS)
import ARKit
import CompositorServices
import Metal
import MetalSprockets
import simd
import SwiftUI

// MARK: - ImmersiveRenderPass

/// A render pass for visionOS immersive spaces with proper stereo setup.
///
/// `ImmersiveRenderPass` wraps a standard ``RenderPass`` with visionOS-specific
/// configuration for stereo rendering and progressive rendering support.
///
/// ## Overview
///
/// Use inside ``ImmersiveRenderContent`` to render 3D content:
///
/// ```swift
/// ImmersiveRenderContent { context in
///     try ImmersiveRenderPass(context: context) {
///         try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///             Draw { encoder in
///                 // Render for each eye
///                 for eye in 0..<context.viewCount {
///                     encoder.setViewport(context.viewports[eye])
///                     // Draw geometry...
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Progressive Rendering
///
/// When progressive rendering is enabled on `ImmersiveRenderContent`,
/// this pass automatically configures stencil masking for efficient
/// partial-frame updates.
///
/// ## Topics
///
/// ### Related Types
/// - ``ImmersiveRenderContent``
/// - ``ImmersiveContext``
/// - ``RenderPass``
public struct ImmersiveRenderPass<Content: Element>: Element {
    let context: ImmersiveContext
    let label: String?
    let content: Content

    /// Creates an immersive render pass.
    ///
    /// - Parameters:
    ///   - context: The immersive context from the render content closure.
    ///   - label: An optional label for debugging (visible in GPU frame capture).
    ///   - content: A closure that returns the elements to render.
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
