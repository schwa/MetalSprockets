import Foundation
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import os
import Testing

private struct DeliberateFailure: Error {}

@MainActor
@Suite("Metal 4 debug groups and labels", .requiresMetal4)
struct DebugGroupEncodingTests {
    private let device = MTLCreateSystemDefaultDevice()!

    private func triangle() throws -> some Element {
        let library = try device.makeLibrary(source: CaptureTests.source, options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        return try RenderPipeline(label: "Triangle pipeline", vertexShader: vertex, fragmentShader: fragment) {
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                .debugGroup("Draw triangle")
        }
    }

    private func pass(_ texture: any MTLTexture, @ElementBuilder content: () throws -> some Element) throws -> some Element {
        let descriptor = MTL4RenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        return try RenderPass(label: "Main pass", content: content).renderPassDescriptor(descriptor)
    }

    private func target() throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 32, height: 32, mipmapped: false)
        descriptor.usage = .renderTarget
        return try #require(device.makeTexture(descriptor: descriptor))
    }

    @Test(.timeLimit(.minutes(1)))
    func groupsNestOnEncodersAndCommandBuffers() async throws {
        let texture = try target()
        // Declared with useResource so it stays alive until the GPU fill runs. Freeing it early let the fill land in
        // another test's buffer at the reused address (#440).
        let buffer = try #require(device.makeBuffer(length: 16))
        let content = try Group {
            try pass(texture) { try triangle() }.debugGroup("Frame")
            try ComputePass(label: "Compute pass") {
                ComputeCommand { $0.fill(buffer: buffer, range: 0..<16, value: 1) }
                    .useResource(buffer, usage: .write, stages: [])
                    .debugGroup("Fill")
            }
        }
        // API Validation rejects unbalanced groups when an encoder or the command buffer ends.
        let result = try await FrameRunner(device: device).run(content.debugGroup("Outer"))
        #expect(result.outcome == .completed)
    }

    @Test(.timeLimit(.minutes(1)))
    func aThrownWorkloadUnwindsGroupsAndTheNextFrameStillRenders() async throws {
        let runner = try FrameRunner(device: device)
        let texture = try target()
        let failing = try pass(texture) {
            AnyBodylessElement().onWorkloadEnter { _ in throw DeliberateFailure() }
                .debugGroup("Inner")
        }
        .debugGroup("Outer")
        await #expect(throws: DeliberateFailure.self) {
            _ = try await runner.run(failing)
        }
        let result = try await runner.run(try pass(texture) { try triangle() }.debugGroup("Outer"))
        #expect(result.outcome == .completed)
    }
}

@Suite(
    "Metal 4 shader logging",
    .requiresMetal4,
    .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Metal log state unavailable on CI runners"),
    // Creating any MTLLogState makes Metal refuse captures for the rest of the process.
    .disabled(if: ProcessInfo.processInfo.environment["MTL_CAPTURE_ENABLED"] == "1", "Shader logging disables GPU capture process-wide")
)
struct ShaderLoggingTests {
    @Test(.timeLimit(.minutes(1)))
    func shaderMessagesReachTheHandlerOnlyWhenLoggingIsOn() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let options = MTLCompileOptions()
        options.enableLogging = true
        let library = try await device.makeLibrary(source: """
        #include <metal_stdlib>
        #include <metal_logging>
        using namespace metal;
        kernel void speak(uint id [[thread_position_in_grid]]) {
            if (id == 0) { os_log_default.log("hello from metal four %d", 4); }
        }
        """, options: options)
        let kernel = try ComputeKernel(library: library, name: "speak")
        let content = try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1))
            }
        }
        func waitForMessage(_ messages: OSAllocatedUnfairLock<[String]>) async throws -> Bool {
            // Log handlers run asynchronously after completion.
            for _ in 0..<100 where messages.withLock({ $0.isEmpty }) {
                try await Task.sleep(for: .milliseconds(10))
            }
            return messages.withLock { $0 }.contains { $0.contains("hello from metal four 4") }
        }

        // Through Runner.
        let runnerMessages = OSAllocatedUnfairLock<[String]>(initialState: [])
        let runner = try Runner(device: device, shaderLogging: .handler { message in runnerMessages.withLock { $0.append(message) } })
        #expect(runner.context.logState != nil)
        try runner.run(content)
        #expect(try await waitForMessage(runnerMessages))

        // Through OffscreenRenderer (its root carries the same option).
        let offscreenMessages = OSAllocatedUnfairLock<[String]>(initialState: [])
        let offscreen = try OffscreenRenderer(size: CGSize(width: 8, height: 8), device: device, shaderLogging: .handler { message in offscreenMessages.withLock { $0.append(message) } })
        _ = try offscreen.render(content)
        #expect(try await waitForMessage(offscreenMessages))

        // Off unless asked for, or unless the process sets MS_METAL_LOGGING=1.
        #expect(try Runner(device: device, shaderLogging: .disabled).context.logState == nil)
        #expect((ShaderLogging.processDefault.configuration != nil) == SystemEnvironment.current.metalLoggingEnabled)
        #expect((try Runner(device: device).context.logState != nil) == SystemEnvironment.current.metalLoggingEnabled)
    }
}

