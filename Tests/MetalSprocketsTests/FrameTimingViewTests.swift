@testable import MetalSprocketsUI
import SwiftUI
import Testing
import ViewInspector

@MainActor
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

@MainActor
@Suite("FrameTimingView rendering")
struct FrameTimingViewRenderingTests {
    private static let statistics = FrameTimingStatistics(
        currentFPS: 59.94,
        deltaTime: 0.0167,
        averageDeltaTime: 0.0166,
        minDeltaTime: 0.0145,
        maxDeltaTime: 0.0201,
        frameCount: 4_827,
        gpuTime: 0.0021
    )

    private func rows(_ options: FrameTimingDisplayOptions, statistics: FrameTimingStatistics = statistics) -> [FrameTimingView.Row] {
        FrameTimingView.rows(for: statistics, options: options, targetFramesPerSecond: 60)
    }

    @Test func `the default options show only fps`() {
        let rows = rows(.default)
        #expect(rows.map(\.label) == ["FPS"])
        #expect(rows[0].value == "60")
        #expect(rows[0].valueColor == .green)
    }

    @Test func `every option renders its own row, in display order`() {
        #expect(rows(.all).map(\.label) == ["FPS", "Frame", "1s Range", "GPU", "Frame #"])
    }

    @Test func `frame times are shown in milliseconds`() {
        let value = rows([.frameTime])[0].value
        #expect(value.contains("16.7"))
        #expect(value.contains("ms"))
    }

    @Test func `the range row spans min to max`() {
        let value = rows([.range])[0].value
        #expect(value.contains("14.5"))
        #expect(value.contains("20.1"))
        #expect(value.contains("–"))
    }

    @Test func `the frame count row shows the raw count`() {
        #expect(rows([.frameCount]).first?.value == "4827")
    }

    @Test func `a missing gpu time hides the gpu row`() {
        var statistics = Self.statistics
        statistics.gpuTime = nil
        #expect(rows(.all, statistics: statistics).map(\.label).contains("GPU") == false)
    }

    @Test func `only the fps row is coloured`() {
        let rows = rows(.all)
        #expect(rows.filter { $0.valueColor != nil }.map(\.label) == ["FPS"])
    }

    @Test func `the view renders without a statistics snapshot yet`() throws {
        let view = FrameTimingView(statistics: Self.statistics, options: .all)
        #expect(throws: Never.self) {
            _ = try view.inspect()
        }
    }

    @Test func `display options compose`() {
        #expect(FrameTimingDisplayOptions.default == [.fps])
        #expect(FrameTimingDisplayOptions.all.contains(.gpuTime))
        #expect(FrameTimingDisplayOptions.all.contains(.range))
        #expect(FrameTimingDisplayOptions(rawValue: 1 << 0) == .fps)
    }
}
