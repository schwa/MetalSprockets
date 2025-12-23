#if os(iOS)
import ARKit
import CoreVideo
import Metal
import MetalSprockets
import simd
import SwiftUI

// MARK: - Public Data

public struct ARFrameData {
    public var textureY: MTLTexture?
    public var textureCbCr: MTLTexture?
    public var textureCoordinates: [SIMD2<Float>] = [[0, 1], [1, 1], [0, 0], [1, 0]]
    public var projectionMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])
    public var viewMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])

    public init() {}

    public var isReady: Bool { textureY != nil && textureCbCr != nil }
}

// MARK: - View Modifier

private struct ARKitFrameModifier: ViewModifier {
    let frame: ARFrame?
    @Binding var frameData: ARFrameData

    @State private var textureCache: CVMetalTextureCache?
    @State private var cvTextureY: CVMetalTexture?
    @State private var cvTextureCbCr: CVMetalTexture?

    func body(content: Content) -> some View {
        content
            .onAppear {
                let device = MTLCreateSystemDefaultDevice()!
                var cache: CVMetalTextureCache?
                CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
                textureCache = cache
            }
            .onChange(of: frame?.timestamp) { _, _ in
                processFrame()
            }
    }

    private func processFrame() {
        guard let frame, let textureCache else { return }

        // ARKit provides YCbCr in a CVPixelBuffer with two planes
        let pixelBuffer = frame.capturedImage
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else { return }

        // Extract Y (luminance) texture from plane 0
        let widthY = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let heightY = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        var newCvTextureY: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .r8Unorm, widthY, heightY, 0, &newCvTextureY)

        // Extract CbCr (chrominance) texture from plane 1
        let widthCbCr = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let heightCbCr = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        var newCvTextureCbCr: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .rg8Unorm, widthCbCr, heightCbCr, 1, &newCvTextureCbCr)

        guard let newCvTextureY, let newCvTextureCbCr else { return }

        // Keep CVMetalTexture alive - MTLTexture is only valid while these are retained
        cvTextureY = newCvTextureY
        cvTextureCbCr = newCvTextureCbCr

        var data = ARFrameData()
        data.textureY = CVMetalTextureGetTexture(newCvTextureY)
        data.textureCbCr = CVMetalTextureGetTexture(newCvTextureCbCr)

        CVMetalTextureCacheFlush(textureCache, 0)

        // Camera sensor is landscape, rotate to match screen orientation
        let interfaceOrientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation ?? .portrait

        let orientationRotation: simd_float4x4
        switch interfaceOrientation {
        case .portrait: orientationRotation = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [0, 0, 1]))
        case .portraitUpsideDown: orientationRotation = simd_float4x4(simd_quatf(angle: .pi / 2, axis: [0, 0, 1]))
        case .landscapeLeft: orientationRotation = simd_float4x4(simd_quatf(angle: .pi, axis: [0, 0, 1]))
        case .landscapeRight: orientationRotation = .init(diagonal: [1, 1, 1, 1])
        @unknown default: orientationRotation = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [0, 0, 1]))
        }
        data.viewMatrix = orientationRotation * frame.camera.transform.inverse

        let viewportSize = UIScreen.main.bounds.size
        data.projectionMatrix = frame.camera.projectionMatrix(for: interfaceOrientation, viewportSize: viewportSize, zNear: 0.01, zFar: 100.0)

        // Transform texture coordinates to match screen orientation
        let displayTransform = frame.displayTransform(for: interfaceOrientation, viewportSize: viewportSize).inverted()
        let baseTexCoords: [CGPoint] = [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0)]
        data.textureCoordinates = baseTexCoords.map { SIMD2<Float>(Float($0.applying(displayTransform).x), Float($0.applying(displayTransform).y)) }

        frameData = data
    }
}

// MARK: - View Extension

public extension View {
    func arkit(frame: ARFrame?, frameData: Binding<ARFrameData>) -> some View {
        modifier(ARKitFrameModifier(frame: frame, frameData: frameData))
    }
}
#endif
