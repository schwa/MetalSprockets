import Foundation
import Metal
import MetalSprocketsSupport
import os

/// Where messages from shader `os_log` calls go.
///
/// Shader logging is set per root (``Runner``, ``OffscreenRenderer``, `RenderView`), because on Metal 4 a log state
/// covers a whole command buffer. Shaders must be compiled with logging enabled (`MTLCompileOptions.enableLogging`).
/// Logging disables GPU capture for the whole process.
public struct ShaderLogging: Sendable {
    internal let configuration: Configuration?

    /// No shader logging.
    public static let disabled = Self(configuration: nil)

    /// Sends shader messages to the MetalSprockets logger.
    public static let logger = Self(configuration: Configuration { message in logShaderMessage(message) })

    /// Sends shader messages to `handler`, which runs on a Metal-owned thread.
    public static func handler(bufferSize: Int = 32 * 1_024 * 1_024, _ handler: @escaping @Sendable (String) -> Void) -> Self {
        Self(configuration: Configuration(bufferSize: bufferSize, handler: handler))
    }

    /// ``logger`` when the process sets `MS_METAL_LOGGING=1`, otherwise ``disabled``. The default for every root.
    public static var processDefault: Self {
        SystemEnvironment.current.metalLoggingEnabled ? .logger : .disabled
    }
}

// Outside ShaderLogging, where `logger` would mean its static member rather than the module logger.
private func logShaderMessage(_ message: String) {
    logger?.log("\(message)")
}

extension ShaderLogging {
    internal struct Configuration: Sendable {
        var bufferSize = 32 * 1_024 * 1_024
        var handler: @Sendable (String) -> Void

        static var systemDefault: Self? {
            ShaderLogging.processDefault.configuration
        }
    }
}

/// Ends a capture this element started once the submission it covers is finished or discarded.
///
/// Metal 4 encodes during traversal but commits after it. If the capture stops at `workloadExit` (as the legacy
/// modifier does), it stops before the work gets to the queue. The recording owns the session. Its terminal handler
/// keeps the session alive until completion. If the recording is discarded, the session goes too. Thus a workload
/// that throws still ends the capture.
internal final class CaptureSession: Sendable {
    private let isFinished = OSAllocatedUnfairLock(initialState: false)
    private let onFinish: @Sendable () -> Void

    init(onFinish: @escaping @Sendable () -> Void = { stopCapture() }) {
        self.onFinish = onFinish
    }

    /// Stops the capture while the resources of the submission are still alive. The capture layer serializes their state.
    func finish() {
        guard !isFinished.withLock({ finished in defer { finished = true }; return finished }) else {
            return
        }
        onFinish()
    }

    static func stopCapture() {
        let manager = MTLCaptureManager.shared()
        if manager.isCapturing {
            manager.stopCapture()
            logger?.info("capture: capture stopped.")
        }
    }

    // Fallback for a discarded recording, which never delivers a terminal result.
    deinit {
        finish()
    }
}

/// One capture that spans several consecutive submissions.
///
/// The first submission starts the capture. Every counted submission ends with a terminal result (or a discard), and
/// the capture stops once the last of them has ended. Later submissions are not captured. Make a new sequence to
/// capture again.
package final class CaptureSequence: Sendable {
    private enum Phase {
        case idle
        case capturing(started: Int, ended: Int)
        case done
    }

    package let frameCount: Int
    private let phase = OSAllocatedUnfairLock(initialState: Phase.idle)

    package init(frameCount: Int) {
        precondition(frameCount > 0, "A capture sequence needs at least one frame.")
        self.frameCount = frameCount
    }

    package var isDone: Bool {
        phase.withLock { if case .done = $0 { true } else { false } }
    }

    enum Admission {
        case start
        case join
        case skip
    }

    /// Counts a new submission into the sequence.
    func admit() -> Admission {
        phase.withLock { phase in
            switch phase {
            case .idle:
                phase = .capturing(started: 1, ended: 0)
                return .start
            case let .capturing(started, ended) where started < frameCount:
                phase = .capturing(started: started + 1, ended: ended)
                return .join
            case .capturing, .done:
                return .skip
            }
        }
    }

    /// Undoes `admit()` for a submission whose capture could not start.
    func cancelStart() {
        phase.withLock { $0 = .done }
    }

    /// Records that an admitted submission has ended. Stops the capture after the last one.
    func submissionEnded() {
        let shouldStop = phase.withLock { phase in
            guard case let .capturing(started, previouslyEnded) = phase else {
                return false
            }
            if previouslyEnded + 1 >= frameCount {
                phase = .done
                return true
            }
            phase = .capturing(started: started, ended: previouslyEnded + 1)
            return false
        }
        if shouldStop {
            CaptureSession.stopCapture()
            logger?.info("capture: \(self.frameCount)-frame capture finished.")
        }
    }

    // The app can drop the sequence mid-capture (configuration change, view gone). Stop so the trace is written.
    deinit {
        if case .capturing = phase.withLock({ $0 }) {
            CaptureSession.stopCapture()
        }
    }
}

