#if os(iOS)
import ARKit
import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import SwiftUI

struct MobileDemoView: View {
    @State private var isARMode = false
    @State private var arSession = ARSession()
    @State private var arkitManager: ARKitSessionManager?
    // Updated each frame by arkitSessionTransforms modifier
    @State private var projectionMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])
    @State private var viewMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])

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
        // ARKit provides YCbCr camera textures
        if isARMode, let manager = arkitManager, let textureY = manager.textureY, let textureCbCr = manager.textureCbCr {
            RenderView { context, _ in
                let time = context.frameUniforms.time

                // Position in world space: 2m forward, 0.25m down, 25cm cube
                let modelMatrix = float4x4.translation(0, -0.25, -2) * cubeRotationMatrix(time: TimeInterval(time)) * float4x4.scale(0.25, 0.25, 0.25)
                // ARKit matrices for correct AR placement
                let transform = projectionMatrix * viewMatrix * modelMatrix

                try RenderPass {
                    // Render camera feed as fullscreen background (converts YCbCr to RGB)
                    YCbCrBillboardRenderPass(textureY: textureY, textureCbCr: textureCbCr, textureCoordinates: manager.textureCoordinates)

                    // 3D content renders on top with depth testing
                    try DemoCubeRenderPipeline(transform: transform, time: time)
                }
            }
            .metalDepthStencilPixelFormat(.depth32Float)
            .metalClearColor(.init(red: 0, green: 0, blue: 0, alpha: 0))
            // Syncs ARKit camera matrices to @State bindings each frame
            .arkitSessionTransforms(manager: manager, projectionMatrix: $projectionMatrix, viewMatrix: $viewMatrix)
        } else {
            RenderDemoView()
        }
    }

    private func toggleARMode() {
        if isARMode {
            arkitManager?.pause()
            arkitManager = nil
            isARMode = false
        } else {
            let manager = ARKitSessionManager(session: arSession)
            manager.start()
            arkitManager = manager
            isARMode = true
        }
    }
}

#Preview {
    MobileDemoView()
}
#endif
