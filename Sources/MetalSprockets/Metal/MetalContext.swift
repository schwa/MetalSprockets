import Foundation
import Metal
import MetalSprocketsSupport
import os

// Like Runner, this context stays on one isolation domain and is deliberately not Sendable.
internal final class MetalContext {
    private struct InFlightSubmission {
        let commands: CommandResources
        let allocations: [any MTLAllocation]
        let completion: SubmissionCompletion
    }

    let device: any MTLDevice
    let commandQueue: any MTL4CommandQueue
    let completionEvent: any MTLSharedEvent

    private var reusableCommands: [CommandResources] = []
    private let scratchCapacity: Int
    private(set) var maximumInFlightSubmissions: Int
    private var isEncoding = false
    // Completion callbacks are delivered on a user-interactive queue so a UI-interactive caller blocking in
    // waitForResult does not wait on a lower-QoS signaling thread (priority inversion).
    private let completionListener = MTLSharedEventListener(dispatchQueue: DispatchQueue(label: "MetalSprockets.completion", qos: .userInteractive))
    private var inFlight: [UInt64: InFlightSubmission] = [:]
    private let residency: ResidencyTracker
    // Allocations of retired submissions whose residency release is deferred until the next commit, so a steady scene
    // re-acquires the same allocations before releasing them and makes no residency-set change. Flushed on commit, on
    // any immediate-flush retire, and on drain.
    private var pendingResidencyRelease: [any MTLAllocation] = []
    let pipelines: PipelineCache
    var residencyConfiguration = ResidencyConfiguration()
    private var depthStencilStates: [DepthState: any MTLDepthStencilState] = [:]
    /// Installed on every command buffer when shader logging is on. Logging is per submission, not per subtree.
    let logState: (any MTLLogState)?

    /// The context-owned residency set, attached to the queue. It contains only allocations used by live recordings.
    var residencySet: any MTLResidencySet { residency.residencySet }
    var residentAllocationCount: Int { residency.trackedCount }
    var residencyCommitCount: Int { residency.commitCount }
    private var lastSubmissionIdentifier: UInt64 = 0
    private var submissionCommitted: (@Sendable (UInt64, String?) -> Void)?
    // Faulted from off-isolation completion callbacks, so it needs its own lock.
    private let faultState = OSAllocatedUnfairLock(initialState: false)
    private let terminalHandler: OSAllocatedUnfairLock<(@Sendable (SubmissionResult) -> Void)?>
    private let resultDelivery: ResultDelivery

    /// A finite default deadline for a single submission. Lifecycle owners can override per context; this is a
    /// conservative safety bound, not an operational frame budget.
    let submissionTimeout: Duration

    var isFaulted: Bool { faultState.withLock { $0 } }

    var canSubmit: Bool { inFlight.count < maximumInFlightSubmissions && !isFaulted }

    /// Sets the CPU-side notification invoked synchronously on the committing isolation when a recording is submitted
    /// to the queue. It always precedes that recording's terminal result. It is not a GPU-start notification.
    func onSubmissionCommitted(_ handler: @escaping @Sendable (UInt64, String?) -> Void) {
        submissionCommitted = handler
    }

    /// Sets the terminal-result handler. Results arrive serially, exactly once each, in submission order. A submission
    /// that never resolves holds back later results until it completes or an awaiting caller times it out.
    func onSubmissionTerminated(_ handler: @escaping @Sendable (SubmissionResult) -> Void) {
        terminalHandler.withLock { $0 = handler }
    }

