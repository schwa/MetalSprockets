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

internal struct CaptureModifier <Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var enabled: Bool
    var target: CaptureTarget
    var destination: MTLCaptureDestination

    func workloadEnter(_ node: Node) throws {
        guard enabled else {
            return
        }

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

        switch target {
        case .device:
            let device = try node.environmentValues.device.orThrow(.missingEnvironment(\.device))
            descriptor.captureObject = device

        case .commandQueue:
            let commandQueue = try node.environmentValues.commandQueue.orThrow(.missingEnvironment(\.commandQueue))
            descriptor.captureObject = commandQueue
        }

        do {
            try manager.startCapture(with: descriptor)
        } catch {
            logger?.warning("capture: Failed to start capture: \(error)")
        }
    }

    func workloadExit(_ node: Node) throws {
        guard enabled else {
            return
        }
        let manager = MTLCaptureManager.shared()
        if manager.isCapturing {
            manager.stopCapture()
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
    /// - Returns: An element that performs a GPU frame capture around its content.
    func capture(
        _ enabled: Bool = true,
        target: CaptureTarget = .device,
        destination: MTLCaptureDestination = .developerTools
    ) -> some Element {
        CaptureModifier(content: self, enabled: enabled, target: target, destination: destination)
    }
}
