import MetalSprocketsUI
import SwiftUI

#if os(visionOS)
import MetalSprockets
#endif

#if os(visionOS)
@Observable
class ImmersiveFrameTiming {
    var statistics: FrameTimingStatistics?
}
#endif

#if os(iOS)
/// The only UIKit hook a SwiftUI app has for limiting rotation: SwiftUI owns the root view controller, so its
/// `supportedInterfaceOrientations` can't be overridden.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// When set, the only orientations the interface may rotate to. See `View.interfaceOrientationLocked(_:)`.
    static var orientationLock: UIInterfaceOrientationMask?

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // `.all` is narrowed by the orientations declared in the Info.plist.
        Self.orientationLock ?? .all
    }
}
#endif

@main
struct MetalSprockets_ExampleApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    #if os(visionOS)
    @State private var immersiveFrameTiming = ImmersiveFrameTiming()
    #endif

    var body: some Scene {
        // Main window with the spinning cube
        WindowGroup {
            ContentView()
                .captureHotKeys { result in
                    print("GPU capture: \(result)")
                }
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
                .gpuTimed("Cube pass")
            }
            .onFrameTimingChange { [immersiveFrameTiming] statistics in
                Task { @MainActor in
                    immersiveFrameTiming.statistics = statistics
                }
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .upperLimbVisibility(.visible)
        #endif
    }
}
