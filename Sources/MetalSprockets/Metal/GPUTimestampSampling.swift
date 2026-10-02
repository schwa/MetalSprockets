import Foundation
import Metal
import MetalSprocketsSupport
import os

/// GPU timestamps for one render or compute pass, sampled into a Metal 4 counter heap.
///
/// Mapping from the legacy stage-boundary samples:
/// - Render: the pass start is taken before the vertex stage begins, the vertex end after all draws finish the vertex
///   stage, and the pass end after they finish the fragment stage. `vertex` is start to vertex end. Metal 4 has no
///   start-of-fragment sample, so `fragment` is always nil; no value is invented for it.
/// - Compute: start and end of the encoder.
/// Ticks convert with `queryTimestampFrequency()`. A zero or reversed timestamp makes the interval nil, never zero.
internal final class TimestampSampler: @unchecked Sendable {
    enum Index {
        static let start = 0
        static let vertexEnd = 1
        static let end = 2
        static let count = 3
    }

    /// Heap contents are only touched on the pool lock or after the owning submission terminates.
    final class Heap: @unchecked Sendable {
        let heap: any MTL4CounterHeap
        fileprivate init(_ heap: any MTL4CounterHeap) { self.heap = heap }
    }

    let device: any MTLDevice
    let ticksPerSecond: UInt64
    private let pool = OSAllocatedUnfairLock<[Heap]>(uncheckedState: [])
    private let createdCount = OSAllocatedUnfairLock(initialState: 0)

    init(device: any MTLDevice) throws {
        guard device.supportsFamily(.metal4) else {
            throw MetalSprocketsError.deviceCababilityFailure("Device '\(device.name)' does not support Metal 4 counter heaps.")
        }
        let frequency = device.queryTimestampFrequency()
        guard frequency > 0 else {
            throw MetalSprocketsError.deviceCababilityFailure("Device '\(device.name)' reports no GPU timestamp frequency.")
        }
        self.device = device
        ticksPerSecond = frequency
    }

    var heapCount: Int { createdCount.withLock { $0 } }

    /// A heap not used by any in-flight submission, with its entries invalidated.
    private func checkOut() throws -> Heap {
        if let reused = pool.withLockUnchecked({ $0.popLast() }) {
            return reused
        }
        let descriptor = MTL4CounterHeapDescriptor()
        descriptor.type = .timestamp
        descriptor.count = Index.count
        let heap = try device.makeCounterHeap(descriptor: descriptor)
        heap.label = "MetalSprockets timestamps"
        heap.invalidateCounterRange(0..<Index.count)
        createdCount.withLock { $0 += 1 }
        return Heap(heap)
    }

    /// Returns the heap to the pool when the last reference goes away: after the terminal handler of a committed
    /// recording runs, or when a discarded recording drops its handlers. Either way the GPU no longer uses it.
    final class Lease: @unchecked Sendable {
        let heap: Heap
        private let sampler: TimestampSampler

        fileprivate init(heap: Heap, sampler: TimestampSampler) {
            self.heap = heap
            self.sampler = sampler
        }

        deinit {
            sampler.checkIn(heap)
        }
    }

    func lease() throws -> Lease {
        Lease(heap: try checkOut(), sampler: self)
    }

    private func checkIn(_ heap: Heap) {
        heap.heap.invalidateCounterRange(0..<Index.count)
        pool.withLockUnchecked { $0.append(heap) }
    }

    func resolve(_ heap: Heap, isRender: Bool, label: String?) -> GPUCounterSample? {
        guard let data = try? heap.heap.resolveCounterRange(0..<Index.count) else {
            return nil
        }
        let timestamps: [UInt64] = data.withUnsafeBytes { buffer in
            buffer.bindMemory(to: MTL4TimestampHeapEntry.self).map(\.timestamp)
        }
        guard timestamps.count == Index.count else {
            return nil
        }
        let endIndex = isRender ? Index.end : Index.vertexEnd
        guard let pass = interval(timestamps[Index.start], timestamps[endIndex]) else {
            return nil
        }
        let vertex = isRender ? interval(timestamps[Index.start], timestamps[Index.vertexEnd]) : nil
        return GPUCounterSample(label: label, startTimestamp: pass.startTimestamp, endTimestamp: pass.endTimestamp, duration: pass.duration, vertex: vertex, fragment: nil)
    }

