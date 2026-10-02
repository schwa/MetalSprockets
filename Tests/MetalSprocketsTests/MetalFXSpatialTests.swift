#if canImport(MetalFX)
import Metal
import MetalFX
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

private func spatialSupported() -> Bool {
    guard let device = MTLCreateSystemDefaultDevice() else {
        return false
    }
    return device.supportsFamily(.metal4) && MTLFXSpatialScalerDescriptor.supportsMetal4FX(device)
}

/// Spatial upscaling through the Metal 4 scaler: produced, scaled and read back in one submission per frame.
@MainActor
@Suite("Metal 4 MetalFX spatial", .requiresMetal4, .enabled(if: spatialSupported(), "Requires Metal 4 and supportsMetal4FX"))
struct MetalFXSpatialTests {
    private let device = MTLCreateSystemDefaultDevice()!

    private static let colorSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
        VertexOut out;
        out.position = float4(positions[id], 0, 1);
        return out;
    }
    [[fragment]] float4 fragment_main(constant float4 &color [[buffer(0)]]) { return color; }
    """

    private func texture(_ format: MTLPixelFormat, _ width: Int, _ height: Int, usage: MTLTextureUsage, storage: MTLStorageMode = .private) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.usage = usage
        descriptor.storageMode = storage
        return try #require(device.makeTexture(descriptor: descriptor))
    }

    /// Produces `input` (left half `left`, right half `right`), scales it into `output`, then copies to `readback`.
    private func frame(input: any MTLTexture, output: any MTLTexture, readback: any MTLTexture, left: SIMD4<Float>, right: SIMD4<Float>) throws -> some Element {
        let library = try device.makeLibrary(source: Self.colorSource, options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = input
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        let half = input.width / 2
        return try Group {
            try RenderPass {
                try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                        .parameter("color", value: left)
                        .scissor(MTLScissorRect(x: 0, y: 0, width: half, height: input.height))
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                        .parameter("color", value: right)
                        .scissor(MTLScissorRect(x: half, y: 0, width: input.width - half, height: input.height))
                }
            }.renderPassDescriptor(pass)
            MetalFXSpatial(inputTexture: input, outputTexture: output)
            try ComputePass {
                ComputeCommand { $0.copy(sourceTexture: output, destinationTexture: readback) }
            }
            .useResources([output, readback])
        }
    }

    private func pixel(_ texture: any MTLTexture, _ x: Int, _ y: Int) -> SIMD4<Float> {
        var value = [Float16](repeating: 0, count: 4)
        texture.getBytes(&value, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
        return SIMD4<Float>(value.map(Float.init))
    }

    private func expectClose(_ actual: SIMD4<Float>, _ expected: SIMD4<Float>, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(abs(actual - expected).max() < 0.02, "\(actual) != \(expected)", sourceLocation: sourceLocation)
    }

    @Test(.timeLimit(.minutes(1)))
    func scaledOutputFollowsEachFramesInputAndResizes() async throws {
        let runner = try FrameRunner(device: device)
        let input = try texture(.rgba16Float, 64, 64, usage: [.renderTarget, .shaderRead])
        let red: SIMD4<Float> = [1, 0, 0, 1]
        let blue: SIMD4<Float> = [0, 0, 1, 1]
        for (size, left, right) in [(128, red, blue), (128, blue, red), (256, red, blue)] {
            let output = try texture(.rgba16Float, size, size, usage: [.renderTarget, .shaderRead, .shaderWrite])
            let readback = try texture(.rgba16Float, size, size, usage: [.shaderRead], storage: .shared)
            let result = try await runner.run(frame(input: input, output: output, readback: readback, left: left, right: right))
            #expect(result.outcome == .completed)
            // Away from the seam, the upscaled halves keep their colors; the seam lands in the middle of the output.
            expectClose(pixel(readback, size / 8, size / 2), left)
            expectClose(pixel(readback, size - size / 8, size / 2), right)
            #expect(pixel(readback, size / 2 - 2, size / 2) != pixel(readback, size / 2 + 2, size / 2))
        }
        #expect(runner.context.inFlightCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func scalerIsReusedAtOneSizeAndRebuiltOnResize() async throws {
        let context = try MetalContext(device: device)
        let system = System()
        let input = try texture(.rgba16Float, 32, 32, usage: [.renderTarget, .shaderRead])
        let small = try texture(.rgba16Float, 64, 64, usage: [.renderTarget, .shaderRead, .shaderWrite])
        let large = try texture(.rgba16Float, 96, 96, usage: [.renderTarget, .shaderRead, .shaderWrite])
        for output in [small, small, large, large] {
            let recording = try context.submit(MetalFXSpatial(inputTexture: input, outputTexture: output), system: system)
            // Recorded but not retired: the scaler's textures are resident until this submission ends.
            #expect(context.residencySet.containsAllocation(input))
            #expect(context.residencySet.containsAllocation(output))
            #expect(try await context.awaitResult(recording).outcome == .completed)
            try context.retireCompletedSubmissions()
            #expect(!context.residencySet.containsAllocation(output))
        }
        let caches = system.nodes.values.map { $0.cache(MetalFXSpatial.Cache.self) { MetalFXSpatial.Cache() } }
        #expect(caches.map(\.creationCount).max() == 2)
    }

    @Test(.timeLimit(.minutes(1)))
    func eightBitFormatsScale() async throws {
        let input = try texture(.bgra8Unorm, 64, 64, usage: [.renderTarget, .shaderRead])
        let output = try texture(.bgra8Unorm, 128, 128, usage: [.renderTarget, .shaderRead, .shaderWrite])
        let readback = try texture(.bgra8Unorm, 128, 128, usage: [.shaderRead], storage: .shared)
        let result = try await FrameRunner(device: device).run(frame(input: input, output: output, readback: readback, left: [0, 1, 0, 1], right: [1, 1, 1, 1]))
        #expect(result.outcome == .completed)
        var bytes = [UInt8](repeating: 0, count: 4)
        readback.getBytes(&bytes, bytesPerRow: 128 * 4, from: MTLRegionMake2D(16, 64, 1, 1), mipmapLevel: 0)
        #expect(bytes == [0, 255, 0, 255])
    }

    @Test(.timeLimit(.minutes(1)))
    func invalidTexturesAreRejectedBeforeEncoding() async throws {
        let input = try texture(.rgba16Float, 32, 32, usage: [.renderTarget, .shaderRead])
        let shared = try texture(.rgba16Float, 64, 64, usage: [.renderTarget, .shaderRead, .shaderWrite], storage: .shared)
        await #expect(throws: MetalSprocketsError.self) {
            _ = try await FrameRunner(device: device).run(MetalFXSpatial(inputTexture: input, outputTexture: shared))
        }
        let unreadable = try texture(.rgba16Float, 32, 32, usage: [.renderTarget])
        let output = try texture(.rgba16Float, 64, 64, usage: [.renderTarget, .shaderRead, .shaderWrite])
        await #expect(throws: MetalSprocketsError.self) {
            _ = try await FrameRunner(device: device).run(MetalFXSpatial(inputTexture: unreadable, outputTexture: output))
        }
    }
}
#endif
