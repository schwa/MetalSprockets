import Foundation
import Metal
import os

// MARK: - GPUCounterSample

/// A resolved pair of GPU timestamps for a single render pass.
///
/// Produced by the ``Element/gpuCounters(label:_:)`` modifier.
public struct GPUCounterSample: Sendable, Equatable {
    /// The label passed to the modifier, if any.
    public var label: String?

    /// Raw GPU timestamp taken at the start of the pass, in GPU ticks.
    public var startTimestamp: MTLTimestamp

    /// Raw GPU timestamp taken at the end of the pass, in GPU ticks.
    public var endTimestamp: MTLTimestamp

    /// Elapsed GPU time for the pass, in seconds.
    ///
    /// Computed by correlating GPU ticks with the CPU clock via
    /// `MTLDevice.sampleTimestamps(...)`. `nil` if correlation was not possible.
    public var duration: TimeInterval?

    public init(label: String? = nil, startTimestamp: MTLTimestamp, endTimestamp: MTLTimestamp, duration: TimeInterval? = nil) {
        self.label = label
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.duration = duration
    }
}

// MARK: - GPUCounterSampler

/// Wraps a device's timestamp counter set and converts GPU ticks to seconds.
///
/// Most users should use ``Element/gpuCounters(label:_:)`` instead of this type.
/// - Note: `@unchecked Sendable` because `MTLDevice` and `MTLCounterSet` are not `Sendable`. The sampler itself has
///   no mutable state — every stored property is a `let` — and Metal's device APIs used here are thread-safe, so no
///   locking is needed. See #388.
public final class GPUCounterSampler: @unchecked Sendable {
    private let device: MTLDevice
    private let counterSet: MTLCounterSet

    /// CPU/GPU timestamp pair captured when the sampler was created; used as the
    /// baseline for tick-to-seconds conversion.
    private let baseCPUTimestamp: MTLTimestamp
    private let baseGPUTimestamp: MTLTimestamp

    /// Creates a sampler, or returns `nil` if the device cannot sample timestamps
    /// at render stage boundaries.
    public init?(device: MTLDevice) {
        guard device.supportsCounterSampling(.atStageBoundary) else {
            return nil
        }
        guard let counterSet = device.counterSets?.first(where: { $0.name == MTLCommonCounterSet.timestamp.rawValue }) else {
            return nil
        }
        self.device = device
        self.counterSet = counterSet
        let timestamps = device.sampleTimestamps()
        baseCPUTimestamp = timestamps.cpu
        baseGPUTimestamp = timestamps.gpu
    }

    /// Creates a sample buffer able to hold `capacity` timestamps.
    public func makeSampleBuffer(capacity: Int = 2) -> MTLCounterSampleBuffer? {
        let descriptor = MTLCounterSampleBufferDescriptor()
        descriptor.counterSet = counterSet
        descriptor.storageMode = .shared
        descriptor.sampleCount = capacity
        return try? device.makeCounterSampleBuffer(descriptor: descriptor)
    }

    /// Resolves the first two timestamps in `sampleBuffer` into a sample.
    public func resolve(_ sampleBuffer: MTLCounterSampleBuffer, label: String? = nil) -> GPUCounterSample? {
        guard let data = try? sampleBuffer.resolveCounterRange(0..<2) else {
            return nil
        }
        let timestamps: [MTLTimestamp] = data.withUnsafeBytes { buffer in
            let results = buffer.bindMemory(to: MTLCounterResultTimestamp.self)
            return results.prefix(2).map(\.timestamp)
        }
        guard timestamps.count == 2 else {
            return nil
        }
        let (start, end) = (timestamps[0], timestamps[1])
        // MTLCounterErrorValue marks a sample the GPU could not take.
        guard start != MTLCounterErrorValue, end != MTLCounterErrorValue, end >= start else {
            return nil
        }
        return GPUCounterSample(label: label, startTimestamp: start, endTimestamp: end, duration: seconds(forTicks: end - start))
    }

    /// Converts a GPU tick delta to seconds using a fresh CPU/GPU correlation pair.
    public func seconds(forTicks ticks: UInt64) -> TimeInterval? {
        let timestamps = device.sampleTimestamps()
        let cpu = timestamps.cpu
        let gpu = timestamps.gpu
        guard gpu > baseGPUTimestamp, cpu > baseCPUTimestamp else {
            return nil
        }
        // CPU timestamps are nanoseconds; scale ticks into the CPU timebase.
        let nanosecondsPerTick = Double(cpu - baseCPUTimestamp) / Double(gpu - baseGPUTimestamp)
        return Double(ticks) * nanosecondsPerTick / 1_000_000_000
    }
}

// MARK: - GPUCountersModifier

