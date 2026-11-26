#if os(iOS)
import ARKit
import CoreVideo
import Metal
import MetalSprockets
import simd
import SwiftUI

// MARK: - ARFrameData

/// Camera frame data extracted from ARKit for Metal rendering.
///
/// Contains the camera textures, matrices, and texture coordinates needed
/// to render the AR camera background and position 3D content correctly.
///
/// ## Overview
///
/// Use with the `.arkit(frame:frameData:)` modifier to process ARKit frames:
///
/// ```swift
/// struct ARView: View {
///     @State private var frameData = ARFrameData()
///     @State private var session = ARSessionManager()
///
///     var body: some View {
///         RenderView { context, size in
///             if frameData.isReady {
///                 try RenderPass {
///                     // Render camera background
///                     YCbCrBillboardRenderPass(
///                         textureY: frameData.textureY!,
///                         textureCbCr: frameData.textureCbCr!,
///                         textureCoordinates: frameData.textureCoordinates
///                     )
///                     // Render 3D content using view/projection matrices
///                 }
///             }
///         }
///         .arkit(frame: session.currentFrame, frameData: $frameData)
///     }
/// }
/// ```
///
/// ## Properties
///
/// - `textureY`: Luminance texture (r8Unorm)
/// - `textureCbCr`: Chrominance texture (rg8Unorm)
/// - `textureCoordinates`: UV coordinates adjusted for screen orientation
/// - `viewMatrix`: Camera view matrix for 3D rendering
/// - `projectionMatrix`: Camera projection matrix
///
/// ## See Also
///
/// - ``YCbCrBillboardRenderPass``
public struct ARFrameData {
    /// The Y (luminance) texture from the camera in r8Unorm format.
    public var textureY: MTLTexture?

    /// The CbCr (chrominance) texture from the camera in rg8Unorm format.
    public var textureCbCr: MTLTexture?

    /// Texture coordinates for the camera quad, adjusted for screen orientation.
    /// Order: bottom-left, bottom-right, top-left, top-right.
    public var textureCoordinates: [SIMD2<Float>] = [[0, 1], [1, 1], [0, 0], [1, 0]]

    /// The projection matrix from ARKit, adjusted for screen orientation.
    public var projectionMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])

    /// The view matrix (inverse camera transform), adjusted for screen orientation.
    public var viewMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])

    /// The `CVMetalTexture`s backing the textures. The textures are valid only while these live, so a renderer keeps
    /// them until its GPU work finishes.
    package var textureOwners: [AnyObject] = []

    /// Creates empty frame data.
    public init() {
        // This line intentionally left blank.
    }

    /// Returns `true` when both camera textures are available.
    public var isReady: Bool { textureY != nil && textureCbCr != nil }
}

// MARK: - View Modifier

private struct ARKitFrameModifier: ViewModifier {
    /// When supplied, the session is told which layer shows the camera image, and its `viewRotationAngle` drives the
    /// camera matrices. Without it the modifier falls back to the scene's interface orientation.
    let session: ARSession?
    let frame: ARFrame?
    @Binding var frameData: ARFrameData

    @Environment(\.device)
    private var environmentDevice

    @State private var textureCache: CVMetalTextureCache?
    @State private var cvTextureY: CVMetalTexture?
    @State private var cvTextureCbCr: CVMetalTexture?

