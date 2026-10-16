import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

struct RenderDemoView: View {
    @State private var msaaEnabled = true
    @State private var sampleCount = 4
    @State private var isPaused = false
    @State private var pausedTime: Float = 0
    @State private var frameTimingStatistics: FrameTimingStatistics?
    // More than one cube is a stress test: one draw per cube, unless instancing is on.
    // Persisted, so a profiling run can start with many cubes (`defaults write` or `-cubeCount 1000`).
    @AppStorage("cubeCount") private var cubeCount = 1
    @State private var instanced = false

    private static let cubeCounts = [1, 100, 500, 1_000, 2_000, 5_000]

    // Queried once: this view redraws every frame, so probing the device from `body` would create a device and
    // rebuild this array 60+ times a second.
    private static let supportedSampleCounts: [Int] = {
        let device = _MTLCreateSystemDefaultDevice()
        return [2, 4, 8].filter { device.supportsTextureSampleCount($0) }
    }()

    var body: some View {
        // RenderView is the bridge between SwiftUI and Metal - closure called every frame
        RenderView { context, size in
            let time: Float = isPaused ? pausedTime : context.frameUniforms.time

            // Standard MVP transform chain
            let modelMatrix = cubeRotationMatrix(time: TimeInterval(time))
            let gridSide = Int(ceil(cbrt(Double(cubeCount))))
            let viewMatrix = float4x4.translation(0, 0, -8 * Float(gridSide))
            let aspect = size.height > 0 ? Float(size.width / size.height) : 1.0
            let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 100.0 * Float(gridSide))
            let transforms = cubeGridOffsets(count: cubeCount, side: gridSide).map { offset in
                projectionMatrix * viewMatrix * modelMatrix * float4x4.translation(offset.x, offset.y, offset.z)
            }

            // RenderPass creates a render command encoder, contains one or more pipelines
            try RenderPass(label: "Cube") {
                try DemoCubeRenderPipeline(transforms: transforms, time: time, instanced: instanced)
            }
            // Shown as its own row in the FrameTimingView HUD.
            .gpuTimed("Cube pass")
            .onWorkloadEnter { environment in
                let commandBuffer = try environment.commandBuffer.orThrow(.missingEnvironment(\.commandBuffer))
                commandBuffer.label = "Cube Frame"
            }
        }
        .ignoresSafeArea()
        // Required for depth testing
        .metalDepthStencilPixelFormat(.depth32Float)
        // MSAA - notice how edges are smoother when enabled
        .metalSampleCount(msaaEnabled ? sampleCount : 1)
        .onFrameTimingChange { frameTimingStatistics = $0 }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isPaused ? "Play" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill") {
                    isPaused.toggle()
                }
            }
            if isPaused {
                ToolbarItem(placement: .primaryAction) {
                    Button("Step", systemImage: "forward.frame.fill") {
                        pausedTime += 1.0 / 60.0  // Advance by one frame (~16.67ms at 60fps)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Picker("Cubes", selection: $cubeCount) {
                    ForEach(Self.cubeCounts, id: \.self) { count in
                        Text("\(count) cubes").tag(count)
                    }
                }
                .pickerStyle(.menu)
            }
            ToolbarItem(placement: .primaryAction) {
                Toggle("Instanced", systemImage: "square.stack.3d.up", isOn: $instanced)
                    .help("Draw all cubes in one instanced draw instead of one draw per cube")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("MSAA Enabled", isOn: $msaaEnabled)
                    if msaaEnabled {
                        Picker("Sample Count", selection: $sampleCount) {
                            ForEach(Self.supportedSampleCounts, id: \.self) { count in
                                Text("\(count)x").tag(count)
                            }
                        }
                    }
                } label: {
                    Label("MSAA", systemImage: msaaEnabled ? "square.grid.3x3.fill" : "square.grid.3x3")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                // SharePreview takes an Image, not a View, so there is nowhere to hang an accessibility label; the
                // preview's own "Screenshot" title is what assistive technologies read.
                // swiftlint:disable:next accessibility_label_for_image
                ShareLink(item: Screenshot(), preview: SharePreview("Screenshot", image: Image(systemName: "photo")))
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text(msaaEnabled ? "MSAA \(sampleCount)x" : "MSAA Off")
                .modifier(OverlayBadgeModifier())
        }
        .overlay(alignment: .bottomTrailing) {
            if let frameTimingStatistics {
                FrameTimingView(statistics: frameTimingStatistics, options: .all)
            }
        }
    }
}

/// Centred grid positions, `side` cubes per edge, filled until `count` is reached.
private func cubeGridOffsets(count: Int, side: Int) -> [SIMD3<Float>] {
    let spacing: Float = 3
    let center = Float(side - 1) / 2
    return (0..<count).map { index in
        let x = Float(index % side) - center
        let y = Float((index / side) % side) - center
        let z = Float(index / (side * side)) - center
        return SIMD3(x, y, z) * spacing
    }
}

#Preview {
    RenderDemoView()
}