    init(device: any MTLDevice, commandQueue: (any MTL4CommandQueue)? = nil, maximumInFlightSubmissions: Int = 3, submissionTimeout: Duration = .seconds(5), scratchCapacity: Int = 4_096, shaderLogging: ShaderLogging.Configuration? = .systemDefault) throws {
        self.submissionTimeout = submissionTimeout
        if let shaderLogging {
            let descriptor = MTLLogStateDescriptor()
            descriptor.bufferSize = shaderLogging.bufferSize
            let logState = try device.makeLogState(descriptor: descriptor)
            let handler = shaderLogging.handler
            logState.addLogHandler { _, _, _, message in handler(message) }
            self.logState = logState
        } else {
            self.logState = nil
        }
        let terminalHandler = OSAllocatedUnfairLock<(@Sendable (SubmissionResult) -> Void)?>(initialState: nil)
        self.terminalHandler = terminalHandler
        self.resultDelivery = ResultDelivery { result in
            terminalHandler.withLock { $0 }?(result)
        }
        guard maximumInFlightSubmissions > 0 else {
            throw MetalSprocketsError.configurationError("maximumInFlightSubmissions must be positive.")
        }
        self.maximumInFlightSubmissions = maximumInFlightSubmissions
        self.scratchCapacity = scratchCapacity
        try Self.validateDevice(
            supportsMetal4: device.supportsFamily(.metal4),
            deviceIdentifier: ObjectIdentifier(device),
            queueDeviceIdentifier: commandQueue.map { ObjectIdentifier($0.device) },
            deviceName: device.name
        )
        self.device = device
        self.commandQueue = try commandQueue ?? device.makeMTL4CommandQueue(descriptor: MTL4CommandQueueDescriptor())
        self.completionEvent = try device.makeSharedEvent().orThrow(.resourceCreationFailure("Could not create the Metal 4 completion event"))
        self.completionEvent.signaledValue = 0
        self.residency = try ResidencyTracker(device: device)
        self.pipelines = try PipelineCache(device: device)
        self.commandQueue.addResidencySet(residency.residencySet)
    }

    @discardableResult
    func submit(presenting presentable: (any Presentable)? = nil, _ encode: (RecordingScope) throws -> Void) throws -> Submission {
        guard !isEncoding else {
            throw MetalSprocketsError.configurationError("Cannot submit recursively while encoding on the same runner.")
        }
        try waitForSubmissionCapacity()
        guard lastSubmissionIdentifier < UInt64.max else {
            throw MetalSprocketsError.validationError("Metal 4 submission identifiers are exhausted.")
        }
        isEncoding = true
        defer { isEncoding = false }
        let commands: CommandResources
        if let reused = reusableCommands.popLast() {
            reused.reset()
            commands = reused
        } else {
            commands = try CommandResources(device: device, scratchCapacity: scratchCapacity)
        }
        if let logState {
            let options = MTL4CommandBufferOptions()
            options.logState = logState
            commands.commandBuffer.beginCommandBuffer(allocator: commands.allocator, options: options)
        } else {
            commands.commandBuffer.beginCommandBuffer(allocator: commands.allocator)
        }
        let scope = RecordingScope(context: self, commands: commands)
        let resources: RecordingScope.Resources
        do {
            try scope.configureResidency(residencyConfiguration)
            // Attach the scratch residency set while the command buffer is open. An owner (the visionOS compositor)
            // can end the command buffer during `encode`, so attaching afterwards trips the residency-set validation
            // assertion. The set is persistent and commits as buffers register, so attaching it empty is fine.
            try scope.attachResidencySet(commands.scratch.resources.residencySet)
            try encode(scope)
            if !commands.scratch.usedBuffers.isEmpty {
                scope.retainResourceCollection(commands.scratch.resources)
                for buffer in commands.scratch.usedBuffers {
                    try scope.retainAllocation(buffer)
                }
            }
            resources = try scope.finish()
        } catch {
            scope.endCommandBuffer()
            scope.invalidate()
            reusableCommands.append(commands)
            throw error
        }
        scope.endCommandBuffer()
        return commit(commands, resources: resources, presenting: presentable)
    }

    func setMaximumInFlightSubmissions(_ limit: Int) throws {
        guard limit > 0 else {
            throw MetalSprocketsError.configurationError("maximumInFlightSubmissions must be positive.")
        }
        maximumInFlightSubmissions = limit
        if reusableCommands.count > limit {
            reusableCommands.removeLast(reusableCommands.count - limit)
        }
    }

    func waitForSubmissionCapacity() throws {
        try retireCompletedSubmissions(flushResidency: false)
        while !canSubmit, let identifier = inFlight.keys.min(), let submission = inFlight[identifier], !isFaulted {
            try waitForResult(Submission(identifier: identifier, completion: submission.completion))
            try retireCompletedSubmissions(flushResidency: false)
        }
        try checkFault()
    }

