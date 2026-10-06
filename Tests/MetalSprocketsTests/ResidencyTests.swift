import Metal
@testable import MetalSprockets
import Testing

@MainActor
@Suite("Metal 4 residency and retirement", .requiresMetal4)
struct ResidencyTests {
    private func buffer(_ device: any MTLDevice) throws -> any MTLBuffer {
        try #require(device.makeBuffer(length: 256, options: .storageModeShared))
    }

    @Test
    func submittedAllocationsAreResidentUntilRetired() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 2)
        let allocation = try buffer(device)
        let recording = try context.submit { scope in
            try scope.retainAllocation(allocation)
            try scope.retainAllocation(allocation)
        }
        #expect(context.residencySet.containsAllocation(allocation))
        #expect(context.residentAllocationCount == 1)
        try context.waitForResult(recording)
        try context.retireCompletedSubmissions()
        #expect(!context.residencySet.containsAllocation(allocation))
        #expect(context.residentAllocationCount == 0)
    }

    @Test
    func failedEncodingDoesNotAcquireResidency() throws {
        enum Failure: Error { case expected }
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let allocation = try buffer(device)
        #expect(throws: Failure.expected) {
            try context.submit {
                try $0.retainAllocation(allocation)
                throw Failure.expected
            }
        }
        #expect(!context.residencySet.containsAllocation(allocation))
    }

    @Test
    func sharedAllocationsStayResidentUntilTheirLastUse() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 2)
        let shared = try buffer(device)
        let firstGate = try #require(device.makeSharedEvent())
        let secondGate = try #require(device.makeSharedEvent())
        defer {
            firstGate.signaledValue = 1
            secondGate.signaledValue = 1
        }
        context.waitForEvent(firstGate, value: 1)
        let first = try context.submit { try $0.retainAllocation(shared) }
        context.waitForEvent(secondGate, value: 1)
        let second = try context.submit { try $0.retainAllocation(shared) }
        firstGate.signaledValue = 1
        try context.waitForResult(first)
        try context.retireCompletedSubmissions()
        #expect(context.residencySet.containsAllocation(shared))
        secondGate.signaledValue = 1
        try context.waitForResult(second)
        try context.retireCompletedSubmissions()
        #expect(!context.residencySet.containsAllocation(shared))
    }

    @Test(.timeLimit(.minutes(1)))
    func repeatedFramesKeepResidencyBoundedAndOutputCorrect() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 3)
        for frame in 1...40 {
            // A fresh transient buffer every frame: residency must not accumulate these.
            let transient = try buffer(device)
            let recording = try context.submit { scope in
                try scope.retainAllocation(transient)
                try scope.withComputeEncoder { $0.fill(buffer: transient, range: 0..<4, value: UInt8(frame)) }
            }
            let submission = recording
            #expect(context.residencySet.containsAllocation(transient))
            try await context.awaitResult(submission)
            #expect(transient.contents().load(as: UInt32.self) == UInt32(frame) * 0x01010101)
        }
        try await context.drain()
        #expect(context.residentAllocationCount == 0)
        #expect(context.residencySet.allocationCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func steadySceneMakesNoResidencyChurn() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 3)
        // The same persistent allocation reused every frame, as a steady scene reuses its textures.
        let persistent = try buffer(device)
        var baselineCommits = 0
        for frame in 1...20 {
            let recording = try context.submit { scope in
                try scope.retainAllocation(persistent)
                try scope.withComputeEncoder { $0.fill(buffer: persistent, range: 0..<4, value: UInt8(frame)) }
            }
            try await context.awaitResult(recording)
            // After the first frame settles, no further residency-set commits should occur.
            if frame == 1 { baselineCommits = context.residencyCommitCount }
        }
        #expect(context.residencyCommitCount == baselineCommits)
        #expect(context.residencySet.containsAllocation(persistent))
        try await context.drain()
        #expect(context.residentAllocationCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func timedOutWorkKeepsItsAllocationsResident() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 1, submissionTimeout: .milliseconds(50))
        let gate = try #require(device.makeSharedEvent())
        context.commandQueue.waitForEvent(gate, value: 1)
        let allocation = try buffer(device)
        let submission = try context.submit { try $0.retainAllocation(allocation) }
        try await context.drain()
        #expect(submission.resolvedResult?.outcome == .timedOut)
        gate.signaledValue = 1
        await context.completionEvent.valueSignaled(submission.identifier)
        try context.retireCompletedSubmissions()
        #expect(context.residencySet.containsAllocation(allocation))
    }

    @Test(.timeLimit(.minutes(1)))
    func perRecordingResidencySetsApplyToThatRecording() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 1)
        let external = try device.makeResidencySet(descriptor: MTLResidencySetDescriptor())
        let output = try buffer(device)
        external.addAllocation(output)
        external.commit()
        for value in [UInt8(3), UInt8(9)] {
            let recording = try context.submit { scope in
                try scope.useResidencySet(external)
                try scope.withComputeEncoder { $0.fill(buffer: output, range: 0..<4, value: value) }
            }
            let submission = recording
            #expect(try await context.awaitResult(submission).outcome == .completed)
            #expect(output.contents().load(as: UInt8.self) == value)
        }
        #expect(!context.residencySet.containsAllocation(output))
    }
}
