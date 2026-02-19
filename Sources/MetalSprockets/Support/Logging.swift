import Foundation
import MetalSprocketsSupport
import os

internal let logger: Logger? = {
    guard ProcessInfo.processInfo.loggingEnabled else {
        return nil
    }
    return .init(subsystem: "io.schwa.metal-sprockets", category: "default")
}()

internal let signposter: OSSignposter? = {
    guard ProcessInfo.processInfo.loggingEnabled else {
        return nil
    }
    return .init(subsystem: "io.schwa.metal-sprockets", category: OSLog.Category.pointsOfInterest)
}()