internal struct GPUCountersModifier <Content>: Element, BodylessElement, BodylessContentElement, WorkloadElement where Content: Element {
    // Shared between the configure phase (which creates the sample buffer) and
    // the workload phase (which resolves it on command buffer completion). The
    // two phases can run on different threads, so the state is lock-protected
    // rather than left as bare `var`s under `@unchecked Sendable`. See #387.
    final class Storage: @unchecked Sendable {
        // `@unchecked` only because `MTLCounterSampleBuffer` is not `Sendable`; access is confined to the lock below.
        private struct State: @unchecked Sendable {
            var sampler: GPUCounterSampler?
            var sampleBuffer: MTLCounterSampleBuffer?
        }

        // `withLockUnchecked` throughout: `MTLCounterSampleBuffer` is not `Sendable`.
        private let state = OSAllocatedUnfairLock(initialState: State())

        var sampler: GPUCounterSampler? {
            state.withLockUnchecked { $0.sampler }
        }

        var sampleBuffer: MTLCounterSampleBuffer? {
            state.withLockUnchecked { $0.sampleBuffer }
        }

        /// Returns the existing sampler, creating one for `device` if there isn't one yet.
        func sampler(makingWith device: MTLDevice) -> GPUCounterSampler? {
            state.withLockUnchecked { state in
                if state.sampler == nil {
                    state.sampler = GPUCounterSampler(device: device)
                }
                return state.sampler
            }
        }

        func setSampleBuffer(_ sampleBuffer: MTLCounterSampleBuffer?) {
            state.withLockUnchecked { $0.sampleBuffer = sampleBuffer }
        }
    }

    var content: Content
    var label: String?
    var handler: @Sendable (GPUCounterSample) -> Void
    let storage = Storage()

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func configureNodeBodyless(_ node: Node) throws {
        guard let system = System.current else {
            fatalError("GPUCountersModifier: No System is currently active.")
        }
        guard let device = node.environmentValues.device else {
            logger?.warning("gpuCounters: No device in environment; counters disabled.")
            return
        }
        let parent = system.traversalContext.parentNode
        guard let renderPassDescriptor = parent?.environmentValues.renderPassDescriptor ?? node.environmentValues.renderPassDescriptor else {
            return
        }
        guard let sampler = storage.sampler(makingWith: device), let sampleBuffer = sampler.makeSampleBuffer() else {
            logger?.warning("gpuCounters: GPU counter sampling unavailable on this device; counters disabled.")
            return
        }
        storage.setSampleBuffer(sampleBuffer)

        let copy = renderPassDescriptor.copyWithType(MTLRenderPassDescriptor.self)
        guard let attachment = copy.sampleBufferAttachments[0] else {
            return
        }
        attachment.sampleBuffer = sampleBuffer
        attachment.startOfVertexSampleIndex = 0
        attachment.endOfVertexSampleIndex = MTLCounterDontSample
        attachment.startOfFragmentSampleIndex = MTLCounterDontSample
        attachment.endOfFragmentSampleIndex = 1
        node.environmentValues.renderPassDescriptor = copy
        node.environmentValues.renderAttachmentFormats = RenderAttachmentFormats(copy)
    }

    func workloadEnter(_ node: Node) throws {
        guard let commandBuffer = node.environmentValues.commandBuffer else {
            return
        }
        guard let sampler = storage.sampler, let sampleBuffer = storage.sampleBuffer else {
            return
        }
        // MTLCounterSampleBuffer is not Sendable; it is only read inside the handler.
        nonisolated(unsafe) let unsafeSampleBuffer = sampleBuffer
        let label = label
        let handler = handler
        commandBuffer.addCompletedHandler { _ in
            if let sample = sampler.resolve(unsafeSampleBuffer, label: label) {
                handler(sample)
            }
        }
    }

    func workloadExit(_ node: Node) throws {
        // This line intentionally left blank.
    }

    nonisolated func requiresSetup(comparedTo old: GPUCountersModifier<Content>) -> Bool {
        false
    }
}

public extension Element {
    /// Samples GPU timestamps around a render pass and reports the elapsed GPU time.
    ///
    /// Apply this to a ``RenderPass``. It attaches a timestamp counter sample buffer
    /// to the pass descriptor and resolves it when the command buffer completes.
    ///
    /// ```swift
    /// try RenderPass {
    ///     // ...
    /// }
    /// .gpuCounters(label: "Main") { sample in
    ///     print("GPU: \((sample.duration ?? 0) * 1000) ms")
    /// }
    /// ```
    ///
    /// On devices that do not support counter sampling at stage boundaries the
    /// modifier logs a warning and does nothing.
    ///
    /// - Parameters:
    ///   - label: An optional label copied into the reported sample.
    ///   - handler: Called on an unspecified queue when the command buffer completes.
    func gpuCounters(label: String? = nil, _ handler: @escaping @Sendable (GPUCounterSample) -> Void) -> some Element {
        GPUCountersModifier(content: self, label: label, handler: handler)
    }
}
