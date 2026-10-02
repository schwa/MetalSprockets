import Metal
@testable import MetalSprockets
import Testing

@MainActor
@Suite("Metal 4 scratch value storage", .requiresMetal4)
struct ScratchStorageTests {
    @Test
    func allocationsRespectAlignmentAndStoreBytes() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let arena = try ScratchArena(device: device, initialCapacity: 256)
        let first = try arena.allocate(UInt8(7))
        let second = try arena.allocate(SIMD4<Float>(1, 2, 3, 4))
        let third = try arena.allocate([UInt32(9), 10, 11], alignment: 64)
        #expect(first.offset.isMultiple(of: ScratchArena.minimumAlignment))
        #expect(second.offset.isMultiple(of: max(MemoryLayout<SIMD4<Float>>.alignment, ScratchArena.minimumAlignment)))
        #expect(third.offset.isMultiple(of: 64))
        #expect(second.gpuAddress == second.buffer.gpuAddress + UInt64(second.offset))
        #expect((second.buffer.contents() + second.offset).load(as: SIMD4<Float>.self) == SIMD4<Float>(1, 2, 3, 4))
        #expect((third.buffer.contents() + third.offset).load(fromByteOffset: 8, as: UInt32.self) == 11)
        #expect(third.length == 12)
    }

    @Test
    func invalidRequestsAreRejected() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let arena = try ScratchArena(device: device, initialCapacity: 256)
        #expect(throws: ScratchArena.Failure.emptyAllocation) { try arena.allocate([UInt32]()) }
        #expect(throws: ScratchArena.Failure.invalidAlignment(3)) { try arena.allocate(UInt32(1), alignment: 3) }
        #expect(throws: ScratchArena.Failure.invalidAlignment(0)) { try arena.allocate(UInt32(1), alignment: 0) }
    }

    @Test
    func growthKeepsEarlierAllocationsValid() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let arena = try ScratchArena(device: device, initialCapacity: 64)
        var allocations: [ScratchArena.Allocation] = []
        for index in 0..<40 {
            allocations.append(try arena.allocate(SIMD4<UInt32>(repeating: UInt32(index))))
        }
        #expect(arena.bufferCount > 1)
        for (index, allocation) in allocations.enumerated() {
            #expect((allocation.buffer.contents() + allocation.offset).load(as: SIMD4<UInt32>.self) == SIMD4(repeating: UInt32(index)))
        }
        // Oversized requests get a dedicated buffer rather than failing.
        let large = try arena.allocate([UInt8](repeating: 1, count: 4_096))
        #expect(large.length == 4_096)
    }

    @Test
    func resetReusesStorageWithBoundedGrowth() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let arena = try ScratchArena(device: device, initialCapacity: 64)
        for _ in 0..<50 {
            arena.reset()
            for index in 0..<20 {
                _ = try arena.allocate(SIMD4<UInt32>(repeating: UInt32(index)))
            }
        }
        #expect(arena.bufferCount <= 3)
    }

    @Test(.timeLimit(.minutes(1)))
    func gpuReadsEveryScratchValueAcrossGrowthAndFrames() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 2, scratchCapacity: 64)
        let count = 32
        let output = try #require(device.makeBuffer(length: count * 4, options: .storageModeShared))
        for frame in 1...6 {
            var scratchBuffers: [any MTLBuffer] = []
            let recording = try context.submit { scope in
                try scope.retainAllocation(output)
                let values = try (0..<count).map { try scope.scratch(UInt32(frame * 1_000 + $0)) }
                scratchBuffers = values.map(\.buffer)
                try scope.withComputeEncoder { encoder in
                    for (index, value) in values.enumerated() {
                        encoder.copy(sourceBuffer: value.buffer, sourceOffset: value.offset, destinationBuffer: output, destinationOffset: index * 4, size: 4)
                    }
                }
            }
            #expect(scratchBuffers.allSatisfy { !context.residencySet.containsAllocation($0) })
            let submission = recording
            #expect(try await context.awaitResult(submission).outcome == .completed)
            let results = output.contents().bindMemory(to: UInt32.self, capacity: count)
            for index in 0..<count {
                #expect(results[index] == UInt32(frame * 1_000 + index))
            }
        }
        try await context.drain()
        #expect(context.residentAllocationCount == 0)
    }

    @Test
    func failedEncodingReusesScratchStorageWithoutKeepingOldValues() throws {
        enum Failure: Error { case expected }
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, scratchCapacity: 64)
        var scratchBuffer: (any MTLBuffer)?
        #expect(throws: Failure.expected) {
            try context.submit { scope in
                scratchBuffer = try scope.scratch(UInt32(1)).buffer
                throw Failure.expected
            }
        }
        let submission = try context.submit { scope in
            let allocation = try scope.scratch(UInt32(2))
            #expect(allocation.buffer === scratchBuffer)
            #expect((allocation.buffer.contents() + allocation.offset).load(as: UInt32.self) == 2)
        }
        #expect(try context.waitForResult(submission).outcome == .completed)
    }
}
