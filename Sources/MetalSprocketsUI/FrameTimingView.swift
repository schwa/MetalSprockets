import SwiftUI

/// Options controlling what information ``FrameTimingView`` displays.
public struct FrameTimingDisplayOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Show the current FPS (e.g., "60 FPS").
    public static let fps = Self(rawValue: 1 << 0)

    /// Show the frame time in milliseconds (e.g., "16.7 ms").
    public static let frameTime = Self(rawValue: 1 << 1)

    /// Show the min/max frame time range (e.g., "8.3–33.2 ms").
    public static let range = Self(rawValue: 1 << 2)

    /// Show the total frame count.
    public static let frameCount = Self(rawValue: 1 << 3)

    /// Show GPU execution time in milliseconds (e.g., "GPU 2.1 ms").
    public static let gpuTime = Self(rawValue: 1 << 4)

    /// The default display: FPS only.
    public static let `default`: FrameTimingDisplayOptions = [.fps]

    /// Show everything.
    public static let all: FrameTimingDisplayOptions = [.fps, .frameTime, .range, .frameCount, .gpuTime]
}

/// A compact view that displays frame timing statistics.
///
/// Each enabled option is shown on its own line. Throttle updates at the source
/// using ``SwiftUICore/View/onFrameTimingChange(perform:)``.
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
    private var savedStatistics: FrameTimingStatistics?

    public init(statistics: FrameTimingStatistics, options: FrameTimingDisplayOptions = .default) {
        self.statistics = statistics
        self.options = options
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: minimumUpdateInterval)) { timeline in
            Group {
                #if os(macOS)
                Form {
                    formContent
                        .foregroundStyle(.white)
                }
                #else
                VStack(spacing: 4) {
                    formContent
                }
                .fixedSize()
                #endif
            }
            .monospacedDigit()
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .padding()
            .onChange(of: timeline.date, initial: true) {
                savedStatistics = statistics
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
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
            if options.contains(.gpuTime), let gpuTime = statistics.gpuTime {
                LabeledContent("GPU", value: formattedMilliseconds(gpuTime))
            }
            if options.contains(.frameCount) {
                LabeledContent("Frame #", value: "\(statistics.frameCount)")
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
        }
        if fps >= 30 {
            return .yellow
        }
        return .red
    }
}

#Preview {
    FrameTimingView(statistics: FrameTimingStatistics(currentFPS: 60, deltaTime: 0.0167, averageDeltaTime: 0.0166, minDeltaTime: 0.0145, maxDeltaTime: 0.0201, frameCount: 4_827, gpuTime: 0.0021), options: .all)
}