    /// Size of the view this modifier is attached to, in points. ARKit's `projectionMatrix(for:viewportSize:)` and
    /// `displayTransform(for:viewportSize:)` want the size of the surface the camera image is being fitted to, which
    /// is this view — not the screen. Reading `UIScreen.main.bounds` here produced a wrong fit under Split View,
    /// Stage Manager, and on external displays.
    @State private var viewportSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                viewportSize = size
            }
            .background {
                if let session {
                    ARSessionViewLayerView(session: session)
                }
            }
            .onAppear {
                // Prefer the device from the environment so the textures live on the same device the RenderView
                // draws with; fall back to the system default when nothing was supplied. See #55.
                // swiftlint:disable:next MTLCreateSystemDefaultDevice
                guard let device = environmentDevice ?? MTLCreateSystemDefaultDevice() else {
                    return
                }
                var cache: CVMetalTextureCache?
                CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
                textureCache = cache
            }
            .onChange(of: frame?.timestamp) { _, _ in
                processFrame()
            }
    }

    private func processFrame() {
        guard let frame, let textureCache else {
            return
        }
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return
        }

        // ARKit provides YCbCr in a CVPixelBuffer with two planes
        let pixelBuffer = frame.capturedImage
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else {
            return
        }

        let widthY = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let heightY = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        var newCvTextureY: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .r8Unorm, widthY, heightY, 0, &newCvTextureY)

        let widthCbCr = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let heightCbCr = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        var newCvTextureCbCr: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .rg8Unorm, widthCbCr, heightCbCr, 1, &newCvTextureCbCr)

        guard let newCvTextureY, let newCvTextureCbCr else {
            return
        }

        // Keep CVMetalTexture alive - MTLTexture is only valid while these are retained
        cvTextureY = newCvTextureY
        cvTextureCbCr = newCvTextureCbCr

        var data = ARFrameData()
        data.textureY = CVMetalTextureGetTexture(newCvTextureY)
        data.textureCbCr = CVMetalTextureGetTexture(newCvTextureCbCr)
        data.textureOwners = [newCvTextureY, newCvTextureCbCr]

        CVMetalTextureCacheFlush(textureCache, 0)

        let displayTransform: CGAffineTransform
        if #available(iOS 27, *), let viewRotationAngle = session?.viewRotationAngle {
            // The session measures the rotation of the layer the image is drawn on. Unlike an interface orientation
            // this stays correct when the camera and the display aren't in the usual relationship — such as on each
            // of iPhone Duo's displays.
            data.viewMatrix = frame.camera.viewMatrix(viewRotationAngle: viewRotationAngle)
            data.projectionMatrix = frame.camera.projectionMatrix(viewRotationAngle: viewRotationAngle, viewportSize: viewportSize, zNear: 0.01, zFar: 100.0)
            displayTransform = frame.displayTransform(viewRotationAngle: viewRotationAngle, viewportSize: viewportSize).inverted()
        } else {
            displayTransform = applyInterfaceOrientation(frame: frame, to: &data)
        }
        let baseTexCoords: [CGPoint] = [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint.zero, CGPoint(x: 1, y: 0)]
        data.textureCoordinates = baseTexCoords.map { SIMD2<Float>(Float($0.applying(displayTransform).x), Float($0.applying(displayTransform).y)) }

        frameData = data
    }

    /// Sets the camera matrices from the scene's interface orientation, and returns the inverted display transform.
    /// Used before iOS 27, or until the session reports a view rotation angle.
    private func applyInterfaceOrientation(frame: ARFrame, to data: inout ARFrameData) -> CGAffineTransform {
        // Camera sensor is landscape, rotate to match screen orientation
        // effectiveGeometry replaces the deprecated UIWindowScene.interfaceOrientation.
        let interfaceOrientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.effectiveGeometry.interfaceOrientation ?? .portrait

        let orientationRotation: simd_float4x4
        switch interfaceOrientation {
        case .portrait: orientationRotation = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [0, 0, 1]))
        case .portraitUpsideDown: orientationRotation = simd_float4x4(simd_quatf(angle: .pi / 2, axis: [0, 0, 1]))
        case .landscapeLeft: orientationRotation = simd_float4x4(simd_quatf(angle: .pi, axis: [0, 0, 1]))
        case .landscapeRight: orientationRotation = .init(diagonal: [1, 1, 1, 1])
        case .unknown: orientationRotation = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [0, 0, 1]))
        @unknown default: orientationRotation = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [0, 0, 1]))
        }
        data.viewMatrix = orientationRotation * frame.camera.transform.inverse

        data.projectionMatrix = frame.camera.projectionMatrix(for: interfaceOrientation, viewportSize: viewportSize, zNear: 0.01, zFar: 100.0)

        return frame.displayTransform(for: interfaceOrientation, viewportSize: viewportSize).inverted()
    }
}

/// An empty view, sized and placed like the AR content, whose layer is given to `ARSession.viewLayer`. The session
/// needs a layer on screen where the camera image is shown before it can report `viewRotationAngle`.
private struct ARSessionViewLayerView: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if #available(iOS 27, *) {
            session.viewLayer = uiView.layer
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Processes ARKit frames and extracts data for Metal rendering.
    ///
    /// Attach this modifier to your view hierarchy to automatically convert
    /// ARKit camera frames into Metal-compatible textures and matrices.
    ///
    /// - Parameters:
    ///   - frame: The current ARFrame from your ARSession.
    ///   - frameData: A binding to store the extracted frame data.
    ///
    /// ## Example
    ///
    /// ```swift
    /// RenderView { context, size in
    ///     // Use frameData for rendering
    /// }
    /// .arkit(frame: arSession.currentFrame, frameData: $frameData)
    /// ```
    func arkit(frame: ARFrame?, frameData: Binding<ARFrameData>) -> some View {
        modifier(ARKitFrameModifier(session: nil, frame: frame, frameData: frameData))
    }

    /// Processes ARKit frames and extracts data for Metal rendering, orienting the camera with the session's view
    /// rotation angle.
    ///
    /// Prefer this over ``arkit(frame:frameData:)``. On iOS 27 and later it registers this view as the session's
    /// `viewLayer` and uses `ARSession.viewRotationAngle`, which is correct on devices where the camera and the
    /// display aren't in the usual relationship, such as iPhone Duo. Earlier systems fall back to the interface
    /// orientation.
    ///
    /// - Parameters:
    ///   - session: The session producing `frame`.
    ///   - frame: The current ARFrame from `session`.
    ///   - frameData: A binding to store the extracted frame data.
    func arkit(session: ARSession, frame: ARFrame?, frameData: Binding<ARFrameData>) -> some View {
        modifier(ARKitFrameModifier(session: session, frame: frame, frameData: frameData))
    }
}
#endif
