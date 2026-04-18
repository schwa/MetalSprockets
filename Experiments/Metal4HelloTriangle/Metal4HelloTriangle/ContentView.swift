import MetalKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        MetalView()
    }
}

struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> Renderer {
        let device = MTLCreateSystemDefaultDevice()!
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

    func updateNSView(_ nsView: MTKView, context: Context) {}
}
