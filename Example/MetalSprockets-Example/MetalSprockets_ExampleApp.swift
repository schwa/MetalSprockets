import SwiftUI

#if os(visionOS)
import MetalSprockets
import MetalSprocketsUI
#endif

@main
struct MetalSprockets_ExampleApp: App {
    var body: some Scene {
        // Main window with the spinning cube
        WindowGroup {
            ContentView()
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
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .upperLimbVisibility(.visible)
        #endif
    }
}
