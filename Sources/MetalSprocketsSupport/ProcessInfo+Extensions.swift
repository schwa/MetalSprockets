import Foundation

public extension ProcessInfo {
    var systemEnvironment: SystemEnvironment {
        SystemEnvironment(variables: environment)
    }

    var loggingEnabled: Bool {
        systemEnvironment.loggingEnabled
    }

    var verboseLoggingEnabled: Bool {
        systemEnvironment.verboseLoggingEnabled
    }

    var fatalErrorOnThrow: Bool {
        systemEnvironment.fatalErrorOnThrow
    }

    var metalLoggingEnabled: Bool {
        systemEnvironment.metalLoggingEnabled
    }

    var dumpSnapshotsEnabled: Bool {
        systemEnvironment.dumpSnapshotsEnabled
    }

    var renderViewLogFrameEnabled: Bool {
        systemEnvironment.renderViewLogFrameEnabled
    }
}