    nonisolated(nonsending) func awaitSubmissionCapacity() async throws {
        try Task.checkCancellation()
        try retireCompletedSubmissions(flushResidency: false)
        while !canSubmit, !isFaulted {
            guard let identifier = inFlight.keys.min(), let submission = inFlight[identifier] else {
                break
            }
            try await awaitResult(Submission(identifier: identifier, completion: submission.completion))
            try retireCompletedSubmissions(flushResidency: false)
        }
        try Task.checkCancellation()
        try checkFault()
    }

    func checkFault() throws {
        guard !isFaulted else {
            throw MetalSprocketsError.validationError("The Metal 4 context is faulted after a GPU failure or timeout. Create a new context to resume rendering.")
        }
    }

    /// Awaits a submission with the context deadline, faulting the context if the deadline elapses first.
    /// Runs on the caller's isolation so the non-`Sendable` context never leaves its owning domain.
    @discardableResult
    nonisolated(nonsending) func awaitResult(_ submission: Submission, timeout: Duration? = nil) async throws -> SubmissionResult {
        let deadline = timeout ?? submissionTimeout
        let faultState = faultState
        return try await withThrowingTaskGroup(of: SubmissionResult.self) { group in
            group.addTask { try await submission.waitForResult() }
            group.addTask {
                try await Task.sleep(for: deadline)
                submission.completion.markTimedOut()
                return try await submission.waitForResult()
            }
            let result = try await group.next().orThrow(.generic("Metal 4 submission produced no result"))
            group.cancelAll()
            if result.outcome != .completed {
                faultState.withLock { $0 = true }
            }
            return result
        }
    }

    /// Blocks until a submission ends or the deadline passes, faulting the context on timeout or failure.
    /// For synchronous roots only; async callers use `awaitResult`. Terminal results are delivered off the caller's
    /// thread, so blocking here cannot deadlock delivery.
    @discardableResult
    func waitForResult(_ submission: Submission, timeout: Duration? = nil) throws -> SubmissionResult {
        let deadline = timeout ?? submissionTimeout
        let semaphore = DispatchSemaphore(value: 0)
        submission.onTerminated { _ in semaphore.signal() }
        let seconds = Double(deadline.components.seconds) + Double(deadline.components.attoseconds) / 1e18
        if semaphore.wait(timeout: .now() + seconds) == .timedOut {
            submission.completion.markTimedOut()
        }
        let result = try submission.resolvedResult.orThrow(.generic("Metal 4 submission produced no result"))
        if result.outcome != .completed {
            faultState.withLock { $0 = true }
        }
        return result
    }

    /// Commits a recording. With a presentable target, the order is: wait for the target, commit, signal the target,
    /// present, then signal completion, so display never reads a partially rendered target.
    private func commit(_ commands: CommandResources, resources: RecordingScope.Resources, presenting presentable: (any Presentable)?) -> Submission {
        let commandBuffer = commands.commandBuffer
        var resources = resources
        resources.allocations = residency.acquire(resources.allocations)
        flushPendingResidencyRelease()
        resources.owners.append(commandQueue)
        resources.owners.append(completionEvent)
        resources.owners.append(completionListener)
        lastSubmissionIdentifier += 1
        let identifier = lastSubmissionIdentifier
        let completion = SubmissionCompletion(submissionIdentifier: identifier, label: commandBuffer.label, commandBuffer: commandBuffer, allocator: commands.allocator, resources: resources)
        inFlight[identifier] = InFlightSubmission(commands: commands, allocations: resources.allocations, completion: completion)
        completion.retainUntilCompleted()
        let faultState = faultState
        let resultDelivery = resultDelivery
        completion.onTerminated { result in
            if result.outcome != .completed {
                faultState.withLock { $0 = true }
            }
            resultDelivery.deliver(result)
        }
        for handler in resources.terminalHandlers {
            completion.onTerminated(handler)
        }
        // Native MTL4CommandQueue.commit cannot fail, so notifying first is observably equivalent and guarantees the
        // commit notification precedes any terminal result.
        presentable?.waitForAvailability(on: commandQueue)
        submissionCommitted?(identifier, commandBuffer.label)
        for handler in resources.committedHandlers {
            handler(identifier)
        }
        completionEvent.notify(completionListener, atValue: identifier) { _, _ in
            completion.recordEvent()
        }
        let options = MTL4CommitOptions()
        options.addFeedbackHandler { feedback in
            let error = feedback.error.map { error in
                let nativeError = error as NSError
                return Submission.Failure.gpuFailure(domain: nativeError.domain, code: nativeError.code, message: nativeError.localizedDescription)
            }
            completion.recordFeedback(error: error, gpuStartTime: feedback.gpuStartTime, gpuEndTime: feedback.gpuEndTime)
        }
        commandQueue.commit([commandBuffer], options: options)
        if let presentable {
            presentable.signalCompletion(on: commandQueue)
            presentable.present()
        }
        commandQueue.signalEvent(completionEvent, value: identifier)
        return Submission(identifier: identifier, completion: completion)
    }

