import Metal
import MetalSprocketsSupport
import MetalSupport

// MARK: - Runner

/// A reusable driver for running an element tree many times against the same
/// device and command queue.
///
/// Use `Runner` instead of ``Element/run()`` when you need to execute the same
/// (or structurally similar) element tree repeatedly — for example, an offline
/// bake that renders thousands of frames. A single ``Runner`` amortizes the
/// cost of constructing the internal engine, looking up pipeline state objects,
/// and resolving descriptors across calls.
///
/// ## Overview
///
/// ```swift
/// let runner = try Runner()
/// for sample in samples {
///     try runner.run(
///         RenderPass {
///             // ... element tree, possibly parameterized by `sample`
///         }
///     )
/// }
/// ```
///
/// Each call to ``run(_:)`` wraps the supplied element in a
/// `CommandBufferElement(completion: .commitAndWaitUntilCompleted)`, injects
/// the runner's `device` and `commandQueue` into the environment, then drives
/// the internal engine through its update, setup, and workload phases.
///
/// When successive calls use a structurally-equal element tree, nodes are
/// reused and the setup phase becomes a near no-op, leaving only the actual
/// workload (command buffer encoding + GPU execution) on the per-call path.
///
/// ## Isolation
///
/// `Runner` is intentionally not `Sendable`. An instance must be confined to a
/// single isolation context (one actor, one thread, or synchronous
/// single-threaded code). Do not share a `Runner` across isolation domains.
///
/// ## Topics
///
/// ### Creating a Runner
/// - ``init(device:commandQueue:)``
///
/// ### Running an Element Tree
/// - ``run(_:)``
///
/// ### Inspecting the Runner
/// - ``device``
/// - ``commandQueue``
public final class Runner {
    /// The Metal device used by this runner.
    public let device: MTLDevice

    /// The command queue used to submit work for each ``run(_:)`` call.
    public let commandQueue: MTLCommandQueue

    private let system: System

    /// Creates a new runner.
    ///
    /// - Parameters:
    ///   - device: The Metal device to render against. If `nil`, the system
    ///     default device is used.
    ///   - commandQueue: The command queue to submit work to. If `nil`, a new
    ///     command queue is created from `device`.
    /// - Throws: ``MetalSprocketsError`` if a command queue cannot be created.
    public init(device: MTLDevice? = nil, commandQueue: MTLCommandQueue? = nil) throws {
        let resolvedDevice = device ?? _MTLCreateSystemDefaultDevice()
        self.device = resolvedDevice
        self.commandQueue = try commandQueue ?? resolvedDevice._makeCommandQueue()
        self.system = System()
    }

    /// Runs the given element tree once, reusing the internal engine.
    ///
    /// The content is wrapped in a `CommandBufferElement` that commits and
    /// waits for completion before returning. Successive calls with a
    /// structurally-equal tree reuse cached pipeline state and skip per-node
    /// setup work.
    ///
    /// - Parameter content: The element tree to run.
    /// - Throws: Any error thrown during update, setup, or workload phases.
    public func run<Content>(_ content: Content) throws where Content: Element {
        let wrapped = CommandBufferElement(completion: .commitAndWaitUntilCompleted) {
            content
        }
        .environment(\.commandQueue, commandQueue)
        .environment(\.device, device)

        try system.update(root: wrapped)
        try system.withCurrentSystem {
            try system.processSetup()
            try system.processWorkload()
        }
    }
}
