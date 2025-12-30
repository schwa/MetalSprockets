import Metal
import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import SwiftUI

/// A demo view that shows side-by-side comparison of rendering with and without MSAA.
///
/// This demo renders the same cube to two textures:
/// - Left side: No MSAA (aliased edges visible)
/// - Right side: 4x MSAA (smooth edges)
///
/// The element-level `.msaa()` modifier is used for render-to-texture MSAA.
struct MSAADemoView: View {
    @State private var elementMSAA = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left: No MSAA
                RenderView { context, size in
                    let time = context.frameUniforms.time
                    let transform = makeTransform(time: time, size: size)

                    try RenderPass {
                        try DemoCubeRenderPipeline(transform: transform, time: time)
                    }
                }
                .metalDepthStencilPixelFormat(.depth32Float)
                .overlay(alignment: .bottom) {
                    Text("No MSAA")
                        .font(.caption.bold())
                        .padding(6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .padding(8)
                }

                Divider()

                // Right: With MSAA via .metalSampleCount()
                RenderView { context, size in
                    let time = context.frameUniforms.time
                    let transform = makeTransform(time: time, size: size)

                    try RenderPass {
                        try DemoCubeRenderPipeline(transform: transform, time: time)
                    }
                }
                .metalDepthStencilPixelFormat(.depth32Float)
                .metalSampleCount(4)
                .overlay(alignment: .bottom) {
                    Text("MSAA 4x")
                        .font(.caption.bold())
                        .padding(6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .padding(8)
                }
            }

            Divider()

            // Instructions
            Text("Compare the cube edges. MSAA smooths jagged edges (aliasing).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("MSAA Comparison")
    }

    private func makeTransform(time: Float, size: CGSize) -> float4x4 {
        let modelMatrix = cubeRotationMatrix(time: TimeInterval(time))
        let viewMatrix = float4x4.translation(0, 0, -8)
        let aspect = size.height > 0 ? Float(size.width / size.height) : 1.0
        let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 100.0)
        return projectionMatrix * viewMatrix * modelMatrix
    }
}

#Preview {
    NavigationStack {
        MSAADemoView()
    }
}
