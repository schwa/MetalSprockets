import MetalKit
import SwiftUI

internal struct ContentView: View {
    var body: some View {
        MetalView()
    }
}

internal struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> Renderer {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("No Metal device available.")
        }
        return Renderer(device: device)
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        view.framebufferOnly = false
        view.preferredFramesPerSecond = 60
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Nothing to update; the renderer owns all mutable state.
    }
}
