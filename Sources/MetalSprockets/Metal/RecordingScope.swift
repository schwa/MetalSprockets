import Metal
import MetalSprocketsSupport

internal final class RecordingScope {
    enum Failure: Error, Equatable {
        case encodingEnded
        case nestedEncoder
    }

    struct Resources {
        var allocations: [any MTLAllocation] = []
        var owners: [any AnyObject & Sendable] = []
        var residencySets: [any MTLResidencySet] = []
        // Non-allocation GPU objects (argument tables, samplers) that must live until the submission completes.
        var objects: [AnyObject] = []
        var terminalHandlers: [@Sendable (SubmissionResult) -> Void] = []
        var committedHandlers: [(UInt64) -> Void] = []
    }

    private let commands: CommandResources
    private var commandBufferEnded = false
    private var isActive = true
    private var hasActiveEncoder = false
    private var resources = Resources()
    private var coveredAllocations: Set<ObjectIdentifier> = []
    private var residencyMode = ResidencyConfiguration.Mode.automatic

    let device: any MTLDevice

    init(context: MetalContext, commands: CommandResources) {
        self.commands = commands
        self.device = context.device
    }

    func retain(_ owner: any AnyObject & Sendable) throws {
        guard isActive else {
            throw Failure.encodingEnded
        }
        resources.owners.append(owner)
    }

    /// Adds a handler invoked exactly once with the GPU submission's terminal result.
    func onTerminated(_ handler: @escaping @Sendable (SubmissionResult) -> Void) throws {
        guard isActive else {
            throw Failure.encodingEnded
        }
        resources.terminalHandlers.append(handler)
    }

    /// Adds a handler run on the committing thread with the submission identifier.
    func onCommitted(_ handler: @escaping (UInt64) -> Void) throws {
        guard isActive else {
            throw Failure.encodingEnded
        }
        resources.committedHandlers.append(handler)
    }

    func argumentTable(sizes: PipelineBindings.TableSizes, label: String?) throws -> any MTL4ArgumentTable {
        guard isActive else {
            throw Failure.encodingEnded
        }
        let table = try commands.argumentTables.acquire(sizes: sizes, label: label)
        try retainObject(table)
        return table
    }

    func retainObject(_ object: AnyObject) throws {
        guard isActive else {
            throw Failure.encodingEnded
        }
        resources.objects.append(object)
    }

    func retainAllocation(_ allocation: any MTLAllocation) throws {
        guard isActive else {
            throw Failure.encodingEnded
        }
        // Memoryless textures (tile-memory render targets, such as MTKView's default depth) have no memory to make
        // resident, and residency sets reject them. Keep them alive, but out of the residency set.
        if let resource = allocation as? any MTLResource, resource.storageMode == .memoryless {
            resources.objects.append(resource)
            return
        }
        resources.allocations.append(allocation)
    }

    /// Copies a shader value into scratch storage retained until the GPU submission retires.
    func scratch<T>(_ value: T, alignment: Int? = nil) throws -> ScratchArena.Allocation {
        guard isActive else {
            throw Failure.encodingEnded
        }
        return try commands.scratch.allocate(value, alignment: alignment)
    }

    func scratch<T>(_ values: [T], alignment: Int? = nil) throws -> ScratchArena.Allocation {
        guard isActive else {
            throw Failure.encodingEnded
        }
        return try commands.scratch.allocate(values, alignment: alignment)
    }

    func configureResidency(_ configuration: ResidencyConfiguration) throws {
        residencyMode = configuration.mode
        for collection in configuration.collections {
            try useResourceCollection(collection)
        }
        for residencySet in configuration.residencySets {
            try useResidencySet(residencySet)
        }
    }

    func useResourceCollection(_ collection: ResourceCollection) throws {
        guard collection.device === device else {
            throw ResourceCollection.Failure.foreignDevice
        }
        try attachResidencySet(collection.residencySet)
        retainResourceCollection(collection)
    }

    /// Attaches a residency set to the command buffer. Must run while the command buffer is open, since Metal rejects
    /// `useResidencySet` after `endCommandBuffer`.
    func attachResidencySet(_ residencySet: any MTLResidencySet) throws {
        guard isActive else {
            throw Failure.encodingEnded
        }
        guard residencySet.device === device else {
            throw ResourceCollection.Failure.foreignDevice
        }
        commands.commandBuffer.useResidencySet(residencySet)
    }

    /// Retains a resource collection's lease for the submission. Order-independent: it does not touch the command
    /// buffer, so it may run after an owner has ended it.
    func retainResourceCollection(_ collection: ResourceCollection) {
        let lease = collection.acquire()
        resources.residencySets.append(collection.residencySet)
        resources.objects.append(lease)
        coveredAllocations.formUnion(lease.identifiers)
    }

