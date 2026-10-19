import MetalSprockets
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

    /// Show each `gpuTimed` interval from the last completed frame, by label, in milliseconds.
    public static let gpuTimings = Self(rawValue: 1 << 5)

    /// Show the previous frame's CPU time per phase (content, update, setup, workload) and in total.
    public static let cpuPhases = Self(rawValue: 1 << 6)

    /// The default display: FPS only.
    public static let `default`: FrameTimingDisplayOptions = [.fps]

    /// Show everything.
    public static let all: FrameTimingDisplayOptions = [.fps, .frameTime, .range, .frameCount, .cpuPhases, .gpuTime, .gpuTimings]
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

    /// - Parameters:
    ///   - statistics: The frame timing statistics to show.
    ///   - options: Which readouts to show.
    ///   - targetFramesPerSecond: The frame rate the FPS readout is colour-coded against. Defaults to the
    ///     display's maximum refresh rate, so that a 120 Hz display does not show green at 60 FPS.
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

    /// The group a row belongs to. Groups are separated by a divider.
    internal enum Section: Equatable {
        case fps
        case frame
        case cpu
        case gpu
    }

    /// One labelled line of the readout.
    internal struct Row: Identifiable, Equatable {
        var label: String
        var value: String
        var valueColor: Color?
        // Set when the label is not unique, such as a user-chosen gpuTimed label.
        var key: String?
        var section: Section = .frame
        // Sub-rows (CPU phases, GPU passes) are indented under their section's total.
        var isIndented = false

        var id: String {
            key ?? label
        }
    }

    /// The rows the given statistics and options produce, in display order.
    internal static func rows(for statistics: FrameTimingStatistics, options: FrameTimingDisplayOptions, targetFramesPerSecond: Double) -> [Row] {
        var rows: [Row] = []
        if options.contains(.fps) {
            let color = fpsColor(for: statistics.currentFPS, targetFramesPerSecond: targetFramesPerSecond)
            rows.append(Row(label: "FPS", value: "\(Int(statistics.currentFPS.rounded()))", valueColor: color, section: .fps))
        }
        if options.contains(.frameTime) {
            rows.append(Row(label: "Frame", value: formattedMilliseconds(statistics.deltaTime)))
        }
        if options.contains(.range) {
            let range = formattedMillisecondRange(statistics.minDeltaTime, statistics.maxDeltaTime)
            rows.append(Row(label: "Range", value: range, isIndented: options.contains(.frameTime)))
        }
        if options.contains(.frameCount) {
            rows.append(Row(label: "Frame #", value: "\(statistics.frameCount)", isIndented: options.contains(.frameTime)))
        }
        if options.contains(.cpuPhases), let phases = statistics.cpuPhaseTimings {
            rows.append(Row(label: "CPU", value: formattedMilliseconds(phases.total), section: .cpu))
            if let content = phases.content {
                rows.append(Row(label: "Content", value: formattedMilliseconds(content), section: .cpu, isIndented: true))
            }
            rows.append(Row(label: "Update", value: formattedMilliseconds(phases.update), section: .cpu, isIndented: true))
            rows.append(Row(label: "Setup", value: formattedMilliseconds(phases.setup), section: .cpu, isIndented: true))
            rows.append(Row(label: "Workload", value: formattedMilliseconds(phases.workload), section: .cpu, isIndented: true))
        }
        let showsGPUTotal = options.contains(.gpuTime) && statistics.gpuTime != nil
        if showsGPUTotal, let gpuTime = statistics.gpuTime {
            rows.append(Row(label: "GPU", value: formattedMilliseconds(gpuTime), section: .gpu))
        }
        if options.contains(.gpuTimings) {
            for (index, timing) in statistics.gpuTimings.enumerated() {
                rows.append(Row(label: timing.label, value: formattedMilliseconds(timing.duration), key: "gpuTiming.\(index)", section: .gpu, isIndented: showsGPUTotal))
            }
        }
        return rows
    }

    /// "14.5–20.1 ms": one unit for both ends keeps the row narrow.
    internal static func formattedMillisecondRange(_ minimum: TimeInterval, _ maximum: TimeInterval) -> String {
        (minimum * 1_000).formatted(.number.precision(.fractionLength(1))) + "–" + formattedMilliseconds(maximum)
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
    ///
    /// Each threshold allows a small tolerance. Half the refresh rate (60 FPS on a 120 Hz display) is a common steady
    /// state, and its measured value jitters around the exact boundary, which made the colour flash. (#397)
    internal static func fpsColor(for fps: Double, targetFramesPerSecond: Double) -> Color {
        let target = targetFramesPerSecond > 0 ? targetFramesPerSecond : fallbackFramesPerSecond
        let tolerance = 0.97
        if fps >= target * 0.9 * tolerance {
            return .green
        }
        if fps >= target * 0.5 * tolerance {
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
        // No SwiftUI equivalent: refresh-rate capability is not surfaced through the environment. UIScreen.main is
        // deprecated, so read the screen of a connected window scene, preferring the foreground-active one.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let screen = scene?.screen, screen.maximumFramesPerSecond > 0 else {
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
        let fpsRow = rows.first { $0.section == .fps }
        let gridRows = rows.filter { $0.section != .fps }
        VStack(alignment: .leading, spacing: 4) {
            if let fpsRow {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(fpsRow.value)
                        .font(.title.bold())
                        .foregroundStyle(fpsRow.valueColor ?? .primary)
                    Text(fpsRow.label)
                        .foregroundStyle(.secondary)
                }
            }
            if !gridRows.isEmpty {
                Grid(alignment: .leading, verticalSpacing: 2) {
                    ForEach(Array(gridRows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 && gridRows[index - 1].section != row.section || index == 0 && fpsRow != nil {
                            Divider()
                        }
                        GridRow {
                            Text(row.label)
                                .foregroundStyle(row.isIndented ? .secondary : .primary)
                                .padding(.leading, row.isIndented ? 10 : 0)
                            Text(row.value)
                                .foregroundStyle(row.valueColor ?? (row.isIndented ? .secondary : .primary))
                                .gridColumnAlignment(.trailing)
                        }
                    }
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
        let gpuTimings = [
            GPUTiming(label: "Shadows", startTimestamp: 0, endTimestamp: 0, duration: deltaTime * 0.03),
            GPUTiming(label: "Main", startTimestamp: 0, endTimestamp: 0, duration: deltaTime * 0.09)
        ]
        let cpuPhaseTimings = CPUPhaseTimings(content: deltaTime * 0.02, update: deltaTime * 0.05, setup: deltaTime * 0.01, workload: deltaTime * 0.04)
        return Self(
            currentFPS: currentFPS,
            deltaTime: deltaTime,
            averageDeltaTime: deltaTime,
            minDeltaTime: deltaTime * 0.9,
            maxDeltaTime: deltaTime * 1.2,
            frameCount: 4_827,
            gpuTime: deltaTime * 0.125,
            gpuTimings: gpuTimings,
            cpuPhaseTimings: cpuPhaseTimings
        )
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
