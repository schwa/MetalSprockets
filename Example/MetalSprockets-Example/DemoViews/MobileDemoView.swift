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
                    ARDemoView(session: viewModel.session, frame: viewModel.currentFrame, frameData: $frameData)
                } else {
                    RenderDemoView()
                }
            }
            // No `.ignoresSafeArea()` here: each demo extends only its render view under the bars, so its overlays
            // stay clear of the toolbar, which sits on the side on iPhone Duo.
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("AR", systemImage: "arkit") { toggleARMode() }
                }
            }
        }
        // Rotating mid-session reorients the camera feed and the cube under the user, so AR keeps the interface in
        // whichever orientation it started in.
        .interfaceOrientationLocked(isARMode)
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

// MARK: - Orientation lock

extension View {
    /// While `isLocked` is true, stops the interface rotating away from the orientation it's in.
    func interfaceOrientationLocked(_ isLocked: Bool) -> some View {
        background(InterfaceOrientationLockView(isLocked: isLocked))
    }
}

/// Reaches the window this view is in, so the lock pins that scene's current orientation, and asks its root view
/// controller to re-read the supported orientations from `AppDelegate`.
private struct InterfaceOrientationLockView: UIViewRepresentable {
    var isLocked: Bool

    func makeUIView(context: Context) -> LockView {
        let view = LockView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: LockView, context: Context) {
        view.isLocked = isLocked
    }

    final class LockView: UIView {
        var isLocked = false {
            didSet {
                if isLocked != oldValue {
                    apply()
                }
            }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window else {
                return
            }
            if isLocked, let orientation = window.windowScene?.effectiveGeometry.interfaceOrientation {
                AppDelegate.orientationLock = UIInterfaceOrientationMask(orientation)
            } else {
                AppDelegate.orientationLock = nil
            }
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

private extension UIInterfaceOrientationMask {
    init(_ orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: self = .portrait
        }
    }
}

// MARK: - ARDemoView

/// Renders the demo cube composited over the ARKit camera feed.
struct ARDemoView: View {
    var session: ARSession
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
                .ignoresSafeArea()
                .metalDepthStencilPixelFormat(.depth32Float)
                .metalClearColor(.init(red: 0, green: 0, blue: 0, alpha: 0))
            } else {
                ProgressView("Starting camera…")
            }
        }
        // Stays attached in both states: the modifier is what turns ARKit frames into the textures the first branch
        // is waiting for.
        .arkit(session: session, frame: frame, frameData: $frameData)
    }
}

#Preview("AR, waiting for camera") {
    @Previewable @State var frameData = ARFrameData()
    ARDemoView(session: ARSession(), frame: nil, frameData: $frameData)
}
#endif
