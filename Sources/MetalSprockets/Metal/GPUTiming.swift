import Foundation
import Metal
import MetalSprocketsSupport
import os

// MARK: - Public API

/// A GPU interval measured by ``Element/gpuTimed(_:)`` and reported by ``Element/onGPUTimings(_:)``.
public struct GPUTiming: Sendable, Equatable {
    public var label: String
    /// Raw GPU timestamps, in GPU ticks.
    public var startTimestamp: MTLTimestamp
    public var endTimestamp: MTLTimestamp
    /// Elapsed GPU time in seconds.
    public var duration: TimeInterval

    public init(label: String, startTimestamp: MTLTimestamp, endTimestamp: MTLTimestamp, duration: TimeInterval) {
        self.label = label
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.duration = duration
    }
}

public extension Element {
    /// Measures the GPU time of the passes in this subtree, from the start of the first ``RenderPass`` or
    /// ``ComputePass`` to the end of the last. The nearest enclosing ``onGPUTimings(_:)`` gets the results.
    /// If there is no such modifier, this modifier does nothing.
    ///
    /// Apple GPUs time at pass boundaries only, so place this on or above a pass. Inside a pass it measures nothing and
    /// logs a warning. To time a smaller piece of work, put it in its own pass.
    ///
    /// Consecutive passes can run at the same time on the GPU, so a pass's interval can include time spent waiting for
    /// or overlapping with earlier passes. Read these intervals as a profile of the real frame, not as isolated costs.
    /// While investigating, a barrier between the passes (for example
    /// ``Element/barrierAfterPass(after:beforeQueueStages:visibility:)`` on the pass before) gives an isolated number.
    /// Do not keep such a barrier in production code: it serializes the passes and makes the frame slower.
    ///
    /// ```swift
    /// Group {
    ///     RenderPass { ... }.gpuTimed("shadows")
    ///     RenderPass { ... }.gpuTimed("main")
    /// }
    /// .gpuTimed("frame")
    /// .onGPUTimings { timings in ... }
    /// ```
    func gpuTimed(_ label: String) -> some Element {
        GPUTimedModifier(content: self, label: label)
    }

    /// Delivers the ``GPUTiming`` intervals from every ``gpuTimed(_:)`` in this subtree, in traversal order, once per
    /// submission after the GPU completes it.
    ///
    /// Failed or discarded work reports nothing. Intervals the GPU did not record (for example a `gpuTimed` subtree that
    /// encoded no pass) are left out. `handler` runs on the completion executor.
    func onGPUTimings(_ handler: @escaping @Sendable ([GPUTiming]) -> Void) -> some Element {
        GPUTimingsModifier(content: self, handler: handler)
    }
}

// MARK: - Heap pool

/// Fixed-size timestamp heaps, reused once the submission that wrote them terminates.
internal final class GPUTimingHeapPool: @unchecked Sendable {
    static let heapCapacity = 64

    let device: any MTLDevice
    let ticksPerSecond: UInt64
    private let makeHeap: CounterHeapFactory
    private let pool = OSAllocatedUnfairLock<[any MTL4CounterHeap]>(uncheckedState: [])
    private let createdCount = OSAllocatedUnfairLock(initialState: 0)
    private let hasWarned = OSAllocatedUnfairLock(initialState: false)

    init(device: any MTLDevice, makeHeap: CounterHeapFactory? = nil) throws {
        guard device.supportsFamily(.metal4) else {
            throw MetalSprocketsError.deviceCababilityFailure("Device '\(device.name)' does not support Metal 4 counter heaps.")
        }
        let frequency = device.queryTimestampFrequency()
        guard frequency > 0 else {
            throw MetalSprocketsError.deviceCababilityFailure("Device '\(device.name)' reports no GPU timestamp frequency.")
        }
        self.device = device
        ticksPerSecond = frequency
        self.makeHeap = makeHeap ?? CounterHeapFactory { try device.makeCounterHeap(descriptor: $0) }
    }

    var heapCount: Int { createdCount.withLock { $0 } }

    func checkOut() throws -> any MTL4CounterHeap {
        if let reused = pool.withLockUnchecked({ $0.popLast() }) {
            return reused
        }
        let descriptor = MTL4CounterHeapDescriptor()
        descriptor.type = .timestamp
        descriptor.count = Self.heapCapacity
        let heap = try makeHeap.make(descriptor)
        heap.label = "MetalSprockets GPU timings"
        heap.invalidateCounterRange(0..<Self.heapCapacity)
        createdCount.withLock { $0 += 1 }
        return heap
    }

