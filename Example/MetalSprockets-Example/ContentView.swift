import Metal
import MetalSprockets
import MetalSprocketsUI
import simd
import SwiftUI

#if os(iOS)
import ARKit
#endif

struct ContentView: View {
    // Track animation start time for consistent timing
    @State private var start = Date()

    #if os(visionOS)
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isImmersive = false
    #endif

    #if os(iOS)
    @State private var isARMode = false
    @State private var arSession = ARSession()
    @State private var arkitManager: ARKitSessionManager?
    @State private var projectionMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])
    @State private var viewMatrix: simd_float4x4 = .init(diagonal: [1, 1, 1, 1])
    #endif

    var body: some View {
        #if os(iOS)
        NavigationStack {
            mainContent
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            toggleARMode()
                        } label: {
                            Label(
                                isARMode ? "Exit AR" : "Enter AR",
                                systemImage: isARMode ? "arkit" : "arkit"
                            )
                        }
                    }
                }
        }
        #else
        mainContent
        #endif
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack {
            // TimelineView drives continuous animation updates
            TimelineView(.animation) { timeline in
                #if os(iOS)
                if isARMode, let manager = arkitManager,
                   let textureY = manager.textureY,
                   let textureCbCr = manager.textureCbCr {
                    // AR Mode: render with camera background
                    RenderView { _, size in
                        try ARKitCubeElement(
                            time: timeline.date.timeIntervalSince(start),
                            textureY: textureY,
                            textureCbCr: textureCbCr,
                            textureCoordinates: manager.textureCoordinates,
                            projectionMatrix: projectionMatrix,
                            viewMatrix: viewMatrix
                        )
                    }
                    .ignoresSafeArea()
                    .metalDepthStencilPixelFormat(.depth32Float)
                    .metalClearColor(.init(red: 0, green: 0, blue: 0, alpha: 0))
                    .arkitSessionTransforms(
                        manager: manager,
                        projectionMatrix: $projectionMatrix,
                        viewMatrix: $viewMatrix
                    )
                } else {
                    // Standard rendering
                    standardRenderView(timeline: timeline)
                }
                #else
                standardRenderView(timeline: timeline)
                #endif
            }

            #if os(visionOS)
            Button(isImmersive ? "Exit Immersive" : "Enter Immersive") {
                Task {
                    if isImmersive {
                        await dismissImmersiveSpace()
                        isImmersive = false
                    } else {
                        let result = await openImmersiveSpace(id: "ImmersiveCube")
                        if case .opened = result {
                            isImmersive = true
                        }
                    }
                }
            }
            .padding()
            #endif
        }
    }

    @ViewBuilder
    private func standardRenderView(timeline: TimelineViewDefaultContext) -> some View {
        RenderView { _, size in
            try ExampleCubeElement(time: timeline.date.timeIntervalSince(start), viewportSize: size)
        }
        .ignoresSafeArea()
        .metalDepthStencilPixelFormat(.depth32Float)
    }

    #if os(iOS)
    private func toggleARMode() {
        if isARMode {
            // Exit AR mode
            arkitManager?.pause()
            arkitManager = nil
            isARMode = false
        } else {
            // Enter AR mode
            let manager = ARKitSessionManager(session: arSession)
            manager.start()
            arkitManager = manager
            isARMode = true
        }
    }
    #endif
}

#Preview {
    ContentView()
}
