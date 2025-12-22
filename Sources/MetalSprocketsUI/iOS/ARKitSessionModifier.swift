#if os(iOS)
import ARKit
import CoreVideo
import Metal
import MetalSprockets
import Observation
import simd
import SwiftUI

// MARK: - ARKit Session Manager

/// Manages ARKit session state, texture extraction, and camera matrix updates.
@Observable
@MainActor
public final class ARKitSessionManager: NSObject {
    public private(set) var textureY: MTLTexture?
    public private(set) var textureCbCr: MTLTexture?
    public private(set) var projectionMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])
    public private(set) var cameraMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])
    public private(set) var viewMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])
    public private(set) var textureCoordinates: [SIMD2<Float>] = [[0, 1], [1, 1], [0, 0], [1, 0]]

    private let session: ARSession
    private var textureCache: CVMetalTextureCache?
    private let device: MTLDevice
    
    // Keep CVMetalTexture alive - MTLTexture is only valid while these are retained
    private var cvTextureY: CVMetalTexture?
    private var cvTextureCbCr: CVMetalTexture?

    public init(session: ARSession) {
        self.session = session
        self.device = MTLCreateSystemDefaultDevice()!

        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        self.textureCache = textureCache

        super.init()

        session.delegate = self
    }

    /// Starts the ARKit session with world tracking configuration.
    public func start() {
        let configuration = ARWorldTrackingConfiguration()
        session.run(configuration)
    }

    /// Pauses the ARKit session.
    public func pause() {
        session.pause()
    }
}

extension ARKitSessionManager: ARSessionDelegate {
    nonisolated public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            updateFromFrame(frame)
        }
    }

    @MainActor
    private func updateFromFrame(_ frame: ARFrame) {
        guard let textureCache else { return }

        let pixelBuffer = frame.capturedImage

        // ARKit provides YCbCr format with two planes
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else { return }

        // Create Y texture (luminance) from plane 0
        let widthY = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let heightY = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)

        var cvMetalTextureY: CVMetalTexture?
        let statusY = CVMetalTextureCacheCreateTextureFromImage(
            nil, textureCache, pixelBuffer, nil,
            .r8Unorm, widthY, heightY, 0, &cvMetalTextureY
        )

        // Create CbCr texture (chrominance) from plane 1
        let widthCbCr = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let heightCbCr = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)

        var cvMetalTextureCbCr: CVMetalTexture?
        let statusCbCr = CVMetalTextureCacheCreateTextureFromImage(
            nil, textureCache, pixelBuffer, nil,
            .rg8Unorm, widthCbCr, heightCbCr, 1, &cvMetalTextureCbCr
        )

        guard statusY == kCVReturnSuccess,
              let cvMetalTextureY,
              statusCbCr == kCVReturnSuccess,
              let cvMetalTextureCbCr
        else { return }

        // Retain the CVMetalTexture objects - MTLTexture is only valid while these live
        cvTextureY = cvMetalTextureY
        cvTextureCbCr = cvMetalTextureCbCr
        
        textureY = CVMetalTextureGetTexture(cvMetalTextureY)
        textureY?.label = "ARKit Camera Y"
        textureCbCr = CVMetalTextureGetTexture(cvMetalTextureCbCr)
        textureCbCr?.label = "ARKit Camera CbCr"
        
        // Flush texture cache to ensure we get fresh textures
        CVMetalTextureCacheFlush(textureCache, 0)

        // Update camera matrix (world transform of the camera)
        cameraMatrix = frame.camera.transform

        // Get interface orientation for display transform and projection
        let interfaceOrientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation ?? .portrait
        
        // Compute view matrix (inverse of camera transform) with orientation correction
        // The camera sensor is physically in landscape orientation, so we need to apply
        // a rotation to align 3D content with the screen orientation
        let orientationRotation: simd_float4x4
        switch interfaceOrientation {
        case .portrait:
            // Rotate -90° around Z axis
            orientationRotation = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [0, 0, 1]))
        case .portraitUpsideDown:
            // Rotate +90° around Z axis
            orientationRotation = simd_float4x4(simd_quatf(angle: .pi / 2, axis: [0, 0, 1]))
        case .landscapeLeft:
            // Rotate 180° around Z axis
            orientationRotation = simd_float4x4(simd_quatf(angle: .pi, axis: [0, 0, 1]))
        case .landscapeRight:
            // No rotation needed (native camera orientation)
            orientationRotation = .init(diagonal: [1, 1, 1, 1])
        @unknown default:
            orientationRotation = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [0, 0, 1]))
        }
        viewMatrix = orientationRotation * cameraMatrix.inverse

        // Get the actual screen size for viewport calculations
        let screenBounds = UIScreen.main.bounds
        let viewportSize = CGSize(width: screenBounds.width, height: screenBounds.height)
        
        // Update projection matrix with screen aspect ratio
        projectionMatrix = frame.camera.projectionMatrix(
            for: interfaceOrientation,
            viewportSize: viewportSize,
            zNear: 0.01,
            zFar: 100.0
        )

        // Calculate display-transformed texture coordinates using screen viewport
        let displayTransform = frame.displayTransform(for: interfaceOrientation, viewportSize: viewportSize).inverted()
        let baseTexCoords: [CGPoint] = [
            CGPoint(x: 0, y: 1),  // bottom-left
            CGPoint(x: 1, y: 1),  // bottom-right
            CGPoint(x: 0, y: 0),  // top-left
            CGPoint(x: 1, y: 0)   // top-right
        ]
        textureCoordinates = baseTexCoords.map { coord in
            let transformed = coord.applying(displayTransform)
            return SIMD2<Float>(Float(transformed.x), Float(transformed.y))
        }
        

    }
}

