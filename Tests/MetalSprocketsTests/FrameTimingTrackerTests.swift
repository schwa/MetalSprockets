@testable import MetalSprocketsUI
import Testing

@Suite("FrameTimingTracker Tests")
struct FrameTimingTrackerTests {
    @Test("First frame has zero delta time")
    func firstFrameDelta() {
        var tracker = FrameTimingTracker()
        let stats = tracker.recordFrame(timestamp: 1.0)
        #expect(stats.deltaTime == 0)
        #expect(stats.frameCount == 1)
    }

    @Test("Steady 60 FPS produces expected statistics")
    func steady60FPS() {
        var tracker = FrameTimingTracker()
        let dt = 1.0 / 60.0
        // Record enough frames to fill the window
        for i in 0..<120 {
            tracker.recordFrame(timestamp: Double(i) * dt)
        }
        let stats = tracker.recordFrame(timestamp: 120.0 * dt)
        #expect(stats.frameCount == 121)
        #expect(stats.currentFPS > 59)
        #expect(stats.currentFPS < 61)
        #expect(stats.deltaTime > 0.016)
        #expect(stats.deltaTime < 0.017)
        #expect(stats.averageDeltaTime > 0.016)
        #expect(stats.averageDeltaTime < 0.017)
    }

    @Test("Min and max track extremes")
    func minMaxDelta() {
        var tracker = FrameTimingTracker()
        // Frame 0
        tracker.recordFrame(timestamp: 0.0)
        // Frame 1: 16ms delta
        tracker.recordFrame(timestamp: 0.016)
        // Frame 2: 33ms delta (a stutter)
        tracker.recordFrame(timestamp: 0.049)
        // Frame 3: 8ms delta (fast)
        let stats = tracker.recordFrame(timestamp: 0.057)

        #expect(stats.frameCount == 4)
        #expect(stats.minDeltaTime == 0.0) // First frame has 0 delta
        #expect(stats.maxDeltaTime > 0.032)
        #expect(stats.maxDeltaTime < 0.034)
    }

    @Test("Rolling window limits to 1 second of history")
    func rollingWindow() {
        var tracker = FrameTimingTracker()
        // Record 2 seconds of slow frames (10 FPS)
        for i in 0..<20 {
            tracker.recordFrame(timestamp: Double(i) * 0.1)
        }
        // Then 1 second of fast frames (60 FPS)
        let baseTime = 2.0
        for i in 0..<60 {
            tracker.recordFrame(timestamp: baseTime + Double(i) * (1.0 / 60.0))
        }
        let stats = tracker.recordFrame(timestamp: baseTime + 1.0)

        // The FPS should reflect the recent 60 FPS window, not the old 10 FPS
        #expect(stats.currentFPS > 50)
    }

    @Test("Frame count increments correctly")
    func frameCount() {
        var tracker = FrameTimingTracker()
        for i in 0..<10 {
            tracker.recordFrame(timestamp: Double(i) * 0.016)
        }
        let stats = tracker.recordFrame(timestamp: 10.0 * 0.016)
        #expect(stats.frameCount == 11)
    }

    @Test("Ring buffer wraps after exceeding maxSamples (300)")
    func ringBufferWrap() {
        var tracker = FrameTimingTracker()
        let dt = 1.0 / 60.0
        // Record more than maxSamples (300) frames to force ring-buffer wrap.
        // Use a steady 60 FPS cadence so the rolling-window stats remain stable.
        for i in 0..<400 {
            tracker.recordFrame(timestamp: Double(i) * dt)
        }
        let stats = tracker.recordFrame(timestamp: 400.0 * dt)
        #expect(stats.frameCount == 401)
        // After wrapping, the tracker should still report sensible 60 FPS stats
        // drawn from the 1-second rolling window.
        #expect(stats.currentFPS > 59)
        #expect(stats.currentFPS < 61)
    }

    @Test("lastGPUTime is surfaced via statistics")
    func gpuTimeSurfaced() {
        var tracker = FrameTimingTracker()
        tracker.recordFrame(timestamp: 0.0)
        // Before any completion, gpuTime is nil.
        let before = tracker.recordFrame(timestamp: 0.016)
        #expect(before.gpuTime == nil)

        // Simulate a command-buffer completion updating the GPU time.
        tracker.lastGPUTime = 0.0042
        let after = tracker.recordFrame(timestamp: 0.032)
        #expect(after.gpuTime == 0.0042)
    }
}
