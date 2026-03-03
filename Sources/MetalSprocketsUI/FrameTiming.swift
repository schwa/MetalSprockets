import Foundation

// MARK: - FrameTimingStatistics

/// Per-frame timing statistics computed from recent frame history.
///
/// Use this to display FPS counters, frame time graphs, or log performance data.
///
/// ## Example
///
/// ```swift
/// RenderView { context, size in
///     let fps = context.frameTimingStatistics.currentFPS
///     // ...
/// }
/// .onFrameTimingChange { statistics in
///     self.statistics = statistics
/// }
/// ```
public struct FrameTimingStatistics: Sendable, Equatable {
    /// Smoothed frames per second, computed over the rolling window.
    public var currentFPS: Double

    /// The raw delta time of the most recent frame, in seconds.
    public var deltaTime: TimeInterval

    /// The average delta time over the rolling window, in seconds.
    public var averageDeltaTime: TimeInterval

    /// The minimum delta time over the rolling window, in seconds.
    public var minDeltaTime: TimeInterval

    /// The maximum delta time over the rolling window, in seconds.
    public var maxDeltaTime: TimeInterval

    /// Total number of frames rendered since the render view started.
    public var frameCount: Int

    /// GPU execution time of the most recent completed frame, in seconds.
    ///
    /// This is `nil` until the first command buffer completion handler fires
    /// (typically one frame behind). Computed from
    /// `MTLCommandBuffer.gpuEndTime - gpuStartTime`.
    public var gpuTime: TimeInterval?

    public init(currentFPS: Double, deltaTime: TimeInterval, averageDeltaTime: TimeInterval, minDeltaTime: TimeInterval, maxDeltaTime: TimeInterval, frameCount: Int, gpuTime: TimeInterval? = nil) {
        self.currentFPS = currentFPS
        self.deltaTime = deltaTime
        self.averageDeltaTime = averageDeltaTime
        self.minDeltaTime = minDeltaTime
        self.maxDeltaTime = maxDeltaTime
        self.frameCount = frameCount
        self.gpuTime = gpuTime
    }
}

// MARK: - FrameTimingTracker

/// Internal tracker that accumulates frame timestamps and produces ``FrameTimingStatistics``.
///
/// Uses a ring buffer of recent frame deltas over a 1-second rolling window.
internal struct FrameTimingTracker: Sendable {
    /// Maximum number of samples to keep in the ring buffer.
    private static let maxSamples = 300

    /// Ring buffer of recent frame delta times (seconds).
    private var deltas: [TimeInterval] = []

    /// Index for the next write into the ring buffer.
    private var writeIndex: Int = 0

    /// Whether the ring buffer has wrapped around at least once.
    private var bufferFull: Bool = false

    /// Total number of frames recorded.
    private(set) var frameCount: Int = 0

    /// The timestamp of the previous frame (seconds, from `CACurrentMediaTime`).
    private var lastTimestamp: CFTimeInterval?

    /// GPU execution time from the most recently completed command buffer.
    var lastGPUTime: TimeInterval?

    /// Record a new frame at the given timestamp and return updated statistics.
    @discardableResult
    mutating func recordFrame(timestamp: CFTimeInterval) -> FrameTimingStatistics {
        let deltaTime: TimeInterval
        if let lastTimestamp {
            deltaTime = timestamp - lastTimestamp
        } else {
            deltaTime = 0
        }
        lastTimestamp = timestamp
        frameCount += 1

        // Write into ring buffer
        if deltas.count < Self.maxSamples {
            deltas.append(deltaTime)
        } else {
            deltas[writeIndex] = deltaTime
            bufferFull = true
        }
        writeIndex = (writeIndex + 1) % Self.maxSamples

        return computeStatistics(currentDeltaTime: deltaTime)
    }

    private func computeStatistics(currentDeltaTime: TimeInterval) -> FrameTimingStatistics {
        let sampleCount = bufferFull ? Self.maxSamples : deltas.count

        guard sampleCount > 0 else {
            return FrameTimingStatistics(
                currentFPS: 0,
                deltaTime: currentDeltaTime,
                averageDeltaTime: 0,
                minDeltaTime: 0,
                maxDeltaTime: 0,
                frameCount: frameCount,
                gpuTime: lastGPUTime
            )
        }

        // Only consider samples within the last 1 second for FPS/averages
        var sum: TimeInterval = 0
        var minDelta: TimeInterval = .greatestFiniteMagnitude
        var maxDelta: TimeInterval = 0
        var windowCount = 0
        var accumulated: TimeInterval = 0

        // Walk backwards from the most recently written sample
        for i in 0..<sampleCount {
            let index = (writeIndex - 1 - i + Self.maxSamples) % Self.maxSamples
            guard index < deltas.count else {
                break
            }
            let delta = deltas[index]
            accumulated += delta
            // Stop if we've exceeded 1 second of history
            if accumulated > 1.0 && windowCount > 0 {
                break
            }
            sum += delta
            minDelta = min(minDelta, delta)
            maxDelta = max(maxDelta, delta)
            windowCount += 1
        }

        let averageDelta = windowCount > 0 ? sum / Double(windowCount) : 0
        let fps = averageDelta > 0 ? 1.0 / averageDelta : 0

        return FrameTimingStatistics(
            currentFPS: fps,
            deltaTime: currentDeltaTime,
            averageDeltaTime: averageDelta,
            minDeltaTime: windowCount > 0 ? minDelta : 0,
            maxDeltaTime: maxDelta,
            frameCount: frameCount,
            gpuTime: lastGPUTime
        )
    }
}
