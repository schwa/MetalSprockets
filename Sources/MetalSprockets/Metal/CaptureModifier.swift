import Foundation
import Metal
import MetalSprocketsSupport

// MARK: - CaptureTarget

/// The Metal object to attach a GPU frame capture to.
///
/// See ``Element/capture(_:target:destination:)``.
public enum CaptureTarget: Sendable {
    /// Capture all GPU work submitted on the device during the scope.
    case device
    /// Capture only the GPU work submitted on the command queue during the scope.
    case commandQueue
}

// MARK: - CaptureModifier

internal struct CaptureModifier <Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var enabled: Bool
    var target: CaptureTarget
    var destination: MTLCaptureDestination
    var outputURL: URL?

    /// Only the scope that started the capture may stop it, so a nested scope leaves the outer
    /// capture running.
    @MSState
    private var didStartCapture = false

    func workloadEnter(_ node: Node) throws {
        guard enabled else {
            logger?.verbose?.info("capture: disabled, skipping.")
            return
        }

        logger?.info("capture: starting capture (target=\(String(describing: target)), destination=\(String(describing: destination)))")

        let manager = MTLCaptureManager.shared()

        guard manager.supportsDestination(destination) else {
            logger?.warning("capture: MTLCaptureManager does not support destination \(String(describing: destination)). Set MTL_CAPTURE_ENABLED=1 to enable .developerTools captures.")
            return
        }

        guard !manager.isCapturing else {
            logger?.warning("capture: MTLCaptureManager is already capturing; skipping nested scope.")
            return
        }

        let descriptor = MTLCaptureDescriptor()
        descriptor.destination = destination

        // Metal requires an output URL for .gpuTraceDocument; without one startCapture always
        // fails (see #356).
        if destination == .gpuTraceDocument {
            guard let outputURL else {
                throw MetalSprocketsError.configurationError("`.capture(destination: .gpuTraceDocument)` requires an `outputURL` to write the .gputrace file to.")
            }
            descriptor.outputURL = outputURL
        }

        switch target {
        case .device:
            let device = try node.environmentValues.device.orThrow(.missingEnvironment(\.device))
            descriptor.captureObject = device
            logger?.verbose?.info("capture: target is device.")

        case .commandQueue:
            let commandQueue = try node.environmentValues.commandQueue.orThrow(.missingEnvironment(\.commandQueue))
            descriptor.captureObject = commandQueue
            logger?.verbose?.info("capture: target is commandQueue.")
        }

        try manager.startCapture(with: descriptor)
        didStartCapture = true
        logger?.info("capture: capture started successfully.")
    }

    func workloadExit(_ node: Node) throws {
        guard enabled else {
            return
        }
        guard didStartCapture else {
            logger?.verbose?.info("capture: workloadExit called but this scope did not start the capture.")
            return
        }
        didStartCapture = false
        let manager = MTLCaptureManager.shared()
        if manager.isCapturing {
            manager.stopCapture()
            logger?.info("capture: capture stopped.")
        } else {
            logger?.verbose?.info("capture: workloadExit called but manager was not capturing.")
        }
    }

    nonisolated func requiresSetup(comparedTo old: CaptureModifier<Content>) -> Bool {
        // Capture only affects the workload phase, never requires setup.
        false
    }
}

// MARK: -

public extension Element {
    /// Wraps the element in an `MTLCaptureManager` GPU frame capture scope.
    ///
    /// Use this to programmatically capture GPU work for inspection in Xcode's
    /// frame debugger or to a `.gputrace` file. The capture starts when the
    /// element enters its workload phase and stops when it exits.
    ///
    /// ```swift
    /// RenderPass {
    ///     // render content
    /// }
    /// .capture()
    /// ```
    ///
    /// Toggle conditionally without restructuring:
    ///
    /// ```swift
    /// .capture(shouldCaptureThisFrame)
    /// ```
    ///
    /// > Important: For `.developerTools` captures, the host process must have
    /// > the `MTL_CAPTURE_ENABLED` environment variable set to `1` (Xcode does
    /// > this automatically when launching with GPU frame capture enabled).
    ///
    /// - Parameters:
    ///   - enabled: When `false`, the modifier is a no-op. Defaults to `true`.
    ///   - target: Whether to capture all work on the device or only on the
    ///     current command queue. Defaults to ``CaptureTarget/device``.
    ///   - destination: The capture destination. Defaults to `.developerTools`.
    ///   - outputURL: Where to write the `.gputrace` file. Required for
    ///     `.gpuTraceDocument`, ignored otherwise.
    /// - Returns: An element that performs a GPU frame capture around its content.
    func capture(
        _ enabled: Bool = true,
        target: CaptureTarget = .device,
        destination: MTLCaptureDestination = .developerTools,
        outputURL: URL? = nil
    ) -> some Element {
        CaptureModifier(content: self, enabled: enabled, target: target, destination: destination, outputURL: outputURL)
    }
}
