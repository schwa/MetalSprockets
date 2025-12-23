#if os(visionOS)
import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import SwiftUI

struct VisionOSDemoView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isImmersive = false

    var body: some View {
        VStack {
            if !isImmersive {
                RenderView { context, size in
                    let time = context.frameUniforms.time

                    let modelMatrix = cubeRotationMatrix(time: TimeInterval(time))
                    let viewMatrix = float4x4.translation(0, 0, -8)
                    let aspect = size.height > 0 ? Float(size.width / size.height) : 1.0
                    let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 100.0)
                    let transform = projectionMatrix * viewMatrix * modelMatrix

                    try RenderPass {
                        try DemoCubeRenderPipeline(transform: transform, time: time)
                    }
                }
                .metalDepthStencilPixelFormat(.depth32Float)
            } else {
                Spacer()
            }

            Button(isImmersive ? "Exit Immersive" : "Enter Immersive") {
                Task {
                    if isImmersive {
                        await dismissImmersiveSpace()
                        isImmersive = false
                    } else {
                        let result = await openImmersiveSpace(id: "ImmersiveCube")
                        if case .opened = result { isImmersive = true }
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    VisionOSDemoView()
}
#endif
