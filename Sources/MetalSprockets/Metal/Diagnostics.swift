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
/// Metal 4 encodes during traversal but commits afterwards, so stopping at `workloadExit` (as the legacy modifier does)
/// would stop before the work reaches the queue. The session is owned by the recording: its terminal handler keeps it
/// alive through completion, and discarding the recording drops it, so a thrown workload still ends the capture.
internal final class CaptureSession: Sendable {
    private let isFinished = OSAllocatedUnfairLock(initialState: false)

    /// Stops the capture while the submission's resources are still alive; the capture layer serializes their state.
    func finish() {
        guard !isFinished.withLock({ finished in defer { finished = true }; return finished }) else {
            return
        }
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

internal struct CaptureModifier<Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var enabled: Bool
    var target: CaptureTarget
    var destination: MTLCaptureDestination
    var outputURL: URL?

    func workloadEnter(_ node: Node) throws {
        guard enabled else {
            return
        }
        let context = try node.environmentValues.metalContext.orThrow(.missingEnvironment("metalContext"))
        let recording = try node.environmentValues.recordingScope.orThrow(.missingEnvironment("recordingScope"))
        // Starting a capture while an encoder is open, then drawing, crashes capture serialization at stop (observed
        // on the Xcode 27 RC, #432). The legacy modifier allowed this placement; on Metal 4 it must wrap whole passes.
        guard node.environmentValues.renderPassEncoder == nil, node.environmentValues.computePassEncoder == nil else {
            throw MetalSprocketsError.configurationError("`.capture()` must wrap whole render or compute passes on Metal 4, not sit inside one.")
        }
        let manager = MTLCaptureManager.shared()
        guard manager.supportsDestination(destination) else {
            logger?.warning("capture: MTLCaptureManager does not support destination \(String(describing: destination)). Set MTL_CAPTURE_ENABLED=1 to enable .developerTools captures.")
            return
        }
        // A capture owned by someone else (or an outer scope) is left alone.
        guard !manager.isCapturing else {
            logger?.warning("capture: MTLCaptureManager is already capturing; skipping nested scope.")
            return
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
        let session = CaptureSession()
        try recording.retain(session)
        try recording.onTerminated { _ in session.finish() }
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

/// Pushes a debug group on the open encoder, or on the command buffer when it wraps whole passes.
internal struct DebugGroupModifier<Content>: Element, WorkloadElement, BodylessContentElement, Equatable where Content: Element {
    var label: String
    var content: Content

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.label == rhs.label
    }

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