// MARK: - View Modifier

/// A view modifier that provides ARKit camera background rendering and camera transforms.
public struct ARKitSessionModifier: ViewModifier {
    @Bindable var manager: ARKitSessionManager
    @Binding var projectionMatrix: simd_float4x4
    @Binding var viewMatrix: simd_float4x4

    public init(
        manager: ARKitSessionManager,
        projectionMatrix: Binding<simd_float4x4>,
        viewMatrix: Binding<simd_float4x4>
    ) {
        self.manager = manager
        self._projectionMatrix = projectionMatrix
        self._viewMatrix = viewMatrix
    }

    public func body(content: Content) -> some View {
        content
            .onChange(of: manager.projectionMatrix) { _, newValue in
                projectionMatrix = newValue
            }
            .onChange(of: manager.viewMatrix) { _, newValue in
                viewMatrix = newValue
            }
            .onAppear {
                // Sync initial values
                projectionMatrix = manager.projectionMatrix
                viewMatrix = manager.viewMatrix
            }
    }
}

// MARK: - View Extension

public extension View {
    /// Applies ARKit session transforms to the view, updating the provided bindings
    /// with projection and view matrices from the ARKit session.
    ///
    /// - Parameters:
    ///   - manager: The ARKit session manager that provides camera data.
    ///   - projectionMatrix: A binding to receive the projection matrix updates.
    ///   - viewMatrix: A binding to receive the view matrix updates (includes orientation correction).
    /// - Returns: A view with ARKit session transform updates applied.
    func arkitSessionTransforms(
        manager: ARKitSessionManager,
        projectionMatrix: Binding<simd_float4x4>,
        viewMatrix: Binding<simd_float4x4>
    ) -> some View {
        modifier(ARKitSessionModifier(
            manager: manager,
            projectionMatrix: projectionMatrix,
            viewMatrix: viewMatrix
        ))
    }
}

// MARK: - Environment Key for ARKit Manager

private struct ARKitSessionManagerKey: EnvironmentKey {
    static let defaultValue: ARKitSessionManager? = nil
}

public extension EnvironmentValues {
    var arkitSessionManager: ARKitSessionManager? {
        get { self[ARKitSessionManagerKey.self] }
        set { self[ARKitSessionManagerKey.self] = newValue }
    }
}
#endif
