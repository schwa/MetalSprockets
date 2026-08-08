import CoreGraphics
import Metal
@testable import MetalSprockets
import Testing

@Suite("Texture usage flags (#112)")
struct TextureUsageTests {
    @Test func `OffscreenRenderer attachments use minimal usage flags by default`() throws {
        let renderer = try OffscreenRenderer(size: CGSize(width: 16, height: 16))

        #expect(renderer.colorTexture.usage == [.renderTarget, .shaderRead])
        #expect(renderer.depthTexture.usage == [.renderTarget])
    }

    @Test func `OffscreenRenderer attachment usage is configurable`() throws {
        let renderer = try OffscreenRenderer(
            size: CGSize(width: 16, height: 16),
            colorUsage: [.renderTarget, .shaderRead, .shaderWrite],
            depthUsage: [.renderTarget, .shaderRead]
        )

        #expect(renderer.colorTexture.usage == [.renderTarget, .shaderRead, .shaderWrite])
        #expect(renderer.depthTexture.usage == [.renderTarget, .shaderRead])
    }
}
