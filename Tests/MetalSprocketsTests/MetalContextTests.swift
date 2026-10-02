import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("Metal 4 context", .requiresMetal4)
struct MetalContextTests {
    @Test
    func `contexts own independent command buffers and completion events`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try device.makeMTL4CommandQueue(descriptor: MTL4CommandQueueDescriptor())
        let context = try MetalContext(device: device, commandQueue: queue)
        let independent = try MetalContext(device: device, commandQueue: queue)
        #expect(context.commandQueue === queue)
        #expect(context.completionEvent !== independent.completionEvent)
        var first: (any MTL4CommandBuffer)?
        var second: (any MTL4CommandBuffer)?
        let firstSubmission = try context.submit { first = try $0.commandBuffer() }
        let secondSubmission = try independent.submit { second = try $0.commandBuffer() }
        let firstBuffer = try #require(first)
        let secondBuffer = try #require(second)
        #expect(firstBuffer !== secondBuffer)
        try context.waitForResult(firstSubmission)
        try independent.waitForResult(secondSubmission)
    }

    @Test
    func `in flight limits must be positive`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        for limit in [0, -1] {
            #expect(throws: MetalSprocketsError.self) {
                try Runner(device: device, maximumInFlightSubmissions: limit)
            }
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func `completed command buffers are reused with correct GPU output`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 1)
        let output = try #require(device.makeBuffer(length: 4, options: .storageModeShared))
        var previous: (any MTL4CommandBuffer)?
        for frame in 1...12 {
            let submission = try context.submit { scope in
                let commandBuffer = try scope.commandBuffer()
                if let previous { #expect(commandBuffer === previous) }
                previous = commandBuffer
                try scope.retainAllocation(output)
                try scope.withComputeEncoder { $0.fill(buffer: output, range: 0..<4, value: UInt8(frame)) }
            }
            #expect(submission.identifier == UInt64(frame))
            #expect(try await context.awaitResult(submission).outcome == .completed)
            #expect(output.contents().load(as: UInt32.self) == UInt32(frame) * 0x01010101)
        }
        try await context.drain()
        #expect(context.inFlightCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func `submitting more than the limit applies backpressure instead of failing`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let runner = try Runner(device: device, maximumInFlightSubmissions: 1)
        var previous: Submission?
        for _ in 0..<20 {
            let submission = try runner.submit(EmptyElement())
            if let previous { #expect(previous.resolvedResult?.outcome == .completed) }
            #expect(runner.context.inFlightCount == 1)
            previous = submission
        }
        try #require(previous).waitUntilCompleted()
    }

    @Test(.timeLimit(.minutes(1)))
    func `backpressure timeout rejects new work before encoding`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 1, submissionTimeout: .milliseconds(50))
        let gate = try #require(device.makeSharedEvent())
        context.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        let first = try context.submit { _ in }
        var encoded = false
        #expect(throws: MetalSprocketsError.self) {
            try context.submit { _ in encoded = true }
        }
        #expect(!encoded)
        #expect(first.resolvedResult?.outcome == .timedOut)
        #expect(context.inFlightCount == 1)
        #expect(context.isFaulted)
    }

    @Test(.timeLimit(.minutes(1)))
    func `cancelled capacity waits do not cancel GPU work`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 1)
        let gate = try #require(device.makeSharedEvent())
        context.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        let submission = try context.submit { _ in }
        let waiter = Task { @MainActor in try await context.awaitSubmissionCapacity() }
        waiter.cancel()
        await #expect(throws: CancellationError.self) { try await waiter.value }
        #expect(!context.isFaulted)
        gate.signaledValue = 1
        #expect(try await context.awaitResult(submission).outcome == .completed)
        try await context.awaitSubmissionCapacity()
        #expect(context.canSubmit)
    }

    @Test(.timeLimit(.minutes(1)))
    func `lowering the in flight limit waits without dropping pending work`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 3)
        let gate = try #require(device.makeSharedEvent())
        context.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        let pending = try (0..<3).map { _ in try context.submit { _ in } }
        try context.setMaximumInFlightSubmissions(1)
        #expect(context.inFlightCount == 3)
        #expect(!context.canSubmit)
        gate.signaledValue = 1
        let next = try context.submit { _ in }
        #expect(context.inFlightCount == 1)
        #expect(pending.allSatisfy { $0.resolvedResult?.outcome == .completed })
        try context.waitForResult(next)
    }

    @Test(.timeLimit(.minutes(1)))
    func `overlapping command buffers remain distinct until GPU retirement`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 2)
        let gate = try #require(device.makeSharedEvent())
        context.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        var buffers: [any MTL4CommandBuffer] = []
        let first = try context.submit { buffers.append(try $0.commandBuffer()) }
        let second = try context.submit { buffers.append(try $0.commandBuffer()) }
        #expect(buffers[0] !== buffers[1])
        #expect(!context.canSubmit)
        #expect(first.resolvedResult == nil)
        #expect(second.resolvedResult == nil)
        gate.signaledValue = 1
        try await context.awaitSubmissionCapacity()
        let third = try context.submit { scope in
            let commandBuffer = try scope.commandBuffer()
            #expect(buffers.contains { $0 === commandBuffer })
        }
        #expect(try await context.awaitResult(third).outcome == .completed)
    }
}
