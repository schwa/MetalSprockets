import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import SwiftUI

struct RenderDemoView: View {
    @State private var msaaEnabled = true
    @State private var sampleCount = 4
    @State private var isPaused = false
    @State private var pausedTime: Float = 0

    // Query device for supported MSAA sample counts
    private var supportedSampleCounts: [Int] {
        let device = _MTLCreateSystemDefaultDevice()
        return [2, 4, 8].filter { device.supportsTextureSampleCount($0) }
    }

    var body: some View {
        // RenderView is the bridge between SwiftUI and Metal - closure called every frame
        RenderView { [self] context, size in
            // Use paused time when paused, otherwise use live time and update pausedTime
            let time: Float = isPaused ? pausedTime : {
                let t = context.frameUniforms.time
                Task { @MainActor in pausedTime = t }
                return t
            }()

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
        // MSAA - notice how edges are smoother when enabled
        .metalSampleCount(msaaEnabled ? sampleCount : 1)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPaused.toggle()
                } label: {
                    Label(isPaused ? "Play" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                }
            }
            if isPaused {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        pausedTime += 1.0 / 60.0  // Advance by one frame (~16.67ms at 60fps)
                    } label: {
                        Label("Step", systemImage: "forward.frame.fill")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("MSAA Enabled", isOn: $msaaEnabled)
                    if msaaEnabled {
                        Picker("Sample Count", selection: $sampleCount) {
                            ForEach(supportedSampleCounts, id: \.self) { count in
                                Text("\(count)x").tag(count)
                            }
                        }
                    }
                } label: {
                    Label("MSAA", systemImage: msaaEnabled ? "square.grid.3x3.fill" : "square.grid.3x3")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                // swiftlint:disable:next accessibility_label_for_image
                ShareLink(item: Screenshot(), preview: SharePreview("Screenshot", image: Image(systemName: "photo")))
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text(msaaEnabled ? "MSAA \(sampleCount)x" : "MSAA Off")
                .font(.caption)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding()
        }
    }
}

#Preview {
    RenderDemoView()
}