    /// Metal limits how many counter heaps can exist (32 were seen on an M5 Max). When creation fails, timings are
    /// dropped and the frame still renders (#493). Logs once per pool.
    func checkOutIfAvailable() -> (any MTL4CounterHeap)? {
        do {
            return try checkOut()
        } catch {
            if !hasWarned.withLock({ warned in defer { warned = true }; return warned }) {
                logger?.warning("Could not create a GPU timestamp heap, so GPU timings are skipped: \(error)")
            }
            return nil
        }
    }

    func checkIn(_ heap: any MTL4CounterHeap) {
        heap.invalidateCounterRange(0..<Self.heapCapacity)
        pool.withLockUnchecked { $0.append(heap) }
    }
}

// MARK: - Per-submission collector

/// A timestamp slot: a heap leased by one collector, and an index in it.
internal struct GPUTimingLocation: Equatable {
    let heap: Int
    let index: Int
}

/// One `gpuTimed` interval. `start` and `end` are where its timestamps are written. When two writes share a point on
/// a compute encoder, this can be the slot of another entry.
internal final class GPUTimingEntry {
    let label: String
    let reserved: GPUTimingLocation
    var start: GPUTimingLocation?
    var end: GPUTimingLocation?
    private(set) var hasStarted = false

    init(label: String, reserved: GPUTimingLocation) {
        self.label = label
        self.reserved = reserved
    }

    var reservedEnd: GPUTimingLocation { GPUTimingLocation(heap: reserved.heap, index: reserved.index + 1) }

    /// For entries outside a pass: true for the first pass beneath it only.
    func markStarted() -> Bool {
        defer { hasStarted = true }
        return !hasStarted
    }
}

/// Collects the intervals of one submission. Encoding writes it. After encoding ends, the completion executor reads it.
/// The lock protects the hand-off.
internal final class GPUTimingCollector: @unchecked Sendable {
    private struct State {
        var heaps: [any MTL4CounterHeap] = []
        var nextIndex = GPUTimingHeapPool.heapCapacity
        var entries: [GPUTimingEntry] = []
    }

    let pool: GPUTimingHeapPool
    private let state = OSAllocatedUnfairLock<State>(uncheckedState: State())

    init(pool: GPUTimingHeapPool) {
        self.pool = pool
    }

    deinit {
        for heap in state.withLockUnchecked({ $0.heaps }) {
            pool.checkIn(heap)
        }
    }

    func heap(_ location: GPUTimingLocation) -> any MTL4CounterHeap {
        state.withLockUnchecked { $0.heaps[location.heap] }
    }

    /// Reserves a start and end slot for `label`, leasing another heap when the current one is full.
    /// Returns nil if no heap is available; the interval is then not measured.
    func reserve(_ label: String, scope: RecordingScope) throws -> GPUTimingEntry? {
        if state.withLockUnchecked({ $0.nextIndex + 2 > GPUTimingHeapPool.heapCapacity }) {
            guard let heap = pool.checkOutIfAvailable() else {
                return nil
            }
            try scope.retainObject(heap)
            state.withLockUnchecked { state in
                state.heaps.append(heap)
                state.nextIndex = 0
            }
        }
        return state.withLockUnchecked { state in
            let entry = GPUTimingEntry(label: label, reserved: GPUTimingLocation(heap: state.heaps.count - 1, index: state.nextIndex))
            state.nextIndex += 2
            state.entries.append(entry)
            return entry
        }
    }

    func write(_ location: GPUTimingLocation, on pass: RenderPassEncoder, afterStage stage: MTLRenderStages) throws -> GPUTimingLocation {
        try pass.writeTimestamp(afterStage: stage, into: heap(location), index: location.index)
        return location
    }

    func write(_ location: GPUTimingLocation, on pass: ComputePassEncoder) throws -> GPUTimingLocation {
        try pass.writeSharedTimestamp(owner: self, location: location, into: heap(location))
    }

    func resolve() -> [GPUTiming] {
        let (heaps, entries) = state.withLockUnchecked { ($0.heaps, $0.entries) }
        let resolved: [[UInt64]] = heaps.map { heap in
            guard let data = try? heap.resolveCounterRange(0..<GPUTimingHeapPool.heapCapacity) else {
                return []
            }
            return data.withUnsafeBytes { $0.bindMemory(to: MTL4TimestampHeapEntry.self).map(\.timestamp) }
        }
        func timestamp(_ location: GPUTimingLocation?) -> UInt64 {
            guard let location, resolved[location.heap].count == GPUTimingHeapPool.heapCapacity else {
                return 0
            }
            return resolved[location.heap][location.index]
        }
        return entries.compactMap { entry in
            let start = timestamp(entry.start)
            let end = timestamp(entry.end)
            // Invalidated or never-written entries resolve to 0.
            guard start != 0, end != 0, end >= start else {
                return nil
            }
            return GPUTiming(label: entry.label, startTimestamp: start, endTimestamp: end, duration: Double(end - start) / Double(pool.ticksPerSecond))
        }
    }
}

