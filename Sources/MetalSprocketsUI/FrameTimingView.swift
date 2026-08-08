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
    var targetFramesPerSecond: Double
    let minimumUpdateInterval: TimeInterval = 1.0 / 15.0

    @State
    private var savedStatistics: FrameTimingStatistics?

    /// - Parameter targetFramesPerSecond: The frame rate the FPS readout is colour-coded against. Defaults to the
    ///   display's maximum refresh rate, so a 120 Hz display isn't marked green at 60 FPS.
    public init(statistics: FrameTimingStatistics, options: FrameTimingDisplayOptions = .default, targetFramesPerSecond: Double? = nil) {
        self.statistics = statistics
        self.options = options
        self.targetFramesPerSecond = targetFramesPerSecond ?? Self.displayMaximumFramesPerSecond
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: minimumUpdateInterval)) { timeline in
            FrameTimingRowsView(rows: savedStatistics.map { statistics in
                Self.rows(for: statistics, options: options, targetFramesPerSecond: targetFramesPerSecond)
            } ?? [])
            .modifier(OverlayBadgeModifier())
            .onChange(of: timeline.date, initial: true) {
                savedStatistics = statistics
            }
        }
    }

    /// One labelled line of the readout.
    internal struct Row: Identifiable, Equatable {
        var label: String
        var value: String
        var valueColor: Color?

        var id: String {
            label
        }
    }

    /// The rows the given statistics and options produce, in display order.
    internal static func rows(for statistics: FrameTimingStatistics, options: FrameTimingDisplayOptions, targetFramesPerSecond: Double) -> [Row] {
        var rows: [Row] = []
        if options.contains(.fps) {
            let color = fpsColor(for: statistics.currentFPS, targetFramesPerSecond: targetFramesPerSecond)
            rows.append(Row(label: "FPS", value: "\(Int(statistics.currentFPS.rounded()))", valueColor: color))
        }
        if options.contains(.frameTime) {
            rows.append(Row(label: "Frame", value: formattedMilliseconds(statistics.deltaTime)))
        }
        if options.contains(.range) {
            let range = formattedMilliseconds(statistics.minDeltaTime) + "–" + formattedMilliseconds(statistics.maxDeltaTime)
            rows.append(Row(label: "1s Range", value: range))
        }
        if options.contains(.gpuTime), let gpuTime = statistics.gpuTime {
            rows.append(Row(label: "GPU", value: formattedMilliseconds(gpuTime)))
        }
        if options.contains(.frameCount) {
            rows.append(Row(label: "Frame #", value: "\(statistics.frameCount)"))
        }
        return rows
    }

    private static let millisecondFormat: Measurement<UnitDuration>.FormatStyle = .measurement(
        width: .abbreviated,
        usage: .asProvided,
        numberFormatStyle: .number.precision(.fractionLength(1))
    )

    internal static func formattedMilliseconds(_ seconds: TimeInterval) -> String {
        Measurement(value: seconds, unit: UnitDuration.seconds)
            .converted(to: .milliseconds)
            .formatted(millisecondFormat)
    }

    /// Green from 90% of the target frame rate, yellow from 50%, red below that.
    internal static func fpsColor(for fps: Double, targetFramesPerSecond: Double) -> Color {
        let target = targetFramesPerSecond > 0 ? targetFramesPerSecond : fallbackFramesPerSecond
        if fps >= target * 0.9 {
            return .green
        }
        if fps >= target * 0.5 {
            return .yellow
        }
        return .red
    }

    private static let fallbackFramesPerSecond: Double = 60

    internal static var displayMaximumFramesPerSecond: Double {
        #if os(macOS)
        guard let screen = NSScreen.main, screen.maximumFramesPerSecond > 0 else {
            return fallbackFramesPerSecond
        }
        return Double(screen.maximumFramesPerSecond)
        #elseif os(iOS) || os(tvOS)
        // No SwiftUI equivalent: refresh-rate capability is not surfaced through the environment.
        let screen = UIScreen.main
        guard screen.maximumFramesPerSecond > 0 else {
            return fallbackFramesPerSecond
        }
        return Double(screen.maximumFramesPerSecond)
        #else
        // visionOS and friends have no single screen to query.
        return fallbackFramesPerSecond
        #endif
    }
}

// MARK: - FrameTimingRowsView

/// The label/value grid inside a ``FrameTimingView``.
///
/// A `Grid` rather than a `Form`: it keeps the two columns aligned identically on every platform, where `Form` is a
/// page-level container that only aligns `LabeledContent` on macOS.
internal struct FrameTimingRowsView: View {
    var rows: [FrameTimingView.Row]

    var body: some View {
        Grid(alignment: .leading) {
            ForEach(rows) { row in
                GridRow {
                    Text(row.label)
                    Text(row.value)
                        .foregroundStyle(row.valueColor ?? .primary)
                        .gridColumnAlignment(.trailing)
                }
            }
        }
        .monospacedDigit()
        .fixedSize()
    }
}

// MARK: - Previews

private extension FrameTimingStatistics {
    static func preview(currentFPS: Double) -> Self {
        let deltaTime = 1 / currentFPS
        return Self(currentFPS: currentFPS, deltaTime: deltaTime, averageDeltaTime: deltaTime, minDeltaTime: deltaTime * 0.9, maxDeltaTime: deltaTime * 1.2, frameCount: 4_827, gpuTime: deltaTime * 0.125)
    }
}

#Preview("All options") {
    FrameTimingView(statistics: .preview(currentFPS: 60), options: .all, targetFramesPerSecond: 60)
}

#Preview("Default options") {
    FrameTimingView(statistics: .preview(currentFPS: 60), options: .default, targetFramesPerSecond: 60)
}

#Preview("Degraded") {
    VStack {
        FrameTimingView(statistics: .preview(currentFPS: 45), options: .all, targetFramesPerSecond: 60)
        FrameTimingView(statistics: .preview(currentFPS: 20), options: .all, targetFramesPerSecond: 60)
    }
}
