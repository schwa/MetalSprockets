#if canImport(MetalFX)
import Metal
import MetalFX
import MetalSprocketsSupport
import MetalSupport

public struct MetalFXSpatial: Element, BodylessElement {
    public typealias Body = Never

    var inputTexture: MTLTexture
    var outputTexture: MTLTexture

    @MSEnvironment(\.commandBuffer)
    var commandBuffer

    public init(inputTexture: MTLTexture, outputTexture: MTLTexture) {
        self.inputTexture = inputTexture
        self.outputTexture = outputTexture
    }

    func setupEnter(_ node: Node) throws {
        // Build (or reuse) the scaler here. requiresSetup always returns true
        // for this element, but the per-node cache keys the scaler on the
        // texture formats and dimensions so we only reallocate when one of
        // those actually changes. See #319 / #333.
        let cache = node.cache(MetalFXSpatialCache.self) { MetalFXSpatialCache() }
        let key = MetalFXSpatialCache.Key(
            inputFormat: inputTexture.pixelFormat,
            outputFormat: outputTexture.pixelFormat,
            inputWidth: inputTexture.width,
            inputHeight: inputTexture.height,
            outputWidth: outputTexture.width,
            outputHeight: outputTexture.height
        )
        if cache.key == key, cache.scaler != nil {
            return
        }
        cache.scaler = try makeScaler()
        cache.key = key
    }

    func workloadEnter(_ node: Node) throws {
        let cache = node.cache(MetalFXSpatialCache.self) { MetalFXSpatialCache() }
        let scaler = try cache.scaler.orThrow(.resourceCreationFailure("MetalFX spatial scaler not initialized"))
        let commandBuffer = try commandBuffer.orThrow(.missingEnvironment(\.commandBuffer))
        scaler.colorTexture = inputTexture
        scaler.inputContentWidth = inputTexture.width
        scaler.inputContentHeight = inputTexture.height
        scaler.outputTexture = outputTexture
        scaler.encode(commandBuffer: commandBuffer)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        // Always re-run setup; the per-node cache decides whether to rebuild
        // the scaler based on (format, dimensions). Setup is cheap on a hit.
        true
    }

    func makeScaler() throws -> MTLFXSpatialScaler {
        let descriptor = MTLFXSpatialScalerDescriptor()
        descriptor.colorTextureFormat = inputTexture.pixelFormat
        descriptor.outputTextureFormat = outputTexture.pixelFormat
        descriptor.inputWidth = inputTexture.width
        descriptor.inputHeight = inputTexture.height
        descriptor.outputWidth = outputTexture.width
        descriptor.outputHeight = outputTexture.height
        let device = _MTLCreateSystemDefaultDevice()
        return try descriptor.makeSpatialScaler(device: device).orThrow(.resourceCreationFailure("Failed to create MetalFX spatial scaler"))
    }
}

private final class MetalFXSpatialCache: NodeElementCache {
    struct Key: Hashable {
        let inputFormat: MTLPixelFormat
        let outputFormat: MTLPixelFormat
        let inputWidth: Int
        let inputHeight: Int
        let outputWidth: Int
        let outputHeight: Int
    }

    var key: Key?
    var scaler: MTLFXSpatialScaler?
}
#endif
