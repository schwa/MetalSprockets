import Metal
import MetalSprockets
import MetalSprocketsUI
import SwiftUI

struct ContentView: View {
    // Track animation start time for consistent timing
    @State private var start = Date()

    #if os(visionOS)
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isImmersive = false
    #endif

    var body: some View {
        VStack {
            // TimelineView drives continuous animation updates
            TimelineView(.animation) { timeline in
                // RenderView bridges SwiftUI and MetalSprockets rendering
                RenderView { _, size in
                    try ExampleCubeElement(time: timeline.date.timeIntervalSince(start), viewportSize: size)
                }
                .ignoresSafeArea()
                .metalDepthStencilPixelFormat(.depth32Float)  // Enable depth buffer
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
}

#Preview {
    ContentView()
}
