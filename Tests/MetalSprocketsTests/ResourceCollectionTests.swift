import Metal
@testable import MetalSprockets
import Testing

@MainActor
@Suite("Persistent resource residency", .requiresMetal4)
struct ResourceCollectionTests {
    @Test
    func `registered resources survive serial recordings without fallback tracking`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let collection = try ResourceCollection(device: device)
        let persistent = try #require(device.makeBuffer(length: 16))
        let transient = try #require(device.makeBuffer(length: 16))
        try collection.register(persistent)
        try collection.register(persistent)
        let context = try MetalContext(device: device)
        context.residencyConfiguration = ResidencyConfiguration(collections: [collection])
        for _ in 0..<5 {
            let recording = try context.submit { scope in
                try scope.retainAllocation(persistent)
                try scope.retainAllocation(transient)
            }
            #expect(context.residentAllocationCount == 1)
            #expect(!context.residencySet.containsAllocation(persistent))
            try context.waitForResult(recording)
            try context.retireCompletedSubmissions()
            #expect(context.residentAllocationCount == 0)
            #expect(collection.residencySet.containsAllocation(persistent))
        }
        collection.unregister(persistent)
        #expect(!collection.residencySet.containsAllocation(persistent))
    }

    @Test
    func `unregister waits for every submission and supports reregistration`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let collection = try ResourceCollection(device: device)
        let buffer = try #require(device.makeBuffer(length: 16))
        try collection.register(buffer)
        let context = try MetalContext(device: device)
        context.residencyConfiguration.collections = [collection]
        let firstGate = try #require(device.makeSharedEvent())
        let secondGate = try #require(device.makeSharedEvent())
        defer {
            firstGate.signaledValue = 1
            secondGate.signaledValue = 1
        }
        context.waitForEvent(firstGate, value: 1)
        let first = try context.submit { try $0.retainAllocation(buffer) }
        context.waitForEvent(secondGate, value: 1)
        let second = try context.submit { try $0.retainAllocation(buffer) }
        collection.unregister(buffer)
        #expect(!collection.contains(buffer))
        #expect(collection.residencySet.containsAllocation(buffer))
        firstGate.signaledValue = 1
        try context.waitForResult(first)
        #expect(collection.residencySet.containsAllocation(buffer))
        #expect(second.resolvedResult == nil)
        try collection.register(buffer)
        secondGate.signaledValue = 1
        try context.waitForResult(second)
        #expect(collection.residencySet.containsAllocation(buffer))
        collection.unregister(buffer)
        #expect(!collection.residencySet.containsAllocation(buffer))
    }

    @Test
    func `failed encoding releases collection leases`() throws {
        enum Failure: Error { case expected }
        let device = try #require(MTLCreateSystemDefaultDevice())
        let collection = try ResourceCollection(device: device)
        let buffer = try #require(device.makeBuffer(length: 16))
        let context = try MetalContext(device: device)
        context.residencyConfiguration.collections = [collection]
        for _ in 0..<2 {
            try collection.register(buffer)
            #expect(throws: Failure.expected) {
                try context.submit { scope in
                    try scope.retainAllocation(buffer)
                    collection.unregister(buffer)
                    throw Failure.expected
                }
            }
            #expect(!collection.residencySet.containsAllocation(buffer))
            #expect(context.inFlightCount == 0)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func `GPU completion releases unregistered allocations after gated work`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let collection = try ResourceCollection(device: device)
        let buffer = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        try collection.register(buffer)
        let context = try MetalContext(device: device)
        context.residencyConfiguration.collections = [collection]
        let gate = try #require(device.makeSharedEvent())
        context.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        let recording = try context.submit { scope in
            try scope.retainAllocation(buffer)
            try scope.withComputeEncoder { $0.fill(buffer: buffer, range: 0..<16, value: 7) }
        }
        let submission = recording
        collection.unregister(buffer)
        #expect(collection.residencySet.containsAllocation(buffer))
        #expect(submission.resolvedResult == nil)
        gate.signaledValue = 1
        #expect(try await context.awaitResult(submission).outcome == .completed)
        try await context.drain()
        #expect(buffer.contents().load(as: UInt8.self) == 7)
        #expect(!collection.residencySet.containsAllocation(buffer))
    }

    @Test
    func `manual mode retains resources without automatic residency`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        context.residencyConfiguration.mode = .manual
        let gate = try #require(device.makeSharedEvent())
        context.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        weak var retained: (any MTLBuffer)?
        let recording = try context.submit { scope in
            let buffer = try #require(device.makeBuffer(length: 16))
            retained = buffer
            try scope.retainAllocation(buffer)
        }
        #expect(retained != nil)
        #expect(context.residentAllocationCount == 0)
        gate.signaledValue = 1
        try context.waitForResult(recording)
        try context.retireCompletedSubmissions()
        #expect(retained == nil)
    }

    @Test
    func `unregistered allocations return to automatic fallback for new recordings`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let collection = try ResourceCollection(device: device)
        let buffer = try #require(device.makeBuffer(length: 16))
        try collection.register(buffer)
        let context = try MetalContext(device: device)
        context.residencyConfiguration.collections = [collection]
        let firstGate = try #require(device.makeSharedEvent())
        let secondGate = try #require(device.makeSharedEvent())
        defer {
            firstGate.signaledValue = 1
            secondGate.signaledValue = 1
        }
        context.waitForEvent(firstGate, value: 1)
        let first = try context.submit { try $0.retainAllocation(buffer) }
        collection.unregister(buffer)
        context.waitForEvent(secondGate, value: 1)
        let second = try context.submit { try $0.retainAllocation(buffer) }
        #expect(context.residencySet.containsAllocation(buffer))
        firstGate.signaledValue = 1
        try context.waitForResult(first)
        try context.retireCompletedSubmissions()
        #expect(!collection.residencySet.containsAllocation(buffer))
        #expect(context.residencySet.containsAllocation(buffer))
        secondGate.signaledValue = 1
        try context.waitForResult(second)
        try context.retireCompletedSubmissions()
        #expect(context.residentAllocationCount == 0)
    }

    @Test
    func `dropping the owner preserves resources until GPU completion`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let gate = try #require(device.makeSharedEvent())
        context.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        weak var retained: (any MTLBuffer)?
        weak var owner: ResourceCollection?
        let submission = try autoreleasepool {
            try context.submit { scope in
                let collection = try ResourceCollection(device: device)
                owner = collection
                let buffer = try #require(device.makeBuffer(length: 16))
                retained = buffer
                try collection.register(buffer)
                try scope.useResourceCollection(collection)
                try scope.retainAllocation(buffer)
            }
        }
        #expect(owner != nil)
        #expect(retained != nil)
        gate.signaledValue = 1
        try context.waitForResult(submission)
        try context.retireCompletedSubmissions()
        #expect(owner == nil)
        #expect(context.residentAllocationCount == 0)
    }

    @Test
    func `heap membership covers its resources without duplicate tracking`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let descriptor = MTLHeapDescriptor()
        descriptor.size = 65_536
        descriptor.storageMode = .private
        let heap = try #require(device.makeHeap(descriptor: descriptor))
        let buffer = try #require(heap.makeBuffer(length: 16, options: .storageModePrivate))
        let collection = try ResourceCollection(device: device)
        try collection.register(heap)
        let context = try MetalContext(device: device)
        context.residencyConfiguration.collections = [collection]
        let recording = try context.submit { try $0.retainAllocation(buffer) }
        #expect(context.residentAllocationCount == 0)
        try context.waitForResult(recording)
        try context.retireCompletedSubmissions()
    }

    @Test
    func `Runner applies collections and client sets without automatic tracking`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let collection = try ResourceCollection(device: device)
        let buffer = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        let externalBuffer = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        try collection.register(buffer)
        let external = try device.makeResidencySet(descriptor: MTLResidencySetDescriptor())
        external.addAllocation(externalBuffer)
        external.commit()
        let runner = try Runner(device: device, residency: ResidencyConfiguration(collections: [collection], residencySets: [external]))
        let submission = try runner.submit(
            try ComputePass {
                ComputeCommand {
                    $0.fill(buffer: buffer, range: 0..<16, value: 7)
                    $0.fill(buffer: externalBuffer, range: 0..<16, value: 9)
                }
            }.useResources([buffer, externalBuffer])
        )
        #expect(runner.context.residentAllocationCount == 0)
        try submission.waitUntilCompleted()
        #expect(buffer.contents().load(as: UInt8.self) == 7)
        #expect(externalBuffer.contents().load(as: UInt8.self) == 9)
        collection.unregister(buffer)
        #expect(!collection.residencySet.containsAllocation(buffer))
    }

    @Test
    func `MSAA replacement retains old targets until submitted work completes`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let gate = try #require(device.makeSharedEvent())
        context.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        let system = System()
        weak var old: (any MTLTexture)?
        func submit(size: Int) throws -> Submission {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
            descriptor.usage = .renderTarget
            let target = try #require(device.makeTexture(descriptor: descriptor))
            let pass = MTL4RenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            let content = try RenderPass {
                EmptyElement().onWorkloadEnter { environment in
                    if size == 16 { old = environment.renderPassDescriptor?.colorAttachments[0].texture }
                }
            }.msaa(sampleCount: 4).renderPassDescriptor(pass)
            return try context.submit(content, system: system)
        }
        let first = try submit(size: 16)
        #expect(old?.width == 16)
        let second = try submit(size: 32)
        #expect(old != nil)
        #expect(first.resolvedResult == nil)
        gate.signaledValue = 1
        #expect(try context.waitForResult(first).outcome == .completed)
        #expect(try context.waitForResult(second).outcome == .completed)
        try context.retireCompletedSubmissions()
        #expect(context.inFlightCount == 0)
    }

    @Test
    func `timeouts do not release collection leases as successful completions`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let collection = try ResourceCollection(device: device)
        let buffer = try #require(device.makeBuffer(length: 16))
        try collection.register(buffer)
        let completion = SubmissionCompletion(submissionIdentifier: 1, label: nil, owners: [collection.acquire()])
        collection.unregister(buffer)
        completion.markTimedOut()
        completion.recordFeedback(error: nil)
        completion.recordEvent()
        #expect(completion.resolvedResult?.outcome == .timedOut)
        #expect(collection.residencySet.containsAllocation(buffer))
        withExtendedLifetime(completion) {}
    }

    @Test
    func `client sets suppress duplicate automatic tracking`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let set = try device.makeResidencySet(descriptor: MTLResidencySetDescriptor())
        let buffer = try #require(device.makeBuffer(length: 16))
        set.addAllocation(buffer)
        set.commit()
        let context = try MetalContext(device: device)
        context.residencyConfiguration.residencySets = [set]
        let recording = try context.submit { try $0.retainAllocation(buffer) }
        #expect(context.residentAllocationCount == 0)
        try context.waitForResult(recording)
        try context.retireCompletedSubmissions()
        #expect(set.containsAllocation(buffer))
    }
}
