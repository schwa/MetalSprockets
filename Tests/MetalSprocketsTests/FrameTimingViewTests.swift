@testable import MetalSprocketsUI
import SwiftUI
import Testing

@Suite("FrameTimingView FPS colour")
struct FrameTimingViewTests {
    @Test func `sixty fps is green on a sixty hertz target`() {
        #expect(FrameTimingView.fpsColor(for: 60, targetFramesPerSecond: 60) == .green)
    }

    @Test func `sixty fps is only yellow on a one-twenty hertz target`() {
        #expect(FrameTimingView.fpsColor(for: 60, targetFramesPerSecond: 120) == .yellow)
    }

    @Test func `one-twenty fps is green on a one-twenty hertz target`() {
        #expect(FrameTimingView.fpsColor(for: 120, targetFramesPerSecond: 120) == .green)
    }

    @Test func `below half the target is red`() {
        #expect(FrameTimingView.fpsColor(for: 29, targetFramesPerSecond: 60) == .red)
        #expect(FrameTimingView.fpsColor(for: 59, targetFramesPerSecond: 120) == .red)
    }

    @Test func `a nonsensical target falls back to sixty`() {
        #expect(FrameTimingView.fpsColor(for: 58, targetFramesPerSecond: 0) == .green)
    }

    @Test func `the display refresh rate is a sane default`() {
        #expect(FrameTimingView.displayMaximumFramesPerSecond >= 24)
    }
}
