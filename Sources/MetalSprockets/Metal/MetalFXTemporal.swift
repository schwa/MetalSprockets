#if canImport(MetalFX) && !os(visionOS)
import Metal
import MetalFX
import MetalSprocketsSupport

/// Temporal upscaling with the Metal 4 MetalFX temporal scaler.
///
/// History lives in the scaler, which persists across frames and is rebuilt (with history discarded) only when a format
/// or size changes. Set `reset` for a frame whose history must not be used, such as after a camera cut. Place it
/// outside passes; ordering with earlier producers and later consumers is handled. Not available on visionOS.
public struct MetalFXTemporal: Element, SetupElement, WorkloadElement {
    public typealias Body = Never

    var inputTexture: MTLTexture
    var depthTexture: MTLTexture
    var motionTexture: MTLTexture
    var outputTexture: MTLTexture
    var jitter: SIMD2<Float>
    var reset: Bool

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

    struct Key: Hashable {
        let formats: [MTLPixelFormat]
        let inputWidth: Int
        let inputHeight: Int
        let outputWidth: Int
        let outputHeight: Int
    }

    final class Cache: NodeElementCache {
        var key: Key?
        var scaler: (any MTL4FXTemporalScaler)?
        var fence: (any MTLFence)?
        var creationCount = 0
        var isFresh = false
    }

    func setupEnter(_ node: Node) throws {
        let context = try node.environmentValues.metalContext.orThrow(.missingEnvironment("metalContext"))
        let cache = node.cache(Cache.self) { Cache() }
        let key = Key(formats: [inputTexture.pixelFormat, depthTexture.pixelFormat, motionTexture.pixelFormat, outputTexture.pixelFormat], inputWidth: inputTexture.width, inputHeight: inputTexture.height, outputWidth: outputTexture.width, outputHeight: outputTexture.height)
        if cache.key != key || cache.scaler == nil {
            guard MTLFXTemporalScalerDescriptor.supportsMetal4FX(context.device) else {
                throw MetalSprocketsError.deviceCababilityFailure("Device '\(context.device.name)' does not support Metal 4 MetalFX temporal scaling.")
            }
            let descriptor = MTLFXTemporalScalerDescriptor()
            descriptor.colorTextureFormat = inputTexture.pixelFormat
            descriptor.depthTextureFormat = depthTexture.pixelFormat
            descriptor.motionTextureFormat = motionTexture.pixelFormat
            descriptor.outputTextureFormat = outputTexture.pixelFormat
            descriptor.inputWidth = inputTexture.width
            descriptor.inputHeight = inputTexture.height
            descriptor.outputWidth = outputTexture.width
            descriptor.outputHeight = outputTexture.height
            cache.scaler = try descriptor.makeTemporalScaler(device: context.device, compiler: context.pipelines.compiler).orThrow(.resourceCreationFailure("Failed to create Metal 4 MetalFX temporal scaler"))
            cache.fence = try context.device.makeFence().orThrow(.resourceCreationFailure("Failed to create MetalFX fence"))
            cache.key = key
            cache.creationCount += 1
            cache.isFresh = true
        }
        let scaler = try cache.scaler.orThrow(.resourceCreationFailure("MetalFX temporal scaler not initialized"))
        try MetalFXSynchronization.validate(inputTexture, role: "temporal color", required: scaler.colorTextureUsage)
        try MetalFXSynchronization.validate(depthTexture, role: "temporal depth", required: scaler.depthTextureUsage)
        try MetalFXSynchronization.validate(motionTexture, role: "temporal motion", required: scaler.motionTextureUsage)
        try MetalFXSynchronization.validate(outputTexture, role: "temporal output", required: scaler.outputTextureUsage)
        guard outputTexture.storageMode == .private else {
            throw MetalSprocketsError.configurationError("MetalFX temporal output texture must use private storage.")
        }
    }

    func workloadEnter(_ node: Node) throws {
        let scope = try node.environmentValues.recordingScope.orThrow(.missingEnvironment("recordingScope"))
        let cache = node.cache(Cache.self) { Cache() }
        let scaler = try cache.scaler.orThrow(.resourceCreationFailure("MetalFX temporal scaler not initialized"))
        let fence = try cache.fence.orThrow(.resourceCreationFailure("MetalFX fence not initialized"))
        // The scaler owns the history; keeping it alive per submission keeps history valid while frames are in flight.
        try scope.retainObject(scaler)
        try scope.retainObject(fence)
        for texture in [inputTexture, depthTexture, motionTexture, outputTexture] {
            try scope.retainAllocation(texture)
        }
        scaler.colorTexture = inputTexture
        scaler.depthTexture = depthTexture
        scaler.motionTexture = motionTexture
        scaler.outputTexture = outputTexture
        scaler.inputContentWidth = inputTexture.width
        scaler.inputContentHeight = inputTexture.height
        scaler.jitterOffsetX = jitter.x
        scaler.jitterOffsetY = jitter.y
        // A rebuilt scaler has no history to keep, so its first frame is always a reset.
        scaler.reset = reset || cache.isFresh
        cache.isFresh = false
        scaler.fence = fence
        try MetalFXSynchronization.encode(scope: scope, fence: fence) { commandBuffer in
            scaler.encode(commandBuffer: commandBuffer)
        }
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { true }
}
#endif
