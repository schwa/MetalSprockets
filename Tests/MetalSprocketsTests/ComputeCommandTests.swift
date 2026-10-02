import Foundation
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

// Pipeline-free copies and fills, the Metal 4 replacement for BlitPass/Blit.
@MainActor
@Suite
struct ComputeCommandTests {
    @Test(.requiresMetal4)
    func testComputeCommandFillBuffer() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let buffer = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        // Pre-fill with non-zero to confirm the fill runs.
        let pre = buffer.contents().bindMemory(to: UInt8.self, capacity: 16)
        for i in 0..<16 { pre[i] = 0xAB }

        try ComputePass {
            ComputeCommand { encoder in
                encoder.fill(buffer: buffer, range: 0..<16, value: 0x42)
            }
            .useComputeResources([buffer], usage: .write)
        }
        .run()

        let ptr = buffer.contents().bindMemory(to: UInt8.self, capacity: 16)
        for i in 0..<16 {
            #expect(ptr[i] == 0x42)
        }
    }

    @Test(.requiresMetal4)
    func testComputeCommandCopiesAfterBarrier() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let source = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        let destination = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        try ComputePass {
            ComputeCommand { $0.fill(buffer: source, range: 0..<16, value: 0x33) }
            // Metal 4 does not order commands in a pass; the copy must wait for the fill.
            EncoderBarrier(after: .blit, before: .blit)
            ComputeCommand { $0.copy(sourceBuffer: source, sourceOffset: 0, destinationBuffer: destination, destinationOffset: 0, size: 16) }
        }
        .useComputeResources([source, destination], usage: [.read, .write])
        .run()
        let ptr = destination.contents().bindMemory(to: UInt8.self, capacity: 16)
        #expect((0..<16).allSatisfy { ptr[$0] == 0x33 })
    }

    @Test(.requiresMetal4)
    func testBarrierAfterPassOrdersAConsumerPass() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let source = try #require(device.makeBuffer(length: 4_096, options: .storageModeShared))
        let destination = try #require(device.makeBuffer(length: 4_096, options: .storageModeShared))
        try Group {
            try ComputePass {
                ComputeCommand { $0.fill(buffer: source, range: 0..<4_096, value: 0x5A) }
            }
            .barrierAfterPass(after: .blit, beforeQueueStages: .blit)
            try ComputePass {
                ComputeCommand { $0.copy(sourceBuffer: source, sourceOffset: 0, destinationBuffer: destination, destinationOffset: 0, size: 4_096) }
            }
        }
        .useComputeResources([source, destination], usage: [.read, .write])
        .run()
        let ptr = destination.contents().bindMemory(to: UInt8.self, capacity: 4_096)
        #expect((0..<4_096).allSatisfy { ptr[$0] == 0x5A })
    }

    @Test
    func testComputeCommandRequiresSetupIsFalse() {
        let a = ComputeCommand { _ in }
        let b = ComputeCommand { _ in }
        #expect(a.requiresSetup(comparedTo: b) == false)
    }

    @Test(.requiresMetal4)
    func testComputeCommandOutsideAPassIsReported() {
        #expect(throws: MetalSprocketsError.self) {
            try ComputeCommand { _ in }.run()
        }
    }
}
