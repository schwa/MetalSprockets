import Foundation

/// The environment variables MetalSprockets responds to, as a value that can be substituted in tests.
///
/// Reading `ProcessInfo.processInfo.environment` at each call site makes the env-gated branches unreachable from a
/// test without spawning a subprocess. Call sites read ``current`` instead, and tests bind a different environment
/// for the duration of a closure with `SystemEnvironment.$current.withValue(_:_:)`. See #326.
public struct SystemEnvironment: Sendable {
    /// The environment in effect. Defaults to the process environment.
    @TaskLocal
    public static var current = Self(variables: ProcessInfo.processInfo.environment)

    private let variables: [String: String]

    public init(variables: [String: String]) {
        self.variables = variables
    }

    /// An environment where only the named variables are set, each to a truthy value.
    public init(enabled: Set<String>) {
        self.variables = Dictionary(uniqueKeysWithValues: enabled.map { ($0, "1") })
    }

    public subscript(name: String) -> String? {
        variables[name]
    }

    private func isEnabled(_ names: String...) -> Bool {
        names.contains { variables[$0]?.isTruthy == true }
    }

    public var loggingEnabled: Bool {
        isEnabled("MS_LOGGING", "LOGGING")
    }

    public var verboseLoggingEnabled: Bool {
        isEnabled("MS_VERBOSE", "VERBOSE")
    }

    public var fatalErrorOnThrow: Bool {
        isEnabled("MS_FATALERROR_ON_THROW")
    }

    public var metalLoggingEnabled: Bool {
        isEnabled("MS_METAL_LOGGING")
    }

    public var dumpSnapshotsEnabled: Bool {
        isEnabled("MS_DUMP_SNAPSHOTS")
    }

    public var renderViewLogFrameEnabled: Bool {
        isEnabled("MS_RENDERVIEW_LOG_FRAME")
    }
}

internal extension String {
    var isTruthy: Bool {
        ["yes", "true", "y", "1", "on"].contains(self.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}
