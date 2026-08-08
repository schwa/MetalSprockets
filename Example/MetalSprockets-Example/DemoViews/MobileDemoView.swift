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
            Group {
                if isARMode {
                    ARDemoView(frame: viewModel.currentFrame, frameData: $frameData)
                } else {
                    RenderDemoView()
                }
            }
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("AR", systemImage: "arkit") { toggleARMode() }
                }
            }
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

// MARK: - ARDemoView

/// Renders the demo cube composited over the ARKit camera feed.
struct ARDemoView: View {
    var frame: ARFrame?
    @Binding var frameData: ARFrameData

    var body: some View {
        Group {
            if let textureY = frameData.textureY, let textureCbCr = frameData.textureCbCr {
                // Read out of `frameData` once, so the closure captures this frame's textures rather than racing
                // with the next ARKit update (or with teardown).
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
            } else {
                ProgressView("Starting camera…")
            }
        }
        // Stays attached in both states: the modifier is what turns ARKit frames into the textures the first branch
        // is waiting for.
        .arkit(frame: frame, frameData: $frameData)
    }
}

#Preview("AR, waiting for camera") {
    @Previewable @State var frameData = ARFrameData()
    ARDemoView(frame: nil, frameData: $frameData)
}
#endif
