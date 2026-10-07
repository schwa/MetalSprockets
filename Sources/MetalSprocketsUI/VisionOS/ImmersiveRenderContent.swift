#if os(visionOS)
import ARKit
@preconcurrency import CompositorServices
import Metal
import MetalSprockets
internal import os
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
    let foveation: Bool
    let maximumInFlightSubmissions: Int
    let content: @Sendable (ImmersiveContext) throws -> Content
    var frameTimingChange: (@Sendable (FrameTimingStatistics) -> Void)?
    var renderLoopChange: (@Sendable (Bool) -> Void)?

    /// Creates immersive render content.
    ///
    /// - Parameters:
    ///   - progressive: Enable progressive rendering for complex scenes.
    ///   - maximumInFlightSubmissions: A positive limit. The render loop awaits capacity before submitting.
    ///   - foveation: Render the periphery of the view at lower resolution when the device supports it. Turn it off
    ///     to rule out foveation artifacts (blocky edges, especially on blended content); it costs GPU time.
    ///   - content: A closure that returns the elements to render each frame.
    public init(progressive: Bool = false, maximumInFlightSubmissions: Int = 3, foveation: Bool = true, @ElementBuilder content: @Sendable @escaping (ImmersiveContext) throws -> Content) {
        self.progressive = progressive
        self.foveation = foveation
        self.maximumInFlightSubmissions = maximumInFlightSubmissions
        self.content = content
    }

    public var body: some ImmersiveSpaceContent {
        let renderLoopChange = renderLoopChange
        return CompositorLayer(configuration: ImmersiveLayerConfiguration(progressive: progressive, foveation: foveation)) { layerRenderer in
            // Fire-and-forget: the loop exits when `layerRenderer.state` becomes `.invalidated`, and it also honours
            // cancellation so a cancelled enclosing task can stop it. See #386.
            Task(priority: .high) { @ImmersiveRendererActor in
                renderLoopChange?(true)
                defer { renderLoopChange?(false) }
                do {
                    let runtime = try ImmersiveRuntime(
                        layerRenderer: layerRenderer,
                        progressive: progressive,
                        maximumInFlightSubmissions: maximumInFlightSubmissions,
                        content: content
                    )
                    runtime.frameTimingChange = frameTimingChange
                    try await runtime.renderLoop()
                } catch is CancellationError {
                    logger?.info("ImmersiveRuntime render loop cancelled.")
                } catch {
                    // Always logged: the loop has stopped and the space shows nothing, which is otherwise silent.
                    Logger(subsystem: "io.schwa.metal-sprockets-ui", category: "immersive").error("ImmersiveRuntime failed: \(String(describing: error), privacy: .public)")
                }
            }
        }
    }
}

public extension ImmersiveRenderContent {
    /// Registers a callback that is called every frame with the latest frame timing statistics.
    ///
    /// Use this to feed a ``FrameTimingView`` or log frame performance data from immersive content.
    ///
    /// ```swift
    /// @State var statistics: FrameTimingStatistics?
    ///
    /// ImmersiveRenderContent { context in
    ///     // ...
    /// }
    /// .onFrameTimingChange { statistics = $0 }
    /// ```
    func onFrameTimingChange(perform action: @Sendable @escaping (FrameTimingStatistics) -> Void) -> Self {
        var copy = self
        copy.frameTimingChange = action
        return copy
    }

    /// Registers a callback for the render loop's lifetime: `true` when it starts, `false` when it ends (the layer was
    /// invalidated, e.g. the immersive space closed, however it closed). Called on the render loop's actor.
    func onRenderLoopChange(perform action: @Sendable @escaping (_ isRunning: Bool) -> Void) -> Self {
        var copy = self
        copy.renderLoopChange = action
        return copy
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

    /// Frame timing statistics computed over a rolling window.
    public let frameTimingStatistics: FrameTimingStatistics

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
    var foveation = true

    func makeConfiguration(capabilities: LayerRenderer.Capabilities, configuration: inout LayerRenderer.Configuration) {
        configuration.colorFormat = .rgba16Float
        configuration.depthFormat = .depth32Float
        // MetalSprockets renders only with Metal 4, through the compositor's Metal 4 queue.
        configuration.supportsMTL4 = true

        if foveation, capabilities.supportsFoveation {
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
