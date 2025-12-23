import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(visionOS)
        VisionOSDemoView()
        #elseif os(iOS)
        MobileDemoView()
        #else
        RenderDemoView()
        #endif
    }
}

#Preview {
    ContentView()
}
