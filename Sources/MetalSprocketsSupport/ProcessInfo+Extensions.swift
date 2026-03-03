import Foundation

public extension ProcessInfo {
    var loggingEnabled: Bool {
        environment["MS_LOGGING"]?.isTruthy ?? false || environment["LOGGING"]?.isTruthy ?? false
    }

    var verboseLoggingEnabled: Bool {
        environment["MS_VERBOSE"]?.isTruthy ?? false || environment["VERBOSE"]?.isTruthy ?? false
    }

    var fatalErrorOnThrow: Bool {
        environment["MS_FATALERROR_ON_THROW"]?.isTruthy ?? false
    }

    var metalLoggingEnabled: Bool {
        environment["MS_METAL_LOGGING"]?.isTruthy ?? false
    }

    var dumpSnapshotsEnabled: Bool {
        environment["MS_DUMP_SNAPSHOTS"]?.isTruthy ?? false
    }

    var renderViewLogFrameEnabled: Bool {
        environment["MS_RENDERVIEW_LOG_FRAME"]?.isTruthy ?? false
    }
}

private extension String {
    var isTruthy: Bool {
        ["yes", "true", "y", "1", "on"].contains(self.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}
