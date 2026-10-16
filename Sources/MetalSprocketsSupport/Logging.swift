import Foundation
import os

internal let logger: Logger? = {
    guard ProcessInfo.processInfo.loggingEnabled else {
        return nil
    }
    return .init(subsystem: "io.schwa.metal-sprockets-support", category: "default")
}()

/// Frame intervals and events for Instruments (Update, Setup, Workload, Frame, Content, Commit, passes, skipped frames).
///
/// Always on: signposts cost almost nothing when no trace is recording. Points of Interest, so they appear in the Time
/// Profiler and other templates without adding an instrument.
package let frameSignposter = OSSignposter(subsystem: "io.schwa.metal-sprockets", category: OSLog.Category.pointsOfInterest)

public func withIntervalSignpost<T>(_ signposter: OSSignposter?, name: StaticString, id: OSSignpostID? = nil, around task: () throws -> T) rethrows -> T {
    guard let signposter else {
        return try task()
    }
    return try signposter.withIntervalSignpost(name, id: id ?? .exclusive, around: task)
}

public extension Logger {
    var verbose: Logger? {
        SystemEnvironment.current.verboseLoggingEnabled ? self : nil
    }
}
