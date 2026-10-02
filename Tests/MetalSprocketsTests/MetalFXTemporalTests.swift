#if canImport(MetalFX) && !os(visionOS)
import Metal
import MetalFX
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

private func temporalSupported() -> Bool {
    guard let device = MTLCreateSystemDefaultDevice() else {
        return false
    }
    return device.supportsFamily(.metal4) && MTLFXTemporalScalerDescriptor.supportsMetal4FX(device)
}

/// Temporal upscaling through the Metal 4 scaler: inputs produced, scaled and read back in one submission per frame.
@MainActor
@Suite("Metal 4 MetalFX temporal", .requiresMetal4, .enabled(if: temporalSupported(), "Requires Metal 4 and supportsMetal4FX"))
struct MetalFXTemporalTests {
    private let device = MTLCreateSystemDefaultDevice()!

    private struct Textures {
        var input: any MTLTexture
        var depth: any MTLTexture
        var motion: any MTLTexture
        var output: any MTLTexture
        var readback: any MTLTexture
    }

    private func texture(_ format: MTLPixelFormat, _ size: Int, usage: MTLTextureUsage, storage: MTLStorageMode = .private) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: size, height: size, mipmapped: false)
        descriptor.usage = usage
        descriptor.storageMode = storage
        return try #require(device.makeTexture(descriptor: descriptor))
    }

    private func textures(input inputSize: Int, output outputSize: Int) throws -> Textures {
        Textures(
            input: try texture(.rgba16Float, inputSize, usage: [.renderTarget, .shaderRead]),
            depth: try texture(.depth32Float, inputSize, usage: [.renderTarget, .shaderRead]),
            motion: try texture(.rg16Float, inputSize, usage: [.renderTarget, .shaderRead]),
            output: try texture(.rgba16Float, outputSize, usage: [.renderTarget, .shaderRead, .shaderWrite]),
            readback: try texture(.rgba16Float, outputSize, usage: [.shaderRead], storage: .shared)
        )
    }

    private static let checkerSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
        VertexOut out;
        out.position = float4(positions[id], 0, 1);
        return out;
    }
    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]], constant uint &phase [[buffer(0)]]) {
        uint2 cell = uint2(in.position.xy);
        return ((cell.x + cell.y + phase) & 1) ? float4(0.9, 0.9, 0.9, 1) : float4(0.1, 0.1, 0.1, 1);
    }
    """

    // A pixel checkerboard, because uniform input makes the scaler's neighborhood clamp reject all history, which would
    // hide whether history is used at all.
    /// Draws a checkerboard with `phase` into the color input, clears depth to far and motion to zero, upscales, then
    /// copies the output to the readback texture.
    private func frame(_ textures: Textures, phase: UInt32, jitter: SIMD2<Float> = .zero, reset: Bool = false) throws -> some Element {
        let library = try device.makeLibrary(source: Self.checkerSource, options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        let color = MTL4RenderPassDescriptor()
        color.colorAttachments[0].texture = textures.input
        color.colorAttachments[0].loadAction = .dontCare
        color.colorAttachments[0].storeAction = .store
        let auxiliary = MTL4RenderPassDescriptor()
        auxiliary.colorAttachments[0].texture = textures.motion
        auxiliary.colorAttachments[0].loadAction = .clear
        auxiliary.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        auxiliary.colorAttachments[0].storeAction = .store
        auxiliary.depthAttachment.texture = textures.depth
        auxiliary.depthAttachment.loadAction = .clear
        auxiliary.depthAttachment.clearDepth = 1
        auxiliary.depthAttachment.storeAction = .store
        return try Group {
            try RenderPass { EmptyElement() }.renderPassDescriptor(auxiliary)
            try RenderPass {
                try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                        .parameter("phase", value: phase)
                }
            }.renderPassDescriptor(color)
            MetalFXTemporal(inputTexture: textures.input, depthTexture: textures.depth, motionTexture: textures.motion, outputTexture: textures.output, jitter: jitter, reset: reset)
            try ComputePass {
                ComputeCommand { $0.copy(sourceTexture: textures.output, destinationTexture: textures.readback) }
            }
            .useResources([textures.output, textures.readback])
        }
    }

    /// Red channel of the whole readback.
    private func pixels(_ texture: any MTLTexture) -> [Float] {
        var values = [Float16](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(&values, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        return stride(from: 0, to: values.count, by: 4).map { Float(values[$0]) }
    }

    /// Mean absolute difference.
    private func difference(_ lhs: [Float], _ rhs: [Float]) -> Float {
        zip(lhs, rhs).map { abs($0 - $1) }.reduce(0, +) / Float(lhs.count)
    }

    /// Output of a brand-new scaler's first frame, which has no history.
    private func freshFirstFrame(input: Int, output: Int, phase: UInt32, jitter: SIMD2<Float> = .zero) async throws -> [Float] {
        let textures = try textures(input: input, output: output)
        _ = try await FrameRunner(device: device).run(try frame(textures, phase: phase, jitter: jitter))
        return pixels(textures.readback)
    }

    @Test(.timeLimit(.minutes(1)))
    func historyAccumulatesAcrossFramesAndResetDiscardsIt() async throws {
        let runner = try FrameRunner(device: device)
        let textures = try textures(input: 64, output: 128)
        var outputs: [[Float]] = []
        for _ in 0..<6 {
            _ = try await runner.run(try frame(textures, phase: 0))
            outputs.append(pixels(textures.readback))
        }
        // Same input every frame, yet the output keeps changing: the scaler is accumulating history.
        #expect(difference(outputs[0], outputs[1]) > 0.02)

        // Switching the pattern without reset blends in the old history; the output moves toward the new pattern
        // over several frames instead of jumping.
        var switched: [[Float]] = []
        for _ in 0..<4 {
            _ = try await runner.run(try frame(textures, phase: 1))
            switched.append(pixels(textures.readback))
        }
        let freshPhaseOne = try await freshFirstFrame(input: 64, output: 128, phase: 1)
        #expect(difference(switched[0], freshPhaseOne) > 0.05, "No-reset frame should still carry old history")
        #expect(difference(outputs[5], switched[3]) > difference(outputs[5], switched[0]) * 1.5, "Output should move away from the old pattern over frames")

        // With reset the old history is discarded: the frame matches a scaler that never saw anything else.
        _ = try await runner.run(try frame(textures, phase: 1, reset: true))
        #expect(difference(pixels(textures.readback), freshPhaseOne) < 0.001)

        // The flag is per frame: the next frame accumulates again rather than resetting.
        _ = try await runner.run(try frame(textures, phase: 1))
        #expect(difference(pixels(textures.readback), freshPhaseOne) > 0.001)
    }

    @Test(.timeLimit(.minutes(1)))
    func jitterReachesTheScaler() async throws {
        let still = try await freshFirstFrame(input: 64, output: 128, phase: 0)
        let jittered = try await freshFirstFrame(input: 64, output: 128, phase: 0, jitter: [0.25, -0.25])
        #expect(difference(still, jittered) > 0.01)
    }

    @Test(.timeLimit(.minutes(1)))
    func resizingRebuildsTheScalerWithoutStaleHistory() async throws {
        let runner = try FrameRunner(device: device)
        let small = try textures(input: 64, output: 128)
        for _ in 0..<4 {
            _ = try await runner.run(try frame(small, phase: 0))
        }
        // A new output size is a new configuration: history from the old size must not leak into it.
        let large = try textures(input: 64, output: 192)
        _ = try await runner.run(try frame(large, phase: 1))
        let freshLarge = try await freshFirstFrame(input: 64, output: 192, phase: 1)
        #expect(difference(pixels(large.readback), freshLarge) < 0.001)
        let caches = runner.system.nodes.values.map { $0.cache(MetalFXTemporal.Cache.self) { MetalFXTemporal.Cache() } }
        #expect(caches.map(\.creationCount).max() == 2)
    }

    @Test(.timeLimit(.minutes(1)))
    func historySurvivesOverlappingInFlightSubmissions() async throws {
        // Reference: three frames, each awaited before the next.
        let sequential = try FrameRunner(device: device)
        let reference = try textures(input: 64, output: 128)
        for phase: UInt32 in [0, 0, 1] {
            _ = try await sequential.run(try frame(reference, phase: phase))
        }
        let expected = pixels(reference.readback)

        // Same frames, all committed before any completes. Each frame reads back into its own texture.
        let context = try MetalContext(device: device)
        let system = System()
        let shared = try textures(input: 64, output: 128)
        var readbacks: [any MTLTexture] = []
        var submissions: [Submission] = []
        for phase: UInt32 in [0, 0, 1] {
            var frameTextures = shared
            frameTextures.readback = try texture(.rgba16Float, 128, usage: [.shaderRead], storage: .shared)
            readbacks.append(frameTextures.readback)
            let recording = try context.submit(try frame(frameTextures, phase: phase), system: system)
            #expect(context.residencySet.containsAllocation(shared.output))
            submissions.append(recording)
        }
        #expect(context.inFlightCount >= 1)
        for submission in submissions {
            #expect(try await context.awaitResult(submission).outcome == .completed)
        }
        try context.retireCompletedSubmissions()
        #expect(difference(pixels(readbacks[2]), expected) < 0.001)
        #expect(!context.residencySet.containsAllocation(shared.output))
    }

    @Test(.timeLimit(.minutes(1)))
    func invalidTexturesAreRejected() async throws {
        let good = try textures(input: 32, output: 64)
        let shared = try texture(.rgba16Float, 64, usage: [.renderTarget, .shaderRead, .shaderWrite], storage: .shared)
        await #expect(throws: MetalSprocketsError.self) {
            _ = try await FrameRunner(device: device).run(MetalFXTemporal(inputTexture: good.input, depthTexture: good.depth, motionTexture: good.motion, outputTexture: shared))
        }
        let unreadableMotion = try texture(.rg16Float, 32, usage: [.renderTarget])
        await #expect(throws: MetalSprocketsError.self) {
            _ = try await FrameRunner(device: device).run(MetalFXTemporal(inputTexture: good.input, depthTexture: good.depth, motionTexture: unreadableMotion, outputTexture: good.output))
        }
    }
}
#endif
