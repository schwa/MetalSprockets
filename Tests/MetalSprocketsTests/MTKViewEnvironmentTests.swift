import Metal
import MetalKit
@testable import MetalSprocketsUI
import SwiftUI
import Testing

@MainActor
@Suite("MTKView configure(from:) Tests")
struct MTKViewEnvironmentTests {
    private func makeView() -> MTKView {
        let device = MTLCreateSystemDefaultDevice()!
        return MTKView(frame: .zero, device: device)
    }

    @Test("nil environment values leave MTKView defaults untouched")
    func testNoOverrides() {
        let view = makeView()
        let originalSampleCount = view.sampleCount
        let originalClearDepth = view.clearDepth

        view.configure(from: EnvironmentValues())

        #expect(view.sampleCount == originalSampleCount)
        #expect(view.clearDepth == originalClearDepth)
    }

    @Test("metalColorPixelFormat is applied")
    func testColorPixelFormat() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalColorPixelFormat = .rgba16Float
        view.configure(from: env)
        #expect(view.colorPixelFormat == .rgba16Float)
    }

    @Test("metalDepthStencilPixelFormat is applied")
    func testDepthStencilPixelFormat() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalDepthStencilPixelFormat = .depth32Float
        view.configure(from: env)
        #expect(view.depthStencilPixelFormat == .depth32Float)
    }

    @Test("metalSampleCount is applied")
    func testSampleCount() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalSampleCount = 4
        view.configure(from: env)
        #expect(view.sampleCount == 4)
    }

    @Test("metalClearColor is applied")
    func testClearColor() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalClearColor = MTLClearColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0)
        view.configure(from: env)
        #expect(view.clearColor.red == 0.1)
        #expect(view.clearColor.green == 0.2)
        #expect(view.clearColor.blue == 0.3)
    }

    @Test("metalClearDepth is applied")
    func testClearDepth() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalClearDepth = 0.5
        view.configure(from: env)
        #expect(view.clearDepth == 0.5)
    }

    @Test("metalClearStencil is applied")
    func testClearStencil() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalClearStencil = 42
        view.configure(from: env)
        #expect(view.clearStencil == 42)
    }

    @Test("metalPreferredFramesPerSecond is applied")
    func testPreferredFramesPerSecond() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalPreferredFramesPerSecond = 120
        view.configure(from: env)
        #expect(view.preferredFramesPerSecond == 120)
    }

    @Test("metalEnableSetNeedsDisplay is applied")
    func testEnableSetNeedsDisplay() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalEnableSetNeedsDisplay = true
        view.configure(from: env)
        #expect(view.enableSetNeedsDisplay == true)
    }

    @Test("metalAutoResizeDrawable is applied")
    func testAutoResizeDrawable() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalAutoResizeDrawable = false
        view.configure(from: env)
        #expect(view.autoResizeDrawable == false)
    }

    @Test("metalIsPaused is applied")
    func testIsPaused() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalIsPaused = true
        view.configure(from: env)
        #expect(view.isPaused == true)
    }

    @Test("metalFramebufferOnly is applied")
    func testFramebufferOnly() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalFramebufferOnly = false
        view.configure(from: env)
        #expect(view.framebufferOnly == false)
    }

    @Test("metalPresentsWithTransaction is applied")
    func testPresentsWithTransaction() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalPresentsWithTransaction = true
        view.configure(from: env)
        #expect(view.presentsWithTransaction == true)
    }

    @Test("metalDepthStencilAttachmentTextureUsage is applied")
    func testDepthStencilAttachmentTextureUsage() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalDepthStencilAttachmentTextureUsage = [.renderTarget, .shaderRead]
        view.configure(from: env)
        #expect(view.depthStencilAttachmentTextureUsage.contains(.renderTarget))
        #expect(view.depthStencilAttachmentTextureUsage.contains(.shaderRead))
    }

    @Test("metalMultisampleColorAttachmentTextureUsage is applied")
    func testMultisampleColorAttachmentTextureUsage() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalMultisampleColorAttachmentTextureUsage = [.renderTarget]
        view.configure(from: env)
        #expect(view.multisampleColorAttachmentTextureUsage.contains(.renderTarget))
    }

    @Test("metalDepthStencilStorageMode is applied")
    func testDepthStencilStorageMode() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalDepthStencilStorageMode = .private
        view.configure(from: env)
        #expect(view.depthStencilStorageMode == .private)
    }

    #if os(macOS)
    @Test("metalColorspace is applied (macOS only)")
    func testColorspace() {
        let view = makeView()
        var env = EnvironmentValues()
        let space = CGColorSpace(name: CGColorSpace.displayP3)
        env.metalColorspace = space
        view.configure(from: env)
        #expect(view.colorspace === space)
    }
    #endif

    @Test("Multiple overrides apply together")
    func testMultipleOverrides() {
        let view = makeView()
        var env = EnvironmentValues()
        env.metalSampleCount = 4
        env.metalColorPixelFormat = .bgra8Unorm_srgb
        env.metalDepthStencilPixelFormat = .depth32Float
        env.metalPreferredFramesPerSecond = 60
        env.metalClearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.configure(from: env)

        #expect(view.sampleCount == 4)
        #expect(view.colorPixelFormat == .bgra8Unorm_srgb)
        #expect(view.depthStencilPixelFormat == .depth32Float)
        #expect(view.preferredFramesPerSecond == 60)
    }
}
