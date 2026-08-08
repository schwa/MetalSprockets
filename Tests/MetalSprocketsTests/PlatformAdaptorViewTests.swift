import MetalKit
@testable import MetalSprocketsUI
import SwiftUI
import Testing

@MainActor
@Suite("PlatformAdaptorView dismantling")
struct PlatformAdaptorViewTests {
    private func makeAdaptor(view: MTKView, dismantle: @escaping (MTKView) -> Void) -> PlatformAdaptorView<MTKView> {
        PlatformAdaptorView<MTKView>(make: { view }, update: { _ in }, dismantle: dismantle)
    }

    @Test func `the coordinator carries the teardown action to the static dismantle`() throws {
        let view = MTKView()
        view.isPaused = false
        let adaptor = makeAdaptor(view: view) { view in
            view.isPaused = true
        }

        let representation = try #require(adaptor.body as? PlatformAdaptorView<MTKView>.Representation)
        representation.makeCoordinator().dismantle(view)

        #expect(view.isPaused)
    }

    @Test func `dismantling defaults to doing nothing`() {
        let view = MTKView()
        view.isPaused = false
        let adaptor = PlatformAdaptorView<MTKView> {
            view
        }
        update: { _ in
        }

        adaptor.dismantle(view)

        #expect(view.isPaused == false)
    }
}
