import os

/// An element that logs messages at various stages during the MetalSprockets lifecycle.
public struct LoggingElement: Element, BodylessElement {
    /// Options describing which lifecycle phases to log.
    public struct Phases: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let setupEnter = Phases(rawValue: 1 << 0)
        public static let setupExit = Phases(rawValue: 1 << 1)
        public static let workloadEnter = Phases(rawValue: 1 << 2)
        public static let workloadExit = Phases(rawValue: 1 << 3)

        public static let setup: Phases = [.setupEnter, .setupExit]
        public static let workload: Phases = [.workloadEnter, .workloadExit]
        public static let enter: Phases = [.setupEnter, .workloadEnter]
        public static let exit: Phases = [.setupExit, .workloadExit]
        public static let all: Phases = [.setup, .workload]
    }

    public let message: String
    public let phases: Phases
    private let customLogger: (@Sendable (String) -> Void)?

    /// Creates a logging element.
    /// - Parameters:
    ///   - message: The message to log.
    ///   - phases: Which lifecycle phases to log. Defaults to `.all`.
    ///   - logger: An optional custom logger. If `nil`, uses the internal MetalSprockets logger.
    public init(_ message: String = "", phases: Phases = .all, logger: Logger? = nil) {
        self.message = message
        self.phases = phases
        if let logger {
            self.customLogger = { message in
                logger.log("\(message)")
            }
        } else {
            self.customLogger = nil
        }
    }

    private func log(_ phase: String) {
        let fullMessage = message.isEmpty ? phase : "\(phase): \(message)"
        if let customLogger {
            customLogger(fullMessage)
        } else {
            MetalSprockets.logger?.log("\(fullMessage)")
        }
    }

    func setupEnter(_ node: Node) throws {
        if phases.contains(.setupEnter) {
            log("setupEnter")
        }
    }

    func setupExit(_ node: Node) throws {
        if phases.contains(.setupExit) {
            log("setupExit")
        }
    }

    func workloadEnter(_ node: Node) throws {
        if phases.contains(.workloadEnter) {
            log("workloadEnter")
        }
    }

    func workloadExit(_ node: Node) throws {
        if phases.contains(.workloadExit) {
            log("workloadExit")
        }
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        // LoggingElement only logs, never needs setup
        false
    }
}
