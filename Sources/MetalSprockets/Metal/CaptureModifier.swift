import Foundation
import Metal
import MetalSprocketsSupport

// MARK: - CaptureTarget

/// What a ``Element/capture(_:target:destination:outputURL:)`` scope records.
public enum CaptureTarget: Sendable {
    /// All work on the device.
    case device
    /// Only work on the root's Metal 4 command queue.
    case commandQueue
}

public extension Element {
    /// Captures the GPU work of the submission this element encodes into, for Xcode's frame debugger or a `.gputrace`.
    ///
    /// The capture starts when the element's workload begins and stops once the submission completes (or is
    /// discarded), so it covers the whole submitted command buffer. A capture that is already running elsewhere is left
    /// alone.
    ///
    /// ```swift
    /// try RenderPass {
    ///     // render content
    /// }
    /// .capture()
    /// ```
    ///
    /// > Important: On Metal 4 the capture must wrap whole passes. Placing it inside a ``RenderPass`` or ``ComputePass``
    /// > is a configuration error.
    ///
    /// > Important: For `.developerTools` captures, the host process must have `MTL_CAPTURE_ENABLED=1` (Xcode sets it
    /// > when launching with GPU frame capture enabled). Shader logging (`MS_METAL_LOGGING`) disables capture for the
    /// > whole process.
    ///
    /// - Parameters:
    ///   - enabled: When `false`, the modifier is a no-op. Defaults to `true`.
    ///   - target: Whether to capture all work on the device or only the root's queue. Defaults to ``CaptureTarget/device``.
    ///   - destination: The capture destination. Defaults to `.developerTools`.
    ///   - outputURL: Where to write the `.gputrace` file. Required for `.gpuTraceDocument`, ignored otherwise.
    func capture(
        _ enabled: Bool = true,
        target: CaptureTarget = .device,
        destination: MTLCaptureDestination = .developerTools,
        outputURL: URL? = nil
    ) -> some Element {
        CaptureModifier(content: self, enabled: enabled, target: target, destination: destination, outputURL: outputURL)
    }
}