    /// Awaits every submitted recording, then retires the successful ones. Failed or timed-out work stays quarantined
    /// with its resources.
    nonisolated(nonsending) func drain(timeout: Duration? = nil) async throws {
        let outstanding = inFlight.sorted { $0.key < $1.key }
        for (identifier, submission) in outstanding {
            _ = try await awaitResult(Submission(identifier: identifier, completion: submission.completion), timeout: timeout)
        }
        try retireCompletedSubmissions()
    }

    var inFlightCount: Int { inFlight.count }

    /// Returns a cached depth-stencil state, so steady-state draws never allocate one.
    func depthStencilState(_ state: DepthState) throws -> any MTLDepthStencilState {
        if let cached = depthStencilStates[state] {
            return cached
        }
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = state.compare
        descriptor.isDepthWriteEnabled = state.isWriteEnabled
        descriptor.frontFaceStencil = state.frontStencil?.makeDescriptor()
        descriptor.backFaceStencil = state.backStencil?.makeDescriptor()
        let created = try device.makeDepthStencilState(descriptor: descriptor).orThrow(.resourceCreationFailure("Could not create a depth-stencil state"))
        depthStencilStates[state] = created
        return created
    }

    /// Signals `event` after all work committed to this context's queue so far. Cross-queue dependencies are explicit;
    /// a queue barrier cannot order work on another queue.
    func signalEvent(_ event: any MTLEvent, value: UInt64) {
        commandQueue.signalEvent(event, value: value)
    }

    /// Makes work committed after this call wait for `event` to reach `value`.
    func waitForEvent(_ event: any MTLEvent, value: UInt64) {
        commandQueue.waitForEvent(event, value: value)
    }

    /// Retires completed submissions. By default it releases their residency immediately; `flushResidency: false` defers
    /// the release into `pendingResidencyRelease`, which the next `commit` flushes right after acquiring the new frame's
    /// allocations. Deferring keeps a steady scene from removing and re-adding the same allocations every frame.
    func retireCompletedSubmissions(flushResidency: Bool = true) throws {
        for (identifier, submission) in inFlight where submission.completion.isRetiredSuccessfully {
            pendingResidencyRelease.append(contentsOf: submission.allocations)
            if reusableCommands.count < maximumInFlightSubmissions {
                reusableCommands.append(submission.commands)
            }
            inFlight.removeValue(forKey: identifier)
        }
        if flushResidency {
            flushPendingResidencyRelease()
        }
    }

    private func flushPendingResidencyRelease() {
        guard !pendingResidencyRelease.isEmpty else {
            return
        }
        residency.release(pendingResidencyRelease)
        pendingResidencyRelease.removeAll(keepingCapacity: true)
    }

    static func validateDevice(supportsMetal4: Bool, deviceIdentifier: ObjectIdentifier, queueDeviceIdentifier: ObjectIdentifier?, deviceName: String) throws {
        guard supportsMetal4 else {
            throw MetalSprocketsError.deviceCababilityFailure("Device '\(deviceName)' does not support Metal 4. Select a Metal 4-capable device; there is no legacy fallback.")
        }
        if let queueDeviceIdentifier, queueDeviceIdentifier != deviceIdentifier {
            throw MetalSprocketsError.configurationError("The injected Metal 4 queue belongs to another device. Use the same device for the queue and renderer context.")
        }
    }
}
