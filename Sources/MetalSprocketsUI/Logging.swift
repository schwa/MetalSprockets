import Foundation
internal import os.log
import MetalSprocketsSupport

internal let logger: Logger? = {
    guard ProcessInfo.processInfo.loggingEnabled else {
        return nil
    }
    return .init(subsystem: "io.schwa.metal-sprockets-ui", category: "default")
}()

internal let signposter: OSSignposter? = {
    guard ProcessInfo.processInfo.loggingEnabled else {
        return nil
    }
    return .init(subsystem: "io.schwa.metal-sprockets-ui", category: OSLog.Category.pointsOfInterest)
}()
