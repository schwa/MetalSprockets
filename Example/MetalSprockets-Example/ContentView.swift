import SwiftUI
import MetalSprockets
import MetalSprocketsUI

struct ContentView: View {

    @State
    var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            RenderView { _, _ in
                try ExampleTriangleElement(time: timeline.date.timeIntervalSince(start))
            }
        }
        .aspectRatio(1, contentMode: .fill)
    }
}

#Preview {
    ContentView()
}
