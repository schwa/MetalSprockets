import Metal
import MetalSprocketsSupport
import MetalSupport

// MARK: - Runner

/// A reusable driver for running an element tree many times against the same device and Metal 4 queue.
///
/// Use `Runner` instead of ``Element/run()`` when you execute the same (or structurally similar) tree repeatedly, for
/// example an offline bake that renders thousands of frames. One runner owns one Metal 4 context: its command allocators,
/// residency set, compiled pipelines and element nodes are reused across calls, so steady-state calls neither
/// recompile nor rebuild setup.
///
/// ```swift
/// let runner = try Runner()
/// for sample in samples {
///     try runner.run(
///         ComputePass {
///             // ... element tree, possibly parameterized by `sample`
///         }
///     )
/// }
/// ```
///
/// ``run(_:)`` submits and waits. ``submit(_:)`` returns after submission, allowing CPU/GPU overlap.
/// When `maximumInFlightSubmissions` is reached, submission waits for the oldest outstanding work.
///
/// `Runner` is not thread-safe; use it from one isolation domain.
public final class Runner {
    public let device: MTLDevice
    public let commandQueue: any MTL4CommandQueue
    internal let context: MetalContext
    internal let system = System()
    public let maximumInFlightSubmissions: Int

    public var residency: ResidencyConfiguration {
        get { context.residencyConfiguration }
        set { context.residencyConfiguration = newValue }
    }

    /// Creates a runner.
    ///
    /// - Parameters:
    ///   - device: The device to use. Defaults to the system default device, which must support Metal 4.
    ///   - commandQueue: A Metal 4 queue on `device`. Defaults to a new queue.
    ///   - shaderLogging: Where shader `os_log` messages go. Defaults to ``ShaderLogging/processDefault``.
    public init(device: MTLDevice? = nil, commandQueue: (any MTL4CommandQueue)? = nil, shaderLogging: ShaderLogging = .processDefault, residency: ResidencyConfiguration = ResidencyConfiguration(), maximumInFlightSubmissions: Int = 3) throws {
        let resolvedDevice = device ?? commandQueue?.device ?? _MTLCreateSystemDefaultDevice()
        context = try MetalContext(device: resolvedDevice, commandQueue: commandQueue, maximumInFlightSubmissions: maximumInFlightSubmissions, shaderLogging: shaderLogging.configuration)
        self.maximumInFlightSubmissions = maximumInFlightSubmissions
        context.residencyConfiguration = residency
        self.device = resolvedDevice
        self.commandQueue = context.commandQueue
    }

    /// Encodes `content`, commits it, and waits for the GPU to finish.
    ///
    /// Throws if encoding fails, or if the GPU reports a failure or does not finish within the deadline.
    public func run<Content>(_ content: Content) throws where Content: Element {
        let submission = try submit(content)
        let result = try context.waitForResult(submission)
        try context.retireCompletedSubmissions()
        guard result.outcome == .completed else {
            throw MetalSprocketsError.validationError("GPU work did not complete: \(result.outcome)")
        }
    }

    /// Submits `content` without waiting for its completion; waits for earlier work if the in-flight limit is reached.
    public func submit<Content>(_ content: Content) throws -> Submission where Content: Element {
        try context.submit(content, system: system)
    }
}
