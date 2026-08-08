import CoreGraphics
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("MSAA modifier edge cases")
struct MSAAModifierEdgeTests {
    struct Leaf: Element, BodylessElement {
        var body: Never {
            fatalError()
        }
    }

    @Test func `a sample count of one does nothing`() throws {
        // sampleCount <= 1 returns before any device or descriptor is needed, so this works with no environment
        // at all.
        let system = System()
        try system.update(root: Leaf().msaa(sampleCount: 1))
        try system.processSetup()
    }

    @Test func `no render pass descriptor is reported`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        // sampleCount > 1 and a device, but no render pass descriptor in the environment.
        let system = System()
        #expect(throws: MetalSprocketsError.self) {
            try system.update(root: Leaf().msaa(sampleCount: 4).device(device))
        }
    }

    @Test func `a colourless render pass descriptor is reported`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let descriptor = MTLRenderPassDescriptor()
        // Deliberately no colorAttachments[0].texture.
        let system = System()
        #expect(throws: MetalSprocketsError.self) {
            try system.update(root: Leaf().msaa(sampleCount: 4).renderPassDescriptor(descriptor).device(device))
        }
    }
}
