import Metal
import MetalSprockets
@testable import MetalSprocketsUI
import SwiftUI
import Testing
import ViewInspector

@MainActor
@Suite("ViewInspector smoke tests")
struct ViewInspectorTests {
    private func renderView() -> RenderView<EmptyElement> {
        RenderView { _, _ in
            EmptyElement()
        }
    }

    // MARK: - MTKView environment keys

    @Test("metalSampleCount")
    func testMetalSampleCount() throws {
        let v = renderView().metalSampleCount(4)
        #expect(try v.inspect().environment(\.metalSampleCount) == 4)
    }

    @Test("metalColorPixelFormat")
    func testMetalColorPixelFormat() throws {
        let v = renderView().metalColorPixelFormat(.bgra8Unorm_srgb)
        #expect(try v.inspect().environment(\.metalColorPixelFormat) == .bgra8Unorm_srgb)
    }

    @Test("metalDepthStencilPixelFormat")
    func testMetalDepthStencilPixelFormat() throws {
        let v = renderView().metalDepthStencilPixelFormat(.depth32Float)
        #expect(try v.inspect().environment(\.metalDepthStencilPixelFormat) == .depth32Float)
    }

    @Test("metalClearColor")
    func testMetalClearColor() throws {
        let color = MTLClearColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0)
        let v = renderView().metalClearColor(color)
        let got = try v.inspect().environment(\.metalClearColor)
        #expect(got?.red == 0.1)
        #expect(got?.green == 0.2)
        #expect(got?.blue == 0.3)
    }

    @Test("metalClearDepth")
    func testMetalClearDepth() throws {
        let v = renderView().metalClearDepth(0.5)
        #expect(try v.inspect().environment(\.metalClearDepth) == 0.5)
    }

    @Test("metalClearStencil")
    func testMetalClearStencil() throws {
        let v = renderView().metalClearStencil(7)
        #expect(try v.inspect().environment(\.metalClearStencil) == 7)
    }

    @Test("metalPreferredFramesPerSecond")
    func testMetalPreferredFramesPerSecond() throws {
        let v = renderView().metalPreferredFramesPerSecond(120)
        #expect(try v.inspect().environment(\.metalPreferredFramesPerSecond) == 120)
    }

    @Test("metalEnableSetNeedsDisplay")
    func testMetalEnableSetNeedsDisplay() throws {
        let v = renderView().metalEnableSetNeedsDisplay(true)
        #expect(try v.inspect().environment(\.metalEnableSetNeedsDisplay) == true)
    }

    @Test("metalAutoResizeDrawable")
    func testMetalAutoResizeDrawable() throws {
        let v = renderView().metalAutoResizeDrawable(false)
        #expect(try v.inspect().environment(\.metalAutoResizeDrawable) == false)
    }

    @Test("metalIsPaused")
    func testMetalIsPaused() throws {
        let v = renderView().metalIsPaused(true)
        #expect(try v.inspect().environment(\.metalIsPaused) == true)
    }

    @Test("metalFramebufferOnly")
    func testMetalFramebufferOnly() throws {
        let v = renderView().metalFramebufferOnly(false)
        #expect(try v.inspect().environment(\.metalFramebufferOnly) == false)
    }

    @Test("metalPresentsWithTransaction")
    func testMetalPresentsWithTransaction() throws {
        let v = renderView().metalPresentsWithTransaction(true)
        #expect(try v.inspect().environment(\.metalPresentsWithTransaction) == true)
    }

    @Test("metalDepthStencilAttachmentTextureUsage")
    func testMetalDepthStencilAttachmentTextureUsage() throws {
        let v = renderView().metalDepthStencilAttachmentTextureUsage([.renderTarget, .shaderRead])
        let got = try v.inspect().environment(\.metalDepthStencilAttachmentTextureUsage)
        #expect(got?.contains(.renderTarget) == true)
        #expect(got?.contains(.shaderRead) == true)
    }

    @Test("metalMultisampleColorAttachmentTextureUsage")
    func testMetalMultisampleColorAttachmentTextureUsage() throws {
        let v = renderView().metalMultisampleColorAttachmentTextureUsage([.renderTarget])
        let got = try v.inspect().environment(\.metalMultisampleColorAttachmentTextureUsage)
        #expect(got?.contains(.renderTarget) == true)
    }

    @Test("metalDepthStencilStorageMode")
    func testMetalDepthStencilStorageMode() throws {
        let v = renderView().metalDepthStencilStorageMode(.private)
        #expect(try v.inspect().environment(\.metalDepthStencilStorageMode) == .private)
    }

    #if os(macOS)
    @Test("metalColorspace (macOS)")
    func testMetalColorspace() throws {
        let space = CGColorSpace(name: CGColorSpace.displayP3)
        let v = renderView().metalColorspace(space)
        let got = try v.inspect().environment(\.metalColorspace)
        #expect(got === space)
    }
    #endif

    // MARK: - RenderView-specific view modifiers

    @Test("onDrawableSizeChange stores callback in environment")
    func testOnDrawableSizeChange() throws {
        var capturedSize: CGSize = .zero
        let v = renderView().onDrawableSizeChange { capturedSize = $0 }
        let callback = try v.inspect().environment(\.drawableSizeChange)
        callback?(CGSize(width: 640, height: 480))
        #expect(capturedSize == CGSize(width: 640, height: 480))
    }

    @Test("onFrameTimingChange stores callback in environment")
    func testOnFrameTimingChange() throws {
        var fired = false
        let v = renderView().onFrameTimingChange { _ in fired = true }
        let callback = try v.inspect().environment(\.frameTimingChange)
        callback?(FrameTimingStatistics(
            currentFPS: 60,
            deltaTime: 1.0 / 60,
            averageDeltaTime: 1.0 / 60,
            minDeltaTime: 1.0 / 60,
            maxDeltaTime: 1.0 / 60,
            frameCount: 1
        ))
        #expect(fired == true)
    }

    // MARK: - View.capture() env wiring

    @Test("RenderView.capture() writes RenderViewCaptureConfiguration")
    func testCaptureConfiguration() throws {
        let v = renderView().capture(true, target: .commandQueue, destination: .developerTools)
        let config = try v.inspect().environment(\.renderViewCapture)
        #expect(config?.enabled == true)
        #expect(config?.target == .commandQueue)
        #expect(config?.destination == .developerTools)
    }

    @Test("RenderView.capture(false) still records disabled config")
    func testCaptureDisabledConfiguration() throws {
        let v = renderView().capture(false)
        let config = try v.inspect().environment(\.renderViewCapture)
        #expect(config?.enabled == false)
    }

    // MARK: - Combining multiple modifiers

    @Test("Multiple modifiers stack and all reach environment")
    func testMultipleModifiersStack() throws {
        let v = renderView()
            .metalSampleCount(4)
            .metalDepthStencilPixelFormat(.depth32Float)
            .metalColorPixelFormat(.bgra8Unorm_srgb)
            .metalPreferredFramesPerSecond(60)
        let inspection = try v.inspect()
        #expect(try inspection.environment(\.metalSampleCount) == 4)
        #expect(try inspection.environment(\.metalDepthStencilPixelFormat) == .depth32Float)
        #expect(try inspection.environment(\.metalColorPixelFormat) == .bgra8Unorm_srgb)
        #expect(try inspection.environment(\.metalPreferredFramesPerSecond) == 60)
    }
}