    /// Applies an externally owned residency set, such as a drawable layer's, to this recording only.
    /// Metal clears per-command-buffer sets when recording begins, so each recording must reapply them.
    func useResidencySet(_ residencySet: any MTLResidencySet) throws {
        guard isActive else {
            throw Failure.encodingEnded
        }
        guard residencySet.device === device else {
            throw ResourceCollection.Failure.foreignDevice
        }
        commands.commandBuffer.useResidencySet(residencySet)
        resources.residencySets.append(residencySet)
        let allocations = residencySet.allAllocations
        coveredAllocations.formUnion(allocations.map(ObjectIdentifier.init))
        resources.objects.append(contentsOf: allocations.map { $0 as AnyObject })
    }

    func withComputeEncoder(_ encode: (any MTL4ComputeCommandEncoder) throws -> Void) throws {
        let encoder = try beginComputeEncoder()
        defer { endEncoder(encoder) }
        try encode(encoder)
    }

    func withRenderEncoder(descriptor: MTL4RenderPassDescriptor, _ encode: (any MTL4RenderCommandEncoder) throws -> Void) throws {
        let encoder = try beginRenderEncoder(descriptor: descriptor)
        defer { endEncoder(encoder) }
        try encode(encoder)
    }

    /// Hands out the command buffer between encoders, for work that encodes itself (such as MetalFX).
    func withCommandBuffer(_ encode: (any MTL4CommandBuffer) throws -> Void) throws {
        try encode(try commandBufferForNewEncoder())
    }

    /// Opens an encoder that stays open across element traversal. Pair with `endEncoder`, including on error paths.
    func beginComputeEncoder() throws -> any MTL4ComputeCommandEncoder {
        let buffer = try commandBufferForNewEncoder()
        let encoder = try buffer.makeComputeCommandEncoder().orThrow(.resourceCreationFailure("Could not create a Metal 4 compute encoder"))
        hasActiveEncoder = true
        return encoder
    }

    func beginRenderEncoder(descriptor: MTL4RenderPassDescriptor) throws -> any MTL4RenderCommandEncoder {
        let buffer = try commandBufferForNewEncoder()
        let encoder = try buffer.makeRenderCommandEncoder(descriptor: descriptor).orThrow(.resourceCreationFailure("Could not create a Metal 4 render encoder"))
        hasActiveEncoder = true
        return encoder
    }

    func endEncoder(_ encoder: any MTL4CommandEncoder) {
        encoder.endEncoding()
        hasActiveEncoder = false
    }

    /// Records that an encoder was ended by its owner rather than through `endEncoder`.
    func encoderEnded() {
        hasActiveEncoder = false
    }

    func finish() throws -> Resources {
        guard isActive else {
            throw Failure.encodingEnded
        }
        guard !hasActiveEncoder else {
            throw Failure.nestedEncoder
        }
        resources.allocations = resources.allocations.filter { allocation in
            let heap = (allocation as? any MTLResource)?.heap
            let isCovered = coveredAllocations.contains(ObjectIdentifier(allocation))
                || heap.map { coveredAllocations.contains(ObjectIdentifier($0)) } == true
            if residencyMode == .manual || isCovered {
                resources.objects.append(allocation)
                return false
            }
            return true
        }
        isActive = false
        let retainedResources = resources
        resources = Resources()
        return retainedResources
    }

    func endCommandBuffer() {
        if !commandBufferEnded {
            commands.commandBuffer.endCommandBuffer()
            commandBufferEnded = true
        }
    }

    func invalidate() {
        isActive = false
        resources = Resources()
    }

    /// The command buffer being recorded, for publishing to the environment.
    func commandBuffer() throws -> any MTL4CommandBuffer {
        guard isActive else {
            throw Failure.encodingEnded
        }
        return commands.commandBuffer
    }

    /// Records that an owner (the visionOS compositor) ended this recording's command buffer.
    func markCommandBufferEndedByOwner() {
        commandBufferEnded = true
    }

    private func commandBufferForNewEncoder() throws -> any MTL4CommandBuffer {
        guard isActive else {
            throw Failure.encodingEnded
        }
        guard !hasActiveEncoder else {
            throw Failure.nestedEncoder
        }
        guard !commandBufferEnded else {
            throw MetalSprocketsError.configurationError("Nothing can be encoded after an immersive render pass: the compositor ends the command buffer. Put all passes before it.")
        }
        return commands.commandBuffer
    }
}
