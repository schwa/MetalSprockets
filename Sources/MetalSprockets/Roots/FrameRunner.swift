import CoreGraphics
import Metal
import MetalSprocketsSupport
import MetalSupport

/// Frame driver shared by `RenderView` and the visionOS immersive root. It reuses one context and one `System`, so
/// repeated structurally equal trees keep node state and cached pipelines. Unlike `Runner`, it can share an external
/// `System` and present drawables.
package final class FrameRunner {
    let device: any MTLDevice
    let context: MetalContext
    package let system: System

    package var residency: ResidencyConfiguration {
        get { context.residencyConfiguration }
        set { context.residencyConfiguration = newValue }
    }

    package init(device: (any MTLDevice)? = nil, commandQueue: (any MTL4CommandQueue)? = nil, system: System = System(), shaderLogging: ShaderLogging = .processDefault, maximumInFlightSubmissions: Int = 3) throws {
        let device = device ?? commandQueue?.device ?? _MTLCreateSystemDefaultDevice()
        self.device = device
        self.system = system
        self.context = try MetalContext(device: device, commandQueue: commandQueue, maximumInFlightSubmissions: maximumInFlightSubmissions, shaderLogging: shaderLogging.configuration)
    }

    /// Reports whether the in-flight limit permits another frame without waiting.
    package func prepareFrame() throws -> Bool {
        try context.retireCompletedSubmissions(flushResidency: false)
        try context.checkFault()
        return context.canSubmit
    }

    /// Awaits capacity for another submission without blocking the caller's executor.
    package nonisolated(nonsending) func waitForSubmissionCapacity() async throws {
        try await context.awaitSubmissionCapacity()
    }

    /// Records and commits `content` without presentation, for roots that present through their own API.
    @discardableResult
    package func submitFrame(_ content: some Element, residencySets: [any MTLResidencySet] = []) throws -> Submission {
        try submitFrame(content, presenting: nil, residencySets: residencySets)
    }

    /// Records and commits a frame that presents `drawable`: the queue waits for the drawable, runs the frame, signals
    /// the drawable, then presents it.
    @discardableResult
    package func submitFrame(_ content: some Element, presenting drawable: any MTLDrawable, residencySets: [any MTLResidencySet]) throws -> Submission {
        try submitFrame(content, presenting: DrawablePresentation(drawable: drawable), residencySets: residencySets)
    }

    /// Records, commits, and awaits `content`. Encoding errors throw without committing; GPU outcomes are in the result.
    @discardableResult
    nonisolated(nonsending) func run(_ content: some Element) async throws -> SubmissionResult {
        let submission = try await context.run(content, system: system)
        let result = try await submission.waitForResult()
        // Retire now, so a synchronous-style root releases residency without waiting for the next frame.
        try context.retireCompletedSubmissions()
        return result
    }

    /// Records and commits `content` without waiting.
    nonisolated(nonsending) func submit(_ content: some Element) async throws -> Submission {
        try await context.awaitSubmissionCapacity()
        return try context.submit(content, system: system)
    }

    /// Records and commits `content` synchronously, presenting `presentable` in the required order. For per-frame
    /// view drivers that call `prepareFrame` first to skip frames at the in-flight limit.
    func submitFrame(_ content: some Element, presenting presentable: (any Presentable)?, residencySets: [any MTLResidencySet]) throws -> Submission {
        try context.retireCompletedSubmissions(flushResidency: false)
        return try context.submit(content, system: system, residencySets: residencySets, presenting: presentable)
    }

    package func setMaximumInFlightSubmissions(_ limit: Int) throws {
        try context.setMaximumInFlightSubmissions(limit)
    }

    package func invalidateSetup() {
        system.markAllNodesNeedingSetup()
    }

    /// Runs `content` once on a fresh runner.
    @discardableResult
    nonisolated(nonsending) static func runOnce(_ content: some Element, device: (any MTLDevice)? = nil) async throws -> SubmissionResult {
        try await FrameRunner(device: device).run(content)
    }
}
