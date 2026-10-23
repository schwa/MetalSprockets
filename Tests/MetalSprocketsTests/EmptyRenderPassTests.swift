import Metal
@testable import MetalSprockets
import Testing

// #552: a pass with no draws must still clear the current frame's target, not last frame's.
@MainActor
@Suite("Empty render pass", .requiresMetal4)
struct EmptyRenderPassTests {
    @Test(.timeLimit(.minutes(1)))
    func emptyPassClearsEachFramesTarget() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let runner = try Runner(device: device)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 4, height: 4, mipmapped: false)
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        textureDescriptor.storageMode = .shared
        for _ in 0..<3 {
            let target = try #require(device.makeTexture(descriptor: textureDescriptor))
            let pass = MTL4RenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)
            try runner.run(try RenderPass { EmptyElement() }.renderPassDescriptor(pass))
            var pixel = [UInt8](repeating: 0, count: 4)
            target.getBytes(&pixel, bytesPerRow: 16, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0)
            #expect(pixel == [0, 0, 255, 255])
        }
    }
}
