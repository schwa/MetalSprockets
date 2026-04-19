import Foundation
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite
struct BlitPassTests {
    @Test
    func testBlitPassFillBuffer() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let buffer = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        // Pre-fill with non-zero to confirm the blit runs.
        let pre = buffer.contents().bindMemory(to: UInt8.self, capacity: 16)
        for i in 0..<16 { pre[i] = 0xAB }

        try BlitPass {
            Blit { encoder in
                encoder.fill(buffer: buffer, range: 0..<16, value: 0x42)
            }
        }
        .run()

        let ptr = buffer.contents().bindMemory(to: UInt8.self, capacity: 16)
        for i in 0..<16 {
            #expect(ptr[i] == 0x42)
        }
    }

    @Test
    func testBlitPassRequiresSetupIsFalse() throws {
        let a = try BlitPass { EmptyElement() }
        let b = try BlitPass { EmptyElement() }
        #expect(a.requiresSetup(comparedTo: b) == false)
    }

    @Test
    func testBlitRequiresSetupIsFalse() {
        let a = Blit { _ in }
        let b = Blit { _ in }
        #expect(a.requiresSetup(comparedTo: b) == false)
    }
}