    func interval(_ start: UInt64, _ end: UInt64) -> GPUCounterSample.Interval? {
        // Invalidated or never-written entries resolve to 0.
        guard start != 0, end != 0, end >= start else {
            return nil
        }
        return GPUCounterSample.Interval(startTimestamp: start, endTimestamp: end, duration: Double(end - start) / Double(ticksPerSecond))
    }
}

/// A pending timestamp sample, claimed by the first pass that opens beneath the counters modifier.
internal final class TimestampRequest {
    let heap: TimestampSampler.Heap
    private(set) var owner: ObjectIdentifier?
    private(set) var isRender = false

    init(heap: TimestampSampler.Heap) {
        self.heap = heap
    }

    func claim(_ pass: AnyObject, isRender: Bool) -> Bool {
        guard owner == nil else {
            return false
        }
        owner = ObjectIdentifier(pass)
        self.isRender = isRender
        return true
    }

    func isOwned(by pass: AnyObject) -> Bool {
        owner == ObjectIdentifier(pass)
    }

    var isClaimed: Bool { owner != nil }
}

internal extension MSEnvironmentValues {
    @MSEntry var timestampRequest: TimestampRequest?
}

internal extension RenderPassEncoder {
    func beginTimestamps(_ request: TimestampRequest?) throws {
        guard let request, request.claim(self, isRender: true) else {
            return
        }
        try writeTimestamp(afterStage: .vertex, into: request.heap.heap, index: TimestampSampler.Index.start)
    }

    func endTimestamps(_ request: TimestampRequest?) throws {
        guard let request, request.isOwned(by: self) else {
            return
        }
        try writeTimestamp(afterStage: .vertex, into: request.heap.heap, index: TimestampSampler.Index.vertexEnd)
        try writeTimestamp(afterStage: .fragment, into: request.heap.heap, index: TimestampSampler.Index.end)
    }
}

internal extension ComputePassEncoder {
    func beginTimestamps(_ request: TimestampRequest?) throws {
        guard let request, request.claim(self, isRender: false) else {
            return
        }
        try writeTimestamp(into: request.heap.heap, index: TimestampSampler.Index.start)
    }

    func endTimestamps(_ request: TimestampRequest?) throws {
        guard let request, request.isOwned(by: self) else {
            return
        }
        try writeTimestamp(into: request.heap.heap, index: TimestampSampler.Index.vertexEnd)
    }
}

/// Samples the first render or compute pass in its content and reports a `GPUCounterSample` after the submission
/// completes. Failed, cancelled or discarded work reports nothing; the heap returns to the pool either way.
internal final class GPUCountersCache: NodeElementCache {
    var sampler: TimestampSampler?
}

internal struct GPUCountersModifier<Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var label: String?
    var handler: @Sendable (GPUCounterSample) -> Void

    func workloadEnter(_ node: Node) throws {
        let context = try node.environmentValues.metalContext.orThrow(.missingEnvironment("metalContext"))
        let scope = try node.environmentValues.recordingScope.orThrow(.missingEnvironment("recordingScope"))
        let cache = node.cache(GPUCountersCache.self) { GPUCountersCache() }
        if cache.sampler == nil {
            cache.sampler = try TimestampSampler(device: context.device)
        }
        let sampler = try cache.sampler.orThrow(.generic("Timestamp sampler missing"))
        let lease = try sampler.lease()
        let request = TimestampRequest(heap: lease.heap)
        node.environmentValues.timestampRequest = request
        try scope.retainObject(lease.heap.heap)
        let label = label
        let handler = handler
        // Read on the completion thread only after the recording's passes have been encoded.
        nonisolated(unsafe) let pending = request
        try scope.onTerminated { result in
            guard result.outcome == .completed, pending.isClaimed, let sample = sampler.resolve(lease.heap, isRender: pending.isRender, label: label) else {
                return
            }
            handler(sample)
        }
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}
