import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("Capture Modifier Tests")
struct CaptureModifierTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]]
    ) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]]
    ) {
        return float4(1.0, 0.0, 0.0, 1.0);
    }
    """

    private func makeTriangleRenderPass() throws -> some Element {
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        return try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
    }

    @Test("Capture disabled is a no-op")
    func testCaptureDisabled() throws {
        let pass = try makeTriangleRenderPass().capture(false)
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("Capture with unsupported destination logs a warning and does not throw")
    func testCaptureUnsupportedDestination() throws {
        // In the test harness MTL_CAPTURE_ENABLED is not set, so
        // MTLCaptureManager.supportsDestination(.developerTools) returns false.
        // The modifier should log a warning and render normally without throwing.
        let pass = try makeTriangleRenderPass().capture(true, target: .device, destination: .developerTools)
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("Capture with commandQueue target")
    func testCaptureCommandQueueTarget() throws {
        // Still hits the unsupported-destination early-return (captures are disabled in tests),
        // but exercises the .commandQueue branch validation.
        let pass = try makeTriangleRenderPass().capture(true, target: .commandQueue, destination: .developerTools)
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("A capture scope writes a .gputrace when given an output URL")
    func testCaptureEnabledPath() throws {
        let manager = MTLCaptureManager.shared()
        // Only reachable when the host was launched with MTL_CAPTURE_ENABLED=1.
        guard manager.supportsDestination(.gpuTraceDocument) else {
            return
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureModifierTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let outputURL = directory.appendingPathComponent("trace.gputrace")

        let pass = try makeTriangleRenderPass().capture(true, target: .device, destination: .gpuTraceDocument, outputURL: outputURL)
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)

        #expect(manager.isCapturing == false)
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }

    @Test("A .gpuTraceDocument capture without an output URL is reported")
    func testCaptureGPUTraceDocumentWithoutOutputURL() throws {
        let manager = MTLCaptureManager.shared()
        guard manager.supportsDestination(.gpuTraceDocument) else {
            return
        }
        let pass = try makeTriangleRenderPass().capture(true, target: .device, destination: .gpuTraceDocument)
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        #expect(throws: MetalSprocketsError.self) {
            _ = try renderer.render(pass)
        }
    }

    @Test("A nested capture scope is skipped")
    func testCaptureAlreadyCapturing() throws {
        let manager = MTLCaptureManager.shared()
        guard manager.supportsDestination(.gpuTraceDocument) else {
            return
        }
        let device = try #require(MTLCreateSystemDefaultDevice())

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureModifierTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = MTLCaptureDescriptor()
        descriptor.destination = .gpuTraceDocument
        descriptor.captureObject = device
        descriptor.outputURL = directory.appendingPathComponent("outer.gputrace")
        // Capturing can still be refused for reasons outside this test's control (e.g. shader logging having been
        // used earlier in the run), in which case there is nothing to nest inside.
        guard (try? manager.startCapture(with: descriptor)) != nil else {
            try? FileManager.default.removeItem(at: directory)
            return
        }
        defer {
            if manager.isCapturing {
                manager.stopCapture()
            }
            try? FileManager.default.removeItem(at: directory)
        }

        let pass = try makeTriangleRenderPass().capture(true, target: .device, destination: .gpuTraceDocument)
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)

        // The outer capture is still the one in charge: the modifier neither started nor stopped a capture.
        #expect(manager.isCapturing)
    }

    @Test("CaptureModifier.requiresSetup is false")
    func testCaptureRequiresSetupIsFalse() throws {
        struct Leaf: Element, BodylessElement { var body: Never { fatalError() } }
        let a = CaptureModifier(content: Leaf(), enabled: true, target: .device, destination: .developerTools, outputURL: nil)
        let b = CaptureModifier(content: Leaf(), enabled: false, target: .device, destination: .developerTools, outputURL: nil)
        #expect(a.requiresSetup(comparedTo: b) == false)
    }
}
