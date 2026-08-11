import Foundation
import Metal
import os

// MARK: - GPUCounterSample

/// Resolved GPU timestamps for a single render or compute pass.
///
/// Produced by the ``Element/gpuCounters(label:_:)`` modifier.
public struct GPUCounterSample: Sendable, Equatable {
    /// A pair of GPU timestamps bounding one stage of a pass.
    public struct Interval: Sendable, Equatable {
        /// Raw GPU timestamp taken at the start of the stage, in GPU ticks.
        public var startTimestamp: MTLTimestamp

        /// Raw GPU timestamp taken at the end of the stage, in GPU ticks.
        public var endTimestamp: MTLTimestamp

        /// Elapsed GPU time for the stage, in seconds. `nil` if tick-to-seconds correlation was not possible.
        public var duration: TimeInterval?

        public init(startTimestamp: MTLTimestamp, endTimestamp: MTLTimestamp, duration: TimeInterval? = nil) {
            self.startTimestamp = startTimestamp
            self.endTimestamp = endTimestamp
            self.duration = duration
        }
    }

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

    /// The vertex-stage interval of a render pass.
    ///
    /// `nil` for compute passes or when the GPU did not report the stage samples.
    ///
    /// - Note: On tile-based deferred renderers (Apple GPUs) the vertex and fragment
    ///   stages overlap, so `vertex.duration + fragment.duration` can exceed ``duration``.
    public var vertex: Interval?

    /// The fragment-stage interval of a render pass.
    ///
    /// `nil` for compute passes or when the GPU did not report the stage samples.
    public var fragment: Interval?

    public init(label: String? = nil, startTimestamp: MTLTimestamp, endTimestamp: MTLTimestamp, duration: TimeInterval? = nil, vertex: Interval? = nil, fragment: Interval? = nil) {
        self.label = label
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.duration = duration
        self.vertex = vertex
        self.fragment = fragment
    }
}

/// The fixed sample-buffer layout used by ``Element/gpuCounters(label:_:)``.
///
/// Render passes fill indices 0...3 (stage boundaries); compute passes fill 4...5
/// (encoder boundaries). ``GPUCounterSampler/resolve(_:label:)`` expects this layout.
public enum GPUCounterSampleIndex {
    public static let vertexStart = 0
    public static let vertexEnd = 1
    public static let fragmentStart = 2
    public static let fragmentEnd = 3
    public static let computeStart = 4
    public static let computeEnd = 5
    public static let count = 6
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
    public func makeSampleBuffer(capacity: Int = GPUCounterSampleIndex.count) -> MTLCounterSampleBuffer? {
        let descriptor = MTLCounterSampleBufferDescriptor()
        descriptor.counterSet = counterSet
        descriptor.storageMode = .shared
        descriptor.sampleCount = capacity
        return try? device.makeCounterSampleBuffer(descriptor: descriptor)
    }

