import Metal
import MetalSprocketsSupport
import os

/// A one-thread no-op dispatch encoded before the start timestamp of a timed compute pass.
///
/// A precise timestamp at the start of a compute encoder is not ordered before the dispatches after it. It is often
/// written after most of the first dispatch has run, so the pass duration is too short. A timestamp after a dispatch
/// is reliable. Measured on Apple M5 Max, macOS 27 (#549).
internal enum TimestampPrimer {
    private static let source = """
    kernel void metalsprockets_timestamp_primer() {}
    """

    private static let pipelines = OSAllocatedUnfairLock<[ObjectIdentifier: any MTLComputePipelineState]>(initialState: [:])

    static func pipeline(for device: any MTLDevice) throws -> any MTLComputePipelineState {
        let key = ObjectIdentifier(device)
        if let pipeline = pipelines.withLock({ $0[key] }) {
            return pipeline
        }
        let library = try device.makeLibrary(source: source, options: nil)
        let function = try library.makeFunction(name: "metalsprockets_timestamp_primer").orThrow(.resourceCreationFailure("Timestamp primer kernel not found"))
        let pipeline = try device.makeComputePipelineState(function: function)
        // Keep the first one if another thread got there first.
        return pipelines.withLock { cache in
            if let existing = cache[key] {
                return existing
            }
            cache[key] = pipeline
            return pipeline
        }
    }
}