internal struct CaptureModifier<Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var enabled: Bool
    var target: CaptureTarget
    var destination: MTLCaptureDestination
    var outputURL: URL?
    var sequence: CaptureSequence?

    func workloadEnter(_ node: Node) throws {
        guard enabled else {
            return
        }
        if let sequence {
            try enterSequence(sequence, node: node)
            return
        }
        guard try startCapture(node: node) else {
            return
        }
        let recording = try node.environmentValues.recordingScope.orThrow(.missingEnvironment("recordingScope"))
        let session = CaptureSession()
        try recording.retain(session)
        try recording.onTerminated { _ in session.finish() }
    }

    private func enterSequence(_ sequence: CaptureSequence, node: Node) throws {
        let recording = try node.environmentValues.recordingScope.orThrow(.missingEnvironment("recordingScope"))
        switch sequence.admit() {
        case .skip:
            return
        case .start:
            do {
                guard try startCapture(node: node) else {
                    sequence.cancelStart()
                    return
                }
            } catch {
                sequence.cancelStart()
                throw error
            }
        case .join:
            break
        }
        // The session holds the sequence, so a capture outlives the view model until its last frame ends.
        let session = CaptureSession { sequence.submissionEnded() }
        try recording.retain(session)
        try recording.onTerminated { _ in session.finish() }
    }

    /// Returns `false` when the capture is skipped (unsupported destination or a capture already running).
    private func startCapture(node: Node) throws -> Bool {
        let context = try node.environmentValues.metalContext.orThrow(.missingEnvironment("metalContext"))
        // Starting a capture while an encoder is open, then drawing, crashes capture serialization at stop (observed
        // on the Xcode 27 RC, #432). The legacy modifier allowed this placement; on Metal 4 it must wrap whole passes.
        guard node.environmentValues.renderPassEncoder == nil, node.environmentValues.computePassEncoder == nil else {
            throw MetalSprocketsError.configurationError("`.capture()` must wrap whole render or compute passes on Metal 4, not sit inside one.")
        }
        let manager = MTLCaptureManager.shared()
        guard manager.supportsDestination(destination) else {
            logger?.warning("capture: MTLCaptureManager does not support destination \(String(describing: destination)). Set MTL_CAPTURE_ENABLED=1 to enable .developerTools captures.")
            return false
        }
        // A capture owned by someone else (or an outer scope) is left alone.
        guard !manager.isCapturing else {
            logger?.warning("capture: MTLCaptureManager is already capturing; skipping nested scope.")
            return false
        }
        let descriptor = MTLCaptureDescriptor()
        descriptor.destination = destination
        if destination == .gpuTraceDocument {
            descriptor.outputURL = try outputURL.orThrow(.configurationError("`.capture(destination: .gpuTraceDocument)` requires an `outputURL` to write the .gputrace file to."))
        }
        switch target {
        case .device:
            descriptor.captureObject = context.device
        case .commandQueue:
            // The MTL4CommandQueue itself; a scope from makeCaptureScope(commandQueue:) as capture object crashed
            // GPUTools on the Xcode 27 RC (unrecognized selector traceStream).
            descriptor.captureObject = context.commandQueue
        }
        try manager.startCapture(with: descriptor)
        logger?.info("capture: capture started successfully.")
        return true
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

/// Pushes a debug group on the open encoder, or on the command buffer when it wraps whole passes.
internal struct DebugGroupModifier<Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var label: String
    var content: Content

    func workloadEnter(_ node: Node) throws {
        let environment = node.environmentValues
        if let pass = environment.renderPassEncoder {
            try pass.pushDebugGroup(label)
        } else if let pass = environment.computePassEncoder {
            try pass.pushDebugGroup(label)
        } else {
            try environment.recordingScope.orThrow(.missingEnvironment("recordingScope")).withCommandBuffer { $0.pushDebugGroup(label) }
        }
    }

    // Runs during unwinding too, so groups stay balanced when a child throws.
    func workloadExit(_ node: Node) throws {
        let environment = node.environmentValues
        if let pass = environment.renderPassEncoder {
            try pass.popDebugGroup()
        } else if let pass = environment.computePassEncoder {
            try pass.popDebugGroup()
        } else {
            try environment.recordingScope.orThrow(.missingEnvironment("recordingScope")).withCommandBuffer { $0.popDebugGroup() }
        }
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}