/// A `gpuTimed` placed outside any pass, waiting for passes beneath it to write its start and end.
internal struct GPUTimingPassRequest {
    let collector: GPUTimingCollector
    let entry: GPUTimingEntry
}

internal struct GPUTimingPassRequestsKey: MSEnvironmentKey {
    static var defaultValue: [GPUTimingPassRequest] { [] }
}

internal extension MSEnvironmentValues {
    @MSEntry var gpuTimingCollector: GPUTimingCollector?

    var gpuTimingPassRequests: [GPUTimingPassRequest] {
        get { self[GPUTimingPassRequestsKey.self] }
        set { self[GPUTimingPassRequestsKey.self] = newValue }
    }
}

internal extension RenderPassEncoder {
    func beginGPUTimings(_ requests: [GPUTimingPassRequest]) throws {
        for request in requests where request.entry.markStarted() {
            request.entry.start = try request.collector.write(request.entry.reserved, on: self, afterStage: .vertex)
        }
    }

    // Every pass writes the end, so the last pass beneath the request wins.
    func endGPUTimings(_ requests: [GPUTimingPassRequest]) throws {
        for request in requests.reversed() {
            request.entry.end = try request.collector.write(request.entry.reservedEnd, on: self, afterStage: .fragment)
        }
    }
}

internal extension ComputePassEncoder {
    func beginGPUTimings(_ requests: [GPUTimingPassRequest]) throws {
        for request in requests where request.entry.markStarted() {
            request.entry.start = try request.collector.write(request.entry.reserved, on: self)
        }
    }

    func endGPUTimings(_ requests: [GPUTimingPassRequest]) throws {
        for request in requests.reversed() {
            request.entry.end = try request.collector.write(request.entry.reservedEnd, on: self)
        }
    }
}

// MARK: - Modifiers

internal final class GPUTimingsCache: NodeElementCache {
    var pool: GPUTimingHeapPool?
}

internal struct GPUTimingsModifier<Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var handler: @Sendable ([GPUTiming]) -> Void

    func workloadEnter(_ node: Node) throws {
        let context = try node.environmentValues.metalContext.orThrow(.missingEnvironment("metalContext"))
        let scope = try node.environmentValues.recordingScope.orThrow(.missingEnvironment("recordingScope"))
        let cache = node.cache(GPUTimingsCache.self) { GPUTimingsCache() }
        if cache.pool == nil {
            cache.pool = try GPUTimingHeapPool(device: context.device, makeHeap: node.environmentValues.counterHeapFactory)
        }
        let pool = try cache.pool.orThrow(.generic("GPU timing heap pool missing"))
        let collector = GPUTimingCollector(pool: pool)
        node.environmentValues.gpuTimingCollector = collector
        // A nested onGPUTimings starts its own set of outside-pass requests.
        node.environmentValues.gpuTimingPassRequests = []
        let handler = handler
        // The collector, and so its leased heaps, lives until the handler is released after termination.
        try scope.onTerminated { result in
            guard result.outcome == .completed else {
                return
            }
            handler(collector.resolve())
        }
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

internal final class GPUTimedCache: NodeElementCache {
    var hasWarned = false
}

internal struct GPUTimedModifier<Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var label: String

    func workloadEnter(_ node: Node) throws {
        guard let collector = node.environmentValues.gpuTimingCollector else {
            return
        }
        // Apple GPUs only time at pass and stage boundaries (no draw or dispatch boundary sampling), so a timestamp
        // inside a pass does not measure the subtree.
        guard node.environmentValues.renderPassEncoder == nil, node.environmentValues.computePassEncoder == nil else {
            let cache = node.cache(GPUTimedCache.self) { GPUTimedCache() }
            if !cache.hasWarned {
                cache.hasWarned = true
                logger?.warning("gpuTimed(\"\(label)\") is inside a pass and measures nothing. Place it on or above a RenderPass or ComputePass.")
            }
            return
        }
        let scope = try node.environmentValues.recordingScope.orThrow(.missingEnvironment("recordingScope"))
        guard let entry = try collector.reserve(label, scope: scope) else {
            return
        }
        // Start from the parent's list: this node's own write from the previous frame would otherwise accumulate.
        node.environmentValues.gpuTimingPassRequests = node.environmentValues.inheritedValue(GPUTimingPassRequestsKey.self) + [GPUTimingPassRequest(collector: collector, entry: entry)]
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}