    /// Resolves the timestamps in `sampleBuffer` into a sample.
    ///
    /// Expects the layout written by ``Element/gpuCounters(label:_:)``: render stage
    /// boundaries first, compute encoder boundaries after. Returns the render sample
    /// (with per-stage intervals when available), falling back to the compute sample,
    /// or `nil` if neither was taken.
    public func resolve(_ sampleBuffer: MTLCounterSampleBuffer, label: String? = nil) -> GPUCounterSample? {
        guard let data = try? sampleBuffer.resolveCounterRange(0..<GPUCounterSampleIndex.count) else {
            return nil
        }
        let timestamps: [MTLTimestamp] = data.withUnsafeBytes { buffer in
            let results = buffer.bindMemory(to: MTLCounterResultTimestamp.self)
            return results.prefix(GPUCounterSampleIndex.count).map(\.timestamp)
        }
        guard timestamps.count == GPUCounterSampleIndex.count else {
            return nil
        }

        func interval(_ startIndex: Int, _ endIndex: Int) -> GPUCounterSample.Interval? {
            let start = timestamps[startIndex]
            let end = timestamps[endIndex]
            // 0 marks a sample the GPU never took; MTLCounterErrorValue one it could not take.
            guard start != 0, end != 0, start != MTLCounterErrorValue, end != MTLCounterErrorValue, end >= start else {
                return nil
            }
            return GPUCounterSample.Interval(startTimestamp: start, endTimestamp: end, duration: seconds(forTicks: end - start))
        }

        if let pass = interval(GPUCounterSampleIndex.vertexStart, GPUCounterSampleIndex.fragmentEnd) {
            let vertex = interval(GPUCounterSampleIndex.vertexStart, GPUCounterSampleIndex.vertexEnd)
            let fragment = interval(GPUCounterSampleIndex.fragmentStart, GPUCounterSampleIndex.fragmentEnd)
            return GPUCounterSample(label: label, startTimestamp: pass.startTimestamp, endTimestamp: pass.endTimestamp, duration: pass.duration, vertex: vertex, fragment: fragment)
        }
        if let pass = interval(GPUCounterSampleIndex.computeStart, GPUCounterSampleIndex.computeEnd) {
            return GPUCounterSample(label: label, startTimestamp: pass.startTimestamp, endTimestamp: pass.endTimestamp, duration: pass.duration)
        }
        return nil
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
        guard let sampler = storage.sampler(makingWith: device), let sampleBuffer = sampler.makeSampleBuffer() else {
            logger?.warning("gpuCounters: GPU counter sampling unavailable on this device; counters disabled.")
            return
        }
        storage.setSampleBuffer(sampleBuffer)

        // The modifier cannot see whether its content is a render or a compute pass, so it
        // publishes both descriptors into disjoint regions of one sample buffer; whichever
        // pass runs writes its region and resolve() picks the populated one.
        let parent = system.traversalContext.parentNode
        if let renderPassDescriptor = parent?.environmentValues.renderPassDescriptor ?? node.environmentValues.renderPassDescriptor {
            let copy = renderPassDescriptor.copyWithType(MTLRenderPassDescriptor.self)
            if let attachment = copy.sampleBufferAttachments[0] {
                attachment.sampleBuffer = sampleBuffer
                attachment.startOfVertexSampleIndex = GPUCounterSampleIndex.vertexStart
                attachment.endOfVertexSampleIndex = GPUCounterSampleIndex.vertexEnd
                attachment.startOfFragmentSampleIndex = GPUCounterSampleIndex.fragmentStart
                attachment.endOfFragmentSampleIndex = GPUCounterSampleIndex.fragmentEnd
                node.environmentValues.renderPassDescriptor = copy
                node.environmentValues.renderAttachmentFormats = RenderAttachmentFormats(copy)
            }
        }

        let computePassDescriptor = (parent?.environmentValues.computePassDescriptor ?? node.environmentValues.computePassDescriptor)?.copyWithType(MTLComputePassDescriptor.self) ?? MTLComputePassDescriptor()
        if let attachment = computePassDescriptor.sampleBufferAttachments[0] {
            attachment.sampleBuffer = sampleBuffer
            attachment.startOfEncoderSampleIndex = GPUCounterSampleIndex.computeStart
            attachment.endOfEncoderSampleIndex = GPUCounterSampleIndex.computeEnd
            node.environmentValues.computePassDescriptor = computePassDescriptor
        }
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
    /// Samples GPU timestamps around a render or compute pass and reports the elapsed GPU time.
    ///
    /// Apply this to a ``RenderPass`` or a ``ComputePass``. It attaches a timestamp
    /// counter sample buffer to the pass descriptor and resolves it when the command
    /// buffer completes.
    ///
    /// ```swift
    /// try RenderPass {
    ///     // ...
    /// }
    /// .gpuCounters(label: "Main") { sample in
    ///     print("GPU: \((sample.duration ?? 0) * 1000) ms")
    ///     if let vertex = sample.vertex, let fragment = sample.fragment {
    ///         print("vertex: \((vertex.duration ?? 0) * 1000) ms, fragment: \((fragment.duration ?? 0) * 1000) ms")
    ///     }
    /// }
    /// ```
    ///
    /// Render passes report per-stage intervals via ``GPUCounterSample/vertex`` and
    /// ``GPUCounterSample/fragment``; compute passes report whole-encoder time only.
    /// Apply the modifier to one pass at a time — wrapping a group that contains both
    /// a render and a compute pass reports only the render pass.
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
