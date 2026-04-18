#if canImport(MetalFX) && !os(visionOS)
import Metal
import MetalFX
import MetalSprocketsSupport
import MetalSupport

/// Runs a `MTLFXTemporalScaler` to upscale a low-resolution color texture
/// to a higher-resolution output, using depth and motion vectors and
/// accumulating information across frames.
///
/// Callers are expected to provide:
///
/// - `inputTexture`: the low-resolution color (linear).
/// - `depthTexture`: matching depth at the same low-res.
/// - `motionTexture`: per-pixel motion vectors in **input pixel units**
///   (two channels, typically `.rg16Float`).
/// - `outputTexture`: the upscaled color target.
/// - `jitter`: the sub-pixel jitter (Halton sequence, usually in
///   `[-0.5, 0.5]`) applied to the projection that produced this frame.
/// - `reset`: set `true` for one frame when history must be discarded
///   (camera teleport, topology change, scale change).
public struct MetalFXTemporal: Element {
    @MSState
    var scaler: MTLFXTemporalScaler?

    var inputTexture: MTLTexture
    var depthTexture: MTLTexture
    var motionTexture: MTLTexture
    var outputTexture: MTLTexture
    var jitter: SIMD2<Float>
    var reset: Bool

    @MSEnvironment(\.commandBuffer)
    var commandBuffer

    public init(
        inputTexture: MTLTexture,
        depthTexture: MTLTexture,
        motionTexture: MTLTexture,
        outputTexture: MTLTexture,
        jitter: SIMD2<Float> = .zero,
        reset: Bool = false
    ) {
        self.inputTexture = inputTexture
        self.depthTexture = depthTexture
        self.motionTexture = motionTexture
        self.outputTexture = outputTexture
        self.jitter = jitter
        self.reset = reset
    }

    public var body: some Element {
        AnyBodylessElement()
            .onWorkloadEnter {
                // Lazily create or recreate the scaler only when needed.
                // Setup runs every frame (AnyBodylessElement always
                // reports requiresSetup = true), so scaler creation must
                // NOT happen in `onSetupEnter` or we'd destroy the
                // accumulated history every frame — defeating the whole
                // point of temporal upscaling.
                if scaler == nil
                    || scaler?.outputWidth != outputTexture.width
                    || scaler?.outputHeight != outputTexture.height
                    || scaler?.inputWidth != inputTexture.width
                    || scaler?.inputHeight != inputTexture.height {
                    scaler = try makeScaler()
                }
                let s = try scaler.orThrow(.resourceCreationFailure("MetalFX temporal scaler not initialized"))
                let commandBuffer = try commandBuffer.orThrow(.missingEnvironment(\.commandBuffer))
                s.colorTexture = inputTexture
                s.depthTexture = depthTexture
                s.motionTexture = motionTexture
                s.outputTexture = outputTexture
                s.inputContentWidth = inputTexture.width
                s.inputContentHeight = inputTexture.height
                s.jitterOffsetX = jitter.x
                s.jitterOffsetY = jitter.y
                s.reset = reset
                s.encode(commandBuffer: commandBuffer)
            }
    }

    func makeScaler() throws -> MTLFXTemporalScaler {
        let descriptor = MTLFXTemporalScalerDescriptor()
        descriptor.colorTextureFormat = inputTexture.pixelFormat
        descriptor.depthTextureFormat = depthTexture.pixelFormat
        descriptor.motionTextureFormat = motionTexture.pixelFormat
        descriptor.outputTextureFormat = outputTexture.pixelFormat
        descriptor.inputWidth = inputTexture.width
        descriptor.inputHeight = inputTexture.height
        descriptor.outputWidth = outputTexture.width
        descriptor.outputHeight = outputTexture.height
        let device = _MTLCreateSystemDefaultDevice()
        return try descriptor.makeTemporalScaler(device: device).orThrow(.resourceCreationFailure("Failed to create MetalFX temporal scaler"))
    }
}
#endif
