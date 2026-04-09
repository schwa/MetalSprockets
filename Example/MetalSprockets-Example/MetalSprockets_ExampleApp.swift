import SwiftUI

#if os(visionOS)
import MetalSprockets
import MetalSprocketsUI
#endif

#if os(visionOS)
@Observable
class ImmersiveFrameTiming {
    var statistics: FrameTimingStatistics?
}
#endif

@main
struct MetalSprockets_ExampleApp: App {
    #if os(visionOS)
    @State private var immersiveFrameTiming = ImmersiveFrameTiming()
    #endif

    var body: some Scene {
        // Main window with the spinning cube
        WindowGroup {
            ContentView()
                #if os(visionOS)
                .environment(immersiveFrameTiming)
                #endif
        }

        #if os(visionOS)
        // Immersive space for mixed reality rendering
        ImmersiveSpace(id: "ImmersiveCube") {
            // ImmersiveRenderContent sets up the CompositorServices render loop
            ImmersiveRenderContent(progressive: false) { context in
                // ImmersiveRenderPass wraps content in a properly configured render pass
                try ImmersiveRenderPass(context: context, label: "Cube") {
                    try ImmersiveCubeContent(context: context)
                }
            }
            .onFrameTimingChange { [weak immersiveFrameTiming] statistics in
                Task { @MainActor in
                    immersiveFrameTiming?.statistics = statistics
                }
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .upperLimbVisibility(.visible)
        #endif
    }
}
