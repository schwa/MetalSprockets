#if os(iOS)
import ARKit
import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import Observation
import simd
import SwiftUI

@Observable
@MainActor
final class ARViewModel: NSObject, ARSessionDelegate {
    let session = ARSession()
    var currentFrame: ARFrame?

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        session.run(ARWorldTrackingConfiguration())
    }

    func stop() {
        session.pause()
        currentFrame = nil
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in currentFrame = frame }
    }
}

struct MobileDemoView: View {
    @State private var isARMode = false
    @State private var viewModel = ARViewModel()
    @State private var frameData = ARFrameData()

    var body: some View {
        NavigationStack {
            content
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("AR", systemImage: "arkit") { toggleARMode() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isARMode, let textureY = frameData.textureY, let textureCbCr = frameData.textureCbCr {
            // Capture textures to avoid race during teardown
            let textureCoordinates = frameData.textureCoordinates
            let projectionMatrix = frameData.projectionMatrix
            let viewMatrix = frameData.viewMatrix

            RenderView { context, _ in
                let time = context.frameUniforms.time
                let modelMatrix = float4x4.translation(0, -0.25, -2) * cubeRotationMatrix(time: TimeInterval(time)) * float4x4.scale(0.25, 0.25, 0.25)
                let transform = projectionMatrix * viewMatrix * modelMatrix

                try RenderPass {
                    YCbCrBillboardRenderPass(textureY: textureY, textureCbCr: textureCbCr, textureCoordinates: textureCoordinates)
                    try DemoCubeRenderPipeline(transform: transform, time: time)
                }
            }
            .metalDepthStencilPixelFormat(.depth32Float)
            .metalClearColor(.init(red: 0, green: 0, blue: 0, alpha: 0))
            .arkit(frame: viewModel.currentFrame, frameData: $frameData)
        } else if isARMode {
            ProgressView()
                .arkit(frame: viewModel.currentFrame, frameData: $frameData)
        } else {
            RenderDemoView()
        }
    }

    private func toggleARMode() {
        if isARMode {
            viewModel.stop()
            frameData = ARFrameData()
            isARMode = false
        } else {
            viewModel.start()
            isARMode = true
        }
    }
}

#Preview {
    MobileDemoView()
}
#endif
