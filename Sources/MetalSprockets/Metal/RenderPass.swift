import Metal

#if os(visionOS)
import CompositorServices
#endif

// MARK: - RenderPass

/// A container element that creates a Metal render command encoder.
///
/// `RenderPass` establishes the rendering context for child elements. It creates
/// an `MTLRenderCommandEncoder` that pipelines and draw commands use to encode GPU work.
///
/// ## Understanding Passes vs Pipelines
///
/// A **render pass** represents a single set of render targets (color, depth, stencil
/// attachments). Within a pass, you can have multiple **pipelines** with different
/// shader configurations. Each pipeline change is relatively cheap, while starting
/// a new pass requires potentially flushing render targets.
///
/// Use multiple passes when you need different render targets (e.g., shadow maps,
/// post-processing). Use multiple pipelines within a pass for different materials
/// or rendering techniques.
///
/// You can have multiple render passes in a frame, and you can also mix render passes
/// with ``ComputePass`` for hybrid rendering and compute workflows.
///
/// ## Overview
///
/// A render pass must contain one or more ``RenderPipeline`` elements:
///
/// ```swift
/// RenderPass {
///     RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///         Draw { encoder in
///             encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
///         }
///     }
/// }
/// ```
///
/// ## Render Pass Descriptor
///
/// The render pass uses the `renderPassDescriptor` from the environment, which is
/// typically configured by `RenderView` or ``OffscreenRenderer``. You can modify
/// it using render pass descriptor modifiers.
///
/// ## Labels
///
/// Use the `label` parameter for debugging. Labels appear in Xcode's GPU frame capture:
///
/// ```swift
/// RenderPass(label: "Main Scene") {
///     // ...
/// }
/// ```
///
/// ## Topics
///
/// ### Related Elements
/// - ``RenderPipeline``
/// - ``Draw``
public struct RenderPass <Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    private let label: String?
    internal let content: Content

    /// Creates a render pass with the specified content.
    ///
    /// - Parameters:
    ///   - label: An optional label for debugging (visible in GPU frame capture).
    ///   - content: A closure that returns the child elements to render.
    public init(label: String? = nil, @ElementBuilder content: () throws -> Content) throws {
        self.label = label
        self.content = try content()
    }

    func setupEnter(_ node: Node) throws {
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        node.environmentValues.renderPipelineDescriptor = renderPipelineDescriptor
    }

    func workloadEnter(_ node: Node) throws {
        logger?.verbose?.info("Start render pass: \(label ?? "<unlabeled>") (\(node.element.debugName))")
        let commandBuffer = try node.environmentValues.commandBuffer.orThrow(.missingEnvironment(\.commandBuffer))
        let renderPassDescriptor = try node.environmentValues.renderPassDescriptor.orThrow(.missingEnvironment(\.renderPassDescriptor))
        let renderCommandEncoder = try commandBuffer._makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        if let label {
            renderCommandEncoder.label = label
        }
        node.environmentValues.renderCommandEncoder = renderCommandEncoder
    }

    func workloadExit(_ node: Node) throws {
        let renderCommandEncoder = try node.environmentValues.renderCommandEncoder.orThrow(.missingEnvironment(\.renderCommandEncoder))

        #if os(visionOS)
        // Use immersive render context for proper CompositorServices integration
        if let renderContext = node.environmentValues.immersiveRenderContext {
            renderContext.endEncoding(commandEncoder: renderCommandEncoder)
        } else {
            renderCommandEncoder.endEncoding()
        }
        #else
        renderCommandEncoder.endEncoding()
        #endif

        node.environmentValues.renderCommandEncoder = nil
        logger?.verbose?.info("Ending render pass: \(label ?? "<unlabeled>") (\(node.element.debugName))")
    }

    nonisolated func requiresSetup(comparedTo old: RenderPass<Content>) -> Bool {
        // RenderPass creates pipeline descriptor in setup but only creates encoders in workload
        // The descriptor creation is lightweight and should happen on structure changes
        false
    }
}
