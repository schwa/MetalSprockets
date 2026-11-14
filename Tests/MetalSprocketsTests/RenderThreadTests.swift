import CoreGraphics
import Foundation
import Metal
@testable import MetalSprockets
@testable import MetalSprocketsUI
import os
import Synchronization
import Testing

#if os(macOS)
import AppKit
#endif

@MainActor
@Suite("RenderView render thread (#560)", .requiresMetal4)
struct RenderThreadTests {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    [[vertex]] float4 vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(0, 0.5), float2(-0.5, -0.5), float2(0.5, -0.5) };
        return float4(positions[id], 0, 1);
    }
    [[fragment]] float4 fragment_main() { return float4(1, 0, 0, 1); }
    """

    /// Records the thread its last reference was dropped on.
    private final class ReleaseProbe: Sendable {
        let releasedOnMainThread: OSAllocatedUnfairLock<Bool?>

        init(_ releasedOnMainThread: OSAllocatedUnfairLock<Bool?>) {
            self.releasedOnMainThread = releasedOnMainThread
        }

        deinit {
            releasedOnMainThread.withLock { $0 = Thread.isMainThread }
        }
    }

    private func makeView(device: any MTLDevice, frame: CGRect = CGRect(x: 0, y: 0, width: 64, height: 64)) -> MetalLayerView {
        let view = MetalLayerView(frame: frame, device: device)
        view.enableSetNeedsDisplay = true
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = 4
        view.drawableSize = CGSize(width: frame.width, height: frame.height)
        view.renderThread = RenderThread()
        return view
    }

    private func makeViewModel(device: any MTLDevice, recordContentThread: (@Sendable (Bool) -> Void)? = nil) throws -> RenderViewViewModel<some Element> {
        let commandQueue = try #require(device.makeMTL4CommandQueue())
        let vertexShader = try VertexShader(source: Self.source)
        let fragmentShader = try FragmentShader(source: Self.source)
        nonisolated(unsafe) let shaders = (vertexShader, fragmentShader)
        return RenderViewViewModel(device: device, commandQueue: commandQueue, rendersOffMainThread: true) { @Sendable _, _ in
            recordContentThread?(Thread.isMainThread)
            return try RenderPass {
                try RenderPipeline(vertexShader: shaders.0, fragmentShader: shaders.1) {
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                }
            }
        }
    }

    /// Waits for the render thread to finish its queue, then for the main-thread callbacks it scheduled.
    private func settle(_ view: MetalLayerView) async throws {
        let thread = try #require(view.renderThread)
        await withCheckedContinuation { continuation in
            thread.perform {
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    private func waitForExit(_ thread: RenderThread) async throws {
        for _ in 0..<200 where thread.isRunning {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!thread.isRunning)
    }

    @Test(.timeLimit(.minutes(1)))
    func `frames run on the render thread and report back on the main thread`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let contentThreads = Mutex<[Bool]>([])
        let viewModel = try makeViewModel(device: device) { isMain in
            contentThreads.withLock { $0.append(isMain) }
        }
        var timingCallbacksOnMain: [Bool] = []
        var sizes: [CGSize] = []
        viewModel.frameTimingChange = { _ in timingCallbacksOnMain.append(Thread.isMainThread) }
        viewModel.drawableSizeChange = { sizes.append($0) }
        view.delegate = viewModel

        let frameCount = 10
        for _ in 0..<frameCount {
            view.draw()
        }
        try await settle(view)

        #expect(viewModel.lastError == nil)
        #expect(contentThreads.withLock { $0 } == Array(repeating: false, count: frameCount))
        #expect(!timingCallbacksOnMain.isEmpty)
        // #expect cannot infer a key path root here.
        // swiftlint:disable:next prefer_key_path
        #expect(timingCallbacksOnMain.allSatisfy { $0 })
        #expect(sizes == [CGSize(width: 64, height: 64)])

        view.drawableSize = CGSize(width: 96, height: 48)
        view.draw()
        try await settle(view)
        #expect(viewModel.lastError == nil)
        #expect(sizes == [CGSize(width: 64, height: 64), CGSize(width: 96, height: 48)])

        view.tearDown()
    }

    @Test(.timeLimit(.minutes(1)))
    func `teardown drains in-flight frames and releases the owner on the render thread`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let thread = try #require(view.renderThread)
        var viewModel = Optional(try makeViewModel(device: device))
        view.delegate = viewModel
        for _ in 0..<3 {
            view.draw()
        }
        try await settle(view)
        let runner = try #require(viewModel).runner()

        let releasedOnMainThread = OSAllocatedUnfairLock<Bool?>(initialState: nil)
        var probe: ReleaseProbe? = ReleaseProbe(releasedOnMainThread)
        view.tearDown(releasing: probe)
        probe = nil
        viewModel = nil
        try await waitForExit(thread)

        #expect(runner.context.inFlightCount == 0)
        #expect(releasedOnMainThread.withLock { $0 } == false)
    }

    #if os(macOS)
    @Test(.timeLimit(.minutes(1)))
    func `a view released without teardown stops its display link and render thread`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 64, height: 64), styleMask: [.borderless], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        weak var weakView: MetalLayerView?
        let thread: RenderThread = try autoreleasepool {
            let view = makeView(device: device)
            view.enableSetNeedsDisplay = false
            weakView = view
            // Joining a window starts the display link on the render thread.
            window.contentView = view
            window.contentView = nil
            return try #require(view.renderThread)
        }
        #expect(weakView == nil)
        try await waitForExit(thread)
    }
    #endif

    @Test(.timeLimit(.minutes(1)))
    func `a frame takes its size and sample count from its attachments`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let viewModel = try makeViewModel(device: device)
        view.delegate = viewModel
        view.draw()
        try await settle(view)
        #expect(viewModel.currentSampleCount == 4)
        #expect(viewModel.currentDrawableSize == CGSize(width: 64, height: 64))

        view.sampleCount = 1
        view.drawableSize = CGSize(width: 32, height: 16)
        view.draw()
        try await settle(view)
        #expect(viewModel.lastError == nil)
        #expect(viewModel.currentSampleCount == 1)
        #expect(viewModel.currentDrawableSize == CGSize(width: 32, height: 16))
        view.tearDown()
    }
}
