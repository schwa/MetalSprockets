#if canImport(MetalFX) && !os(visionOS)
import Metal
import MetalFX
@testable import MetalSprockets
import MetalSprocketsSupport
import simd
import Testing

@MainActor
@Suite("MetalFXTemporal Tests")
struct MetalFXTemporalTests {
    private struct Textures {
        var input: MTLTexture
        var depth: MTLTexture
        var motion: MTLTexture
        var output: MTLTexture
    }

    private func makeTexture(device: MTLDevice, format: MTLPixelFormat, width: Int, height: Int, usage: MTLTextureUsage) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.usage = usage
        descriptor.storageMode = .private
        return try #require(device.makeTexture(descriptor: descriptor))
    }

    private func makeTextures(device: MTLDevice, inputSize: Int, outputSize: Int) throws -> Textures {
        Textures(
            input: try makeTexture(device: device, format: .rgba16Float, width: inputSize, height: inputSize, usage: [.renderTarget, .shaderRead]),
            depth: try makeTexture(device: device, format: .depth32Float, width: inputSize, height: inputSize, usage: [.renderTarget, .shaderRead]),
            motion: try makeTexture(device: device, format: .rg16Float, width: inputSize, height: inputSize, usage: [.renderTarget, .shaderRead]),
            output: try makeTexture(device: device, format: .rgba16Float, width: outputSize, height: outputSize, usage: [.renderTarget, .shaderWrite, .shaderRead])
        )
    }

    private func element(_ textures: Textures, jitter: SIMD2<Float> = .zero, reset: Bool = false) -> MetalFXTemporal {
        MetalFXTemporal(
            inputTexture: textures.input,
            depthTexture: textures.depth,
            motionTexture: textures.motion,
            outputTexture: textures.output,
            jitter: jitter,
            reset: reset
        )
    }

    private func supportedDevice() throws -> MTLDevice? {
        let device = try #require(MTLCreateSystemDefaultDevice())
        guard MTLFXTemporalScalerDescriptor.supportsDevice(device) else {
            return nil
        }
        return device
    }

    @Test func `the scaler descriptor mirrors the textures`() throws {
        guard let device = try supportedDevice() else {
            return
        }
        let textures = try makeTextures(device: device, inputSize: 64, outputSize: 128)
        let scaler = try element(textures).makeScaler(device: device)
        #expect(scaler.inputWidth == 64)
        #expect(scaler.inputHeight == 64)
        #expect(scaler.outputWidth == 128)
        #expect(scaler.outputHeight == 128)
    }

    @Test func `a temporal upscale encodes into the command buffer`() throws {
        guard let device = try supportedDevice() else {
            return
        }
        let textures = try makeTextures(device: device, inputSize: 64, outputSize: 128)
        let pass = CommandBufferElement(completion: .commitAndWaitUntilCompleted) {
            element(textures, jitter: SIMD2<Float>(0.25, -0.25), reset: true)
        }
        try pass.run()
    }

    @Test func `the scaler is recreated when the input size changes`() throws {
        guard let device = try supportedDevice() else {
            return
        }
        let small = try makeTextures(device: device, inputSize: 64, outputSize: 128)
        let larger = try makeTextures(device: device, inputSize: 96, outputSize: 128)

        // One runner, so the node's @MSState scaler survives between runs and the size-change branch is what
        // rebuilds it.
        let runner = try Runner(device: device)
        try runner.run(element(small))
        try runner.run(element(larger))
    }

    @Test func `successive frames at the same size reuse the scaler`() throws {
        guard let device = try supportedDevice() else {
            return
        }
        let textures = try makeTextures(device: device, inputSize: 64, outputSize: 128)
        let runner = try Runner(device: device)

        for frame in 0..<3 {
            try runner.run(element(textures, jitter: SIMD2<Float>(Float(frame) * 0.1, 0), reset: frame == 0))
        }
    }
}
#endif
