import SwiftUI
import MetalSprockets
import MetalSprocketsUI

struct ContentView: View {
    var body: some View {
        RenderView { _, _ in
            try RedTriangleInline()
        }
        .aspectRatio(1, contentMode: .fill)
    }
}

#Preview {
    ContentView()
}
