#if canImport(MetalFX)
import Metal
import MetalFX
import MetalSprocketsSupport

/// Upscales `inputTexture` into `outputTexture` with the Metal 4 MetalFX spatial scaler.
///
/// Place it outside passes, after the pass that produces the input. Work before it finishes before MetalFX reads the
/// input, and work after it sees the output, without extra barriers. The scaler is rebuilt only when formats or sizes
/// change. The output must use private storage, and both textures need the usage MetalFX reports.
public struct MetalFXSpatial: Element, SetupElement, WorkloadElement {
    public typealias Body = Never

    var inputTexture: MTLTexture
    var outputTexture: MTLTexture

    public init(inputTexture: MTLTexture, outputTexture: MTLTexture) {
        self.inputTexture = inputTexture
        self.outputTexture = outputTexture
    }

    struct Key: Hashable {
        let inputFormat: MTLPixelFormat
        let outputFormat: MTLPixelFormat
        let inputWidth: Int
        let inputHeight: Int
        let outputWidth: Int
        let outputHeight: Int
    }

    final class Cache: NodeElementCache {
        var key: Key?
        var scaler: (any MTL4FXSpatialScaler)?
        var fence: (any MTLFence)?
        var creationCount = 0
    }

    func setupEnter(_ node: Node) throws {
        let context = try node.environmentValues.metalContext.orThrow(.missingEnvironment("metalContext"))
        let cache = node.cache(Cache.self) { Cache() }
        let key = Key(inputFormat: inputTexture.pixelFormat, outputFormat: outputTexture.pixelFormat, inputWidth: inputTexture.width, inputHeight: inputTexture.height, outputWidth: outputTexture.width, outputHeight: outputTexture.height)
        if cache.key != key || cache.scaler == nil {
            guard MTLFXSpatialScalerDescriptor.supportsMetal4FX(context.device) else {
                throw MetalSprocketsError.deviceCababilityFailure("Device '\(context.device.name)' does not support Metal 4 MetalFX spatial scaling.")
            }
            let descriptor = MTLFXSpatialScalerDescriptor()
            descriptor.colorTextureFormat = key.inputFormat
            descriptor.outputTextureFormat = key.outputFormat
            descriptor.inputWidth = key.inputWidth
            descriptor.inputHeight = key.inputHeight
            descriptor.outputWidth = key.outputWidth
            descriptor.outputHeight = key.outputHeight
            cache.scaler = try descriptor.makeSpatialScaler(device: context.device, compiler: context.pipelines.compiler).orThrow(.resourceCreationFailure("Failed to create Metal 4 MetalFX spatial scaler"))
            cache.fence = try context.device.makeFence().orThrow(.resourceCreationFailure("Failed to create MetalFX fence"))
            cache.key = key
            cache.creationCount += 1
        }
        let scaler = try cache.scaler.orThrow(.resourceCreationFailure("MetalFX spatial scaler not initialized"))
        try MetalFXSynchronization.validate(inputTexture, role: "spatial input", required: scaler.colorTextureUsage)
        try MetalFXSynchronization.validate(outputTexture, role: "spatial output", required: scaler.outputTextureUsage)
        guard outputTexture.storageMode == .private else {
            throw MetalSprocketsError.configurationError("MetalFX spatial output texture must use private storage.")
        }
    }

    func workloadEnter(_ node: Node) throws {
        let scope = try node.environmentValues.recordingScope.orThrow(.missingEnvironment("recordingScope"))
        let cache = node.cache(Cache.self) { Cache() }
        let scaler = try cache.scaler.orThrow(.resourceCreationFailure("MetalFX spatial scaler not initialized"))
        let fence = try cache.fence.orThrow(.resourceCreationFailure("MetalFX fence not initialized"))
        // The scaler is reused across frames, so it and its textures stay alive until every submission using them ends.
        try scope.retainObject(scaler)
        try scope.retainObject(fence)
        try scope.retainAllocation(inputTexture)
        try scope.retainAllocation(outputTexture)
        scaler.colorTexture = inputTexture
        scaler.inputContentWidth = inputTexture.width
        scaler.inputContentHeight = inputTexture.height
        scaler.outputTexture = outputTexture
        scaler.fence = fence
        try MetalFXSynchronization.encode(scope: scope, fence: fence) { commandBuffer in
            scaler.encode(commandBuffer: commandBuffer)
        }
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { true }
}
#endif
