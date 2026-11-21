import Metal
import MetalSupport

/// The Metal context settings shared by every root: ``Runner``, ``OffscreenRenderer``, ``OffscreenVideoRenderer`` and
/// `RenderView` (#483).
///
/// `RenderView` fills it from its SwiftUI modifiers (`.environment(\.device, …)`, `.metalShaderLogging(_:)`, …) and its
/// init parameters. The other roots take it directly.
///
/// ```swift
/// let runner = try Runner(configuration: .init(device: device, maximumInFlightSubmissions: 1))
/// ```
public struct MetalContextConfiguration {
    /// The device to use. `nil` uses the command queue's device, else the system default device. It must support
    /// Metal 4.
    public var device: (any MTLDevice)?
    /// A Metal 4 queue on `device`. `nil` creates a new queue.
    public var commandQueue: (any MTL4CommandQueue)?
    /// Where shader `os_log` messages go.
    public var shaderLogging: ShaderLogging
    /// How resources are made resident for each submission.
    public var residency: ResidencyConfiguration
    /// The most submissions that can be on the GPU at once. Must be positive.
    public var maximumInFlightSubmissions: Int

    public init(
        device: (any MTLDevice)? = nil,
        commandQueue: (any MTL4CommandQueue)? = nil,
        shaderLogging: ShaderLogging = .processDefault,
        residency: ResidencyConfiguration = ResidencyConfiguration(),
        maximumInFlightSubmissions: Int = 3
    ) {
        self.device = device
        self.commandQueue = commandQueue
        self.shaderLogging = shaderLogging
        self.residency = residency
        self.maximumInFlightSubmissions = maximumInFlightSubmissions
    }

    /// The device to use: `device`, else the queue's device, else the system default device.
    var resolvedDevice: any MTLDevice {
        device ?? commandQueue?.device ?? _MTLCreateSystemDefaultDevice()
    }

    func makeContext() throws -> MetalContext {
        let context = try MetalContext(device: resolvedDevice, commandQueue: commandQueue, maximumInFlightSubmissions: maximumInFlightSubmissions, shaderLogging: shaderLogging.configuration)
        context.residencyConfiguration = residency
        return context
    }
}
