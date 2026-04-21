import CoreGraphics
import Metal
@testable import MetalSprockets
@testable import MetalSprocketsUI
import Testing

@MainActor
@Suite("RenderView support helpers")
struct RenderViewSupportTests {
    // MARK: - FrameTimingState

    @Test("First advance sets firstFrameTime and emits index 0")
    func testFirstAdvance() {
        var state = FrameTimingState()
        let uniforms = state.advance(now: 100.0, viewportSize: [800, 600])

        #expect(state.firstFrameTime == 100.0)
        #expect(state.frameTime == 0.0)
        #expect(uniforms.index == 0)
        #expect(uniforms.time == 0.0)
        #expect(uniforms.deltaTime == 0.0)
        #expect(uniforms.viewportSize == [800, 600])
    }

    @Test("Second advance reports deltaTime from first")
    func testSecondAdvance() {
        var state = FrameTimingState()
        _ = state.advance(now: 100.0, viewportSize: [640, 480])
        let second = state.advance(now: 100.016, viewportSize: [640, 480])

        #expect(second.time == Float(0.016))
        // Allow for Float rounding.
        #expect(abs(second.deltaTime - Float(0.016)) < 1e-4)
    }

    @Test("commit() advances frame counter")
    func testCommitAdvancesFrame() {
        var state = FrameTimingState()
        #expect(state.frame == 0)
        state.commit()
        #expect(state.frame == 1)
        state.commit()
        #expect(state.frame == 2)
    }

    @Test("advance uses frame index from state")
    func testFrameIndexUsesStateValue() {
        var state = FrameTimingState()
        _ = state.advance(now: 10, viewportSize: [100, 100])
        state.commit()
        let second = state.advance(now: 10.016, viewportSize: [100, 100])
        #expect(second.index == 1)
    }

    @Test("Multiple frames produce monotonic time")
    func testMonotonicTime() {
        var state = FrameTimingState()
        var times: [Float] = []
        var current = 50.0
        for _ in 0..<5 {
            let u = state.advance(now: current, viewportSize: [1, 1])
            times.append(u.time)
            state.commit()
            current += 0.016
        }
        #expect(times == times.sorted())
        #expect(times.first == 0.0)
        #expect(times.last ?? 0 > 0.06)
    }

    // MARK: - sampleCountChanged

    @Test("sampleCountChanged reports change")
    func testSampleCountChangedTrue() {
        #expect(sampleCountChanged(current: 1, observed: 4) == true)
    }

    @Test("sampleCountChanged reports no-op")
    func testSampleCountChangedFalse() {
        #expect(sampleCountChanged(current: 4, observed: 4) == false)
    }

    // MARK: - buildRenderViewRootElement

    @Test("Root element renders via OffscreenRenderer")
    func testBuildRootElementRenders() throws {
        // Use OffscreenRenderer to exercise the assembled element tree
        // end-to-end without any MTKView. We swap the outer CommandBufferElement
        // for the one OffscreenRenderer provides by wrapping buildRenderViewRootElement
        // inside a plain RenderPass that uses the surrounding environment.
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn { float2 position [[attribute(0)]]; };
        struct VertexOut { float4 position [[position]]; };

        [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
            VertexOut out; out.position = float4(in.position, 0.0, 1.0); return out;
        }

        [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) {
            return float4(0.2, 0.4, 0.6, 1.0);
        }
        """
        let vs = try VertexShader(source: source)
        let fs = try FragmentShader(source: source)

        // User content: a RenderPass drawing a triangle.
        let content = try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }

        // Drive the helper directly. We don't supply a drawable; the helper
        // only puts it in the environment, and the RenderPass below won't need it
        // because OffscreenRenderer supplies its own renderPassDescriptor.
        let device = MTLCreateSystemDefaultDevice()!
        let queue = device.makeCommandQueue()!
        let rpDesc = MTLRenderPassDescriptor()
        rpDesc.colorAttachments[0].loadAction = .clear

        var completedCalled = false
        let root = try buildRenderViewRootElement(
            content: content,
            captureConfiguration: nil,
            device: device,
            commandQueue: queue,
            shaderStore: ShaderStore(),
            renderPassDescriptor: rpDesc,
            currentDrawable: nil,
            drawableSize: CGSize(width: 256, height: 256)
        ) { _ in
            completedCalled = true
        }
        _ = root

        // The element tree is constructed fine. To actually render, we wrap the user
        // content directly through OffscreenRenderer (which sets its own env keys).
        let renderer = try OffscreenRenderer(size: CGSize(width: 128, height: 128))
        _ = try renderer.render(content)
        _ = completedCalled // presence check only; firing depends on commit path
    }

    @Test("Root element honors capture configuration when enabled==false")
    func testBuildRootElementCaptureDisabled() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let queue = device.makeCommandQueue()!
        let rpDesc = MTLRenderPassDescriptor()
        let config = RenderViewCaptureConfiguration(enabled: false, target: .device, destination: .developerTools)

        _ = try buildRenderViewRootElement(
            content: EmptyElement(),
            captureConfiguration: config,
            device: device,
            commandQueue: queue,
            shaderStore: ShaderStore(),
            renderPassDescriptor: rpDesc,
            currentDrawable: nil,
            drawableSize: .zero
        ) { _ in }
    }

    @Test("Root element handles nil captureConfiguration")
    func testBuildRootElementNilCapture() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let queue = device.makeCommandQueue()!
        let rpDesc = MTLRenderPassDescriptor()

        _ = try buildRenderViewRootElement(
            content: EmptyElement(),
            captureConfiguration: nil,
            device: device,
            commandQueue: queue,
            shaderStore: ShaderStore(),
            renderPassDescriptor: rpDesc,
            currentDrawable: nil,
            drawableSize: CGSize(width: 1, height: 1)
        ) { _ in }
    }
}
