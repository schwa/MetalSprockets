import SwiftUI

/// Options controlling what information ``FrameTimingView`` displays.
public struct FrameTimingDisplayOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Show the current FPS (e.g., "60 FPS").
    public static let fps = FrameTimingDisplayOptions(rawValue: 1 << 0)

    /// Show the frame time in milliseconds (e.g., "16.7 ms").
    public static let frameTime = FrameTimingDisplayOptions(rawValue: 1 << 1)

    /// Show the min/max frame time range (e.g., "8.3–33.2 ms").
    public static let range = FrameTimingDisplayOptions(rawValue: 1 << 2)

    /// Show the total frame count.
    public static let frameCount = FrameTimingDisplayOptions(rawValue: 1 << 3)

    /// The default display: FPS only.
    public static let `default`: FrameTimingDisplayOptions = [.fps]

    /// Show everything.
    public static let all: FrameTimingDisplayOptions = [.fps, .frameTime, .range, .frameCount]
}

/// A compact view that displays frame timing statistics.
///
/// Each enabled option is shown on its own line. Throttle updates at the source
/// using the `rate` parameter on ``SwiftUICore/View/onFrameTimingChange(rate:perform:)``.
///
/// ## Example
///
/// ```swift
/// @State var statistics: FrameTimingStatistics?
///
/// ZStack(alignment: .topTrailing) {
///     RenderView { context, size in
///         // ...
///     }
///     .onFrameTimingChange(rate: 4) { statistics = $0 }
///
///     if let statistics {
///         FrameTimingView(statistics: statistics, options: [.fps, .frameTime])
///             .padding()
///     }
/// }
/// ```
public struct FrameTimingView: View {
    var statistics: FrameTimingStatistics
    var options: FrameTimingDisplayOptions
    let minimumUpdateInterval: TimeInterval = 1.0 / 15.0

    @State
    var savedStatistics: FrameTimingStatistics?

    public init(statistics: FrameTimingStatistics, options: FrameTimingDisplayOptions = .default) {
        self.statistics = statistics
        self.options = options
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: minimumUpdateInterval)) { timeline in
            Group {
                Form {
                    if let statistics = savedStatistics {

                        if options.contains(.fps) {
                            LabeledContent {
                                Text("\(Int(statistics.currentFPS.rounded()))")
                                    .foregroundStyle(fpsColor(for: statistics.currentFPS))
                            } label: {
                                Text("FPS")
                            }
                        }
                        if options.contains(.frameTime) {
                            LabeledContent("Frame", value: formattedMilliseconds(statistics.deltaTime))
                        }
                        if options.contains(.range) {
                            let rangeText = formattedMilliseconds(statistics.minDeltaTime) + "–" + formattedMilliseconds(statistics.maxDeltaTime)
                            LabeledContent("1s Range", value: rangeText)
                        }
                        if options.contains(.frameCount) {
                            LabeledContent("Frame #", value: "\(statistics.frameCount)")
                        }
                    }
                }
                .foregroundStyle(.white)
                .monospacedDigit()
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
            }
            .onChange(of: timeline.date, initial: true) {
                savedStatistics = statistics
            }

        }

    }

    private static let millisecondFormat: Measurement<UnitDuration>.FormatStyle = .measurement(
        width: .abbreviated,
        usage: .asProvided,
        numberFormatStyle: .number.precision(.fractionLength(1))
    )

    private func formattedMilliseconds(_ seconds: TimeInterval) -> String {
        Measurement(value: seconds, unit: UnitDuration.seconds)
            .converted(to: .milliseconds)
            .formatted(Self.millisecondFormat)
    }

    private func fpsColor(for fps: Double) -> Color {
        if fps >= 55 {
            return .green
        } else if fps >= 30 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    FrameTimingView(statistics: FrameTimingStatistics(currentFPS: 60, deltaTime: 0.0167, averageDeltaTime: 0.0166, minDeltaTime: 0.0145, maxDeltaTime: 0.0201, frameCount: 4827), options: .all)
}
