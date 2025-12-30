#if os(visionOS)
import ARKit
@preconcurrency import CompositorServices
import Metal
import MetalSprockets
import simd
import SwiftUI

// MARK: - ImmersiveRenderContent

/// Content for visionOS immersive spaces using MetalSprockets rendering.
///
/// Use `ImmersiveRenderContent` to render Metal content in a visionOS
/// immersive space with proper stereo rendering and head tracking.
///
/// ## Overview
///
/// Create an immersive space that uses MetalSprockets for rendering:
///
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         ImmersiveSpace(id: "ImmersiveScene") {
///             ImmersiveRenderContent { context in
///                 try ImmersiveRenderPass(context: context) {
///                     try MyImmersiveElement(context: context)
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Stereo Rendering
///
/// The `ImmersiveContext` provides per-eye view and projection matrices:
///
/// ```swift
/// struct MyImmersiveElement: Element {
///     let context: ImmersiveContext
///
///     var body: some Element {
///         RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///             Draw { encoder in
///                 for eye in 0..<context.viewCount {
///                     let viewMatrix = context.viewMatrix(eye: eye)
///                     let projMatrix = context.projectionMatrix(eye: eye)
///                     // Render for this eye...
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Progressive Rendering
///
/// Enable progressive rendering for complex scenes:
///
/// ```swift
/// ImmersiveRenderContent(progressive: true) { context in
///     // Content renders progressively across frames
/// }
/// ```
///
/// ## Topics
///
/// ### Related Types
/// - ``ImmersiveContext``
/// - ``ImmersiveRenderPass``
public struct ImmersiveRenderContent<Content: Element>: ImmersiveSpaceContent {
    let progressive: Bool
    let content: @Sendable (ImmersiveContext) throws -> Content

    /// Creates immersive render content.
    ///
    /// - Parameters:
    ///   - progressive: Enable progressive rendering for complex scenes.
    ///   - content: A closure that returns the elements to render each frame.
    public init(progressive: Bool = false, @ElementBuilder content: @Sendable @escaping (ImmersiveContext) throws -> Content) {
        self.progressive = progressive
        self.content = content
    }

    public var body: some ImmersiveSpaceContent {
        CompositorLayer(configuration: ImmersiveLayerConfiguration(progressive: progressive)) { layerRenderer in
            Task(priority: .high) { @ImmersiveRendererActor in
                do {
                    let runtime = try ImmersiveRuntime(
                        layerRenderer: layerRenderer,
                        progressive: progressive,
                        content: content
                    )
                    try await runtime.renderLoop()
                } catch {
                    print("ImmersiveRuntime failed: \(error)")
                }
            }
        }
    }
}

// MARK: - ImmersiveContext

/// Per-frame context for visionOS immersive rendering.
///
/// Provides access to stereo rendering data, head tracking, and timing
/// information needed to render content in an immersive space.
///
/// ## Stereo Rendering
///
/// Use `viewCount` to iterate over eyes and get per-eye matrices:
///
/// ```swift
/// for eye in 0..<context.viewCount {
///     let view = context.viewMatrix(eye: eye)
///     let projection = context.projectionMatrix(eye: eye)
///     let viewport = context.viewports[eye]
///     // Render this eye...
/// }
/// ```
///
/// ## Head Tracking
///
/// The `deviceAnchor` provides the current head position and orientation,
/// which is already incorporated into the view matrices.
public struct ImmersiveContext: Sendable {
    /// The Metal device for resource creation.
    public let device: MTLDevice

    /// Elapsed time in seconds since rendering started.
    public let time: TimeInterval

    /// The current drawable from CompositorServices.
    public let drawable: LayerRenderer.Drawable

    /// The current device (head) anchor, if available.
    public let deviceAnchor: DeviceAnchor?

    /// The number of views to render (typically 2 for stereo).
    public var viewCount: Int { drawable.views.count }

    /// The viewport for each eye.
    public var viewports: [MTLViewport] { drawable.views.map(\.textureMap.viewport) }

    internal let renderContext: LayerRenderer.Drawable.RenderContext

    /// Whether progressive rendering is enabled.
    public let isProgressive: Bool

    internal let stencilValue: UInt8

    /// The stencil format used for progressive rendering.
    public let stencilFormat: MTLPixelFormat

    /// Returns the view matrix for the specified eye.
    ///
    /// - Parameter eye: The eye index (0 for left, 1 for right).
    /// - Returns: The view matrix incorporating head tracking.
    public func viewMatrix(eye: Int) -> simd_float4x4 {
        let deviceTransform = deviceAnchor?.originFromAnchorTransform ?? matrix_identity_float4x4
        return (deviceTransform * drawable.views[eye].transform).inverse
    }

    /// Returns the projection matrix for the specified eye.
    ///
    /// - Parameter eye: The eye index (0 for left, 1 for right).
    /// - Returns: The projection matrix for proper stereo rendering.
    public func projectionMatrix(eye: Int) -> simd_float4x4 {
        drawable.computeProjection(convention: .rightUpBack, viewIndex: eye)
    }
}

// MARK: - ImmersiveRenderPass

// MARK: - Layer Configuration

internal struct ImmersiveLayerConfiguration: CompositorLayerConfiguration {
    let progressive: Bool

    func makeConfiguration(capabilities: LayerRenderer.Capabilities, configuration: inout LayerRenderer.Configuration) {
        configuration.colorFormat = .rgba16Float
        configuration.depthFormat = .depth32Float

        if capabilities.supportsFoveation {
            configuration.isFoveationEnabled = true
        }

        let options: LayerRenderer.Capabilities.SupportedLayoutsOptions =
            configuration.isFoveationEnabled ? [.foveationEnabled] : []
        let supportedLayouts = capabilities.supportedLayouts(options: options)
        configuration.layout = supportedLayouts.contains(.layered) ? .layered : .shared

        if progressive, configuration.layout == .layered {
            if capabilities.drawableRenderContextSupportedStencilFormats.contains(.stencil8) {
                configuration.drawableRenderContextStencilFormat = .stencil8
            }
            configuration.drawableRenderContextRasterSampleCount = 1
        }
    }
}
#endif
