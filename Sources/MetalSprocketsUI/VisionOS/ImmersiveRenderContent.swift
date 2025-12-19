#if os(visionOS)
import ARKit
@preconcurrency import CompositorServices
import Metal
import MetalSprockets
import simd
import SwiftUI

public struct ImmersiveRenderContent<Content: Element>: ImmersiveSpaceContent {

    let progressive: Bool
    let content: @Sendable (ImmersiveContext) throws -> Content

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
public struct ImmersiveContext: Sendable {
    public let device: MTLDevice
    public let time: TimeInterval
    public let drawable: LayerRenderer.Drawable
    public let deviceAnchor: DeviceAnchor?
    public var viewCount: Int { drawable.views.count }
    public var viewports: [MTLViewport] { drawable.views.map(\.textureMap.viewport) }
    internal let renderContext: LayerRenderer.Drawable.RenderContext
    public let isProgressive: Bool
    internal let stencilValue: UInt8
    public let stencilFormat: MTLPixelFormat

    public func viewMatrix(eye: Int) -> simd_float4x4 {
        let deviceTransform = deviceAnchor?.originFromAnchorTransform ?? matrix_identity_float4x4
        return (deviceTransform * drawable.views[eye].transform).inverse
    }

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
