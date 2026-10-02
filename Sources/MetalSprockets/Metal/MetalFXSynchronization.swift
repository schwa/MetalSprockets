#if canImport(MetalFX)
import Metal
import MetalFX
import MetalSprocketsSupport

/// Ordering around MetalFX work that encodes its own passes into the command buffer.
///
/// Metal 4 does not track hazards, and MetalFX does not document which stages it uses. Each side therefore gets a tiny
/// compute pass with barriers over every queue stage: the one before waits for all earlier queue work and blocks all
/// later queue work until it finishes; the one after does the same for the MetalFX passes. The scaler's fence is
/// updated before and waited on after, which satisfies the fence contract as well. The result: earlier producers
/// finish before MetalFX reads its inputs, and later consumers see its output without their own barriers.
internal enum MetalFXSynchronization {
    static let allStages: MTLStages = [.vertex, .fragment, .tile, .object, .mesh, .dispatch, .blit, .accelerationStructure, .machineLearning, .resourceState]

    static func encode(scope: RecordingScope, fence: any MTLFence, _ work: (any MTL4CommandBuffer) throws -> Void) throws {
        try scope.withComputeEncoder { encoder in
            encoder.barrier(afterQueueStages: allStages, beforeStages: .dispatch, visibilityOptions: .device)
            encoder.updateFence(fence, afterEncoderStages: .dispatch)
            encoder.barrier(afterStages: .dispatch, beforeQueueStages: allStages, visibilityOptions: .device)
        }
        try scope.withCommandBuffer(work)
        try scope.withComputeEncoder { encoder in
            encoder.waitForFence(fence, beforeEncoderStages: .dispatch)
            encoder.barrier(afterQueueStages: allStages, beforeStages: .dispatch, visibilityOptions: .device)
            encoder.barrier(afterStages: .dispatch, beforeQueueStages: allStages, visibilityOptions: .device)
        }
    }

    /// MetalFX states its minimum usage per texture; missing bits are a configuration error, not undefined behavior.
    static func validate(_ texture: any MTLTexture, role: String, required: MTLTextureUsage) throws {
        guard texture.usage.isSuperset(of: required) else {
            throw MetalSprocketsError.configurationError("MetalFX \(role) texture usage \(texture.usage.rawValue) lacks required usage \(required.rawValue).")
        }
    }
}
#endif
