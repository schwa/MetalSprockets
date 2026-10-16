import Foundation
import MetalSprocketsSupport
import os

internal let logger: Logger? = {
    guard ProcessInfo.processInfo.loggingEnabled else {
        return nil
    }
    return .init(subsystem: "io.schwa.metal-sprockets", category: "default")
}()

/// Frame phase intervals for Instruments. Not gated on logging: signposts cost almost nothing when no trace is running.
internal let phaseSignposter = OSSignposter(subsystem: "io.schwa.metal-sprockets", category: OSLog.Category.pointsOfInterest)

internal let signposter: OSSignposter? = {
    guard ProcessInfo.processInfo.loggingEnabled else {
        return nil
    }
    return .init(subsystem: "io.schwa.metal-sprockets", category: OSLog.Category.pointsOfInterest)
}()
