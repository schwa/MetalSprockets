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
    /// Converted from GPU ticks with `MTLDevice.queryTimestampFrequency()`. `nil` when a timestamp is missing or
    /// out of order; never a fabricated zero.
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
    /// Always `nil` on Metal 4, which has no start-of-fragment sample. The pass ends when fragment work ends, so
    /// ``endTimestamp`` still marks the end of fragment work.
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

public extension Element {
    /// Samples GPU timestamps around the first render or compute pass inside this element and reports them after the
    /// submission completes.
    ///
    /// ```swift
    /// try RenderPass {
    ///     // ...
    /// }
    /// .gpuCounters(label: "Main") { sample in
    ///     logger.info("GPU: \((sample.duration ?? 0) * 1000) ms")
    /// }
    /// ```
    ///
    /// On Metal 4 a render pass reports its whole duration and a ``GPUCounterSample/vertex`` interval; the fragment
    /// interval is always `nil`. Failed or discarded work reports nothing. `handler` runs on the completion executor.
    func gpuCounters(label: String? = nil, _ handler: @escaping @Sendable (GPUCounterSample) -> Void) -> some Element {
        GPUCountersModifier(content: self, label: label, handler: handler)
    }
}