/// Capture needs `MTL_CAPTURE_ENABLED=1`; without it the capturing cases have nothing to exercise and return early.
@MainActor
@Suite("Metal 4 capture", .serialized, .requiresMetal4)
struct CaptureTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(0, 0.75), float2(-0.75, -0.75), float2(0.75, -0.75) };
        VertexOut out;
        out.position = float4(positions[id], 0, 1);
        return out;
    }
    [[fragment]] float4 fragment_main() { return float4(1, 0, 0, 1); }
    """

    private let device = MTLCreateSystemDefaultDevice()!
    private let manager = MTLCaptureManager.shared()

    /// A labeled render pass with a debug-grouped draw. Capture must wrap passes on Metal 4, so tests run it through
    /// `FrameRunner` rather than `TestOffscreenRenderer`, which puts content inside its own pass.
    private func frame() throws -> some Element {
        let library = try device.makeLibrary(source: Self.source, options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 32, height: 32, mipmapped: false)
        textureDescriptor.usage = .renderTarget
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = device.makeTexture(descriptor: textureDescriptor)
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        return try RenderPass(label: "Captured pass") {
            try RenderPipeline(label: "Capture pipeline", vertexShader: vertex, fragmentShader: fragment) {
                Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                    .debugGroup("Captured draw")
            }
        }.renderPassDescriptor(pass)
        .debugGroup("Captured frame")
    }

    /// The capture ends from the submission's terminal handler, which can run just after the awaited result returns.
    private func run(_ content: some Element) async throws {
        defer { waitForCaptureToEnd() }
        let result = try await FrameRunner(device: device).run(content)
        #expect(result.outcome == .completed)
    }

    private func waitForCaptureToEnd() {
        for _ in 0..<200 where manager.isCapturing {
            Thread.sleep(forTimeInterval: 0.005)
        }
    }

    private func traceURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("trace.gputrace")
    }

    @Test(.timeLimit(.minutes(1)))
    func disabledAndUnsupportedCapturesAreNoOps() async throws {
        try await run(try frame().capture(false, destination: .gpuTraceDocument))
        if !manager.supportsDestination(.developerTools) {
            try await run(try frame().capture(true, destination: .developerTools))
        }
        #expect(!manager.isCapturing)
    }

    @Test(.timeLimit(.minutes(1)))
    func captureInsideAPassIsRejectedBeforeCapturing() async throws {
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 32, height: 32))
        await #expect(throws: MetalSprocketsError.self) {
            _ = try await renderer.render(EmptyElement().capture(destination: .gpuTraceDocument, outputURL: try traceURL()))
        }
        #expect(!manager.isCapturing)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [CaptureTarget.device, .commandQueue])
    func captureWritesATraceCoveringTheSubmission(target: CaptureTarget) async throws {
        guard manager.supportsDestination(.gpuTraceDocument) else {
            return
        }
        let url = try traceURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await run(try frame().capture(target: target, destination: .gpuTraceDocument, outputURL: url))
        #expect(!manager.isCapturing)
        #expect(FileManager.default.fileExists(atPath: url.path))
        if let keep = ProcessInfo.processInfo.environment["METALSPROCKETS_KEEP_TRACE"] {
            let destination = URL(fileURLWithPath: keep).appendingPathComponent("metal4-\(target).gputrace")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: url, to: destination)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func missingOutputURLIsAConfigurationError() async throws {
        guard manager.supportsDestination(.gpuTraceDocument) else {
            return
        }
        await #expect(throws: MetalSprocketsError.self) {
            try await run(try frame().capture(destination: .gpuTraceDocument))
        }
        #expect(!manager.isCapturing)
    }

    @Test(.timeLimit(.minutes(1)))
    func aCaptureOwnedElsewhereIsNeitherNestedNorStopped() async throws {
        guard manager.supportsDestination(.gpuTraceDocument) else {
            return
        }
        let url = try traceURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let descriptor = MTLCaptureDescriptor()
        descriptor.destination = .gpuTraceDocument
        descriptor.captureObject = device
        descriptor.outputURL = url
        try manager.startCapture(with: descriptor)
        defer {
            if manager.isCapturing {
                manager.stopCapture()
            }
        }
        let result = try await FrameRunner(device: device).run(try frame().capture(destination: .gpuTraceDocument, outputURL: try traceURL()))
        #expect(result.outcome == .completed)
        #expect(manager.isCapturing)
    }

    @Test(.timeLimit(.minutes(1)))
    func aThrownWorkloadStillEndsTheCapture() async throws {
        guard manager.supportsDestination(.gpuTraceDocument) else {
            return
        }
        let url = try traceURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let failing = try Group {
            try frame()
            AnyBodylessElement().onWorkloadEnter { _ in throw DeliberateFailure() }
        }
        await #expect(throws: DeliberateFailure.self) {
            try await run(failing.capture(destination: .gpuTraceDocument, outputURL: url))
        }
        #expect(!manager.isCapturing)
    }
}
