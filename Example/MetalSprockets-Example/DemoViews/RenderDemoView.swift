import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import SwiftUI

struct RenderDemoView: View {
    var body: some View {
        // RenderView is the bridge between SwiftUI and Metal - closure called every frame
        RenderView { context, size in
            // Frame timing provided automatically
            let time = context.frameUniforms.time

            // Standard MVP transform chain
            let modelMatrix = cubeRotationMatrix(time: TimeInterval(time))
            let viewMatrix = float4x4.translation(0, 0, -8)
            let aspect = size.height > 0 ? Float(size.width / size.height) : 1.0
            let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 100.0)
            let transform = projectionMatrix * viewMatrix * modelMatrix

            // RenderPass creates a render command encoder, contains one or more pipelines
            try RenderPass {
                try DemoCubeRenderPipeline(transform: transform, time: time)
            }
        }
        .ignoresSafeArea()
        // Required for depth testing
        .metalDepthStencilPixelFormat(.depth32Float)
        .toolbar {
            ShareLink(item: Screenshot(), preview: SharePreview("Screenshot", image: Image(systemName: "photo")))
        }
    }
}

#Preview {
    RenderDemoView()
}
