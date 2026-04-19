#if canImport(MetalFX)
import Metal
import MetalFX
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("MetalFXSpatial Tests")
struct MetalFXSpatialTests {
    private func makeTexture(width: Int, height: Int, usage: MTLTextureUsage) -> MTLTexture {
        let device = MTLCreateSystemDefaultDevice()!
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = usage
        desc.storageMode = .private
        return device.makeTexture(descriptor: desc)!
    }

    private func fillInputTexture(_ texture: MTLTexture, device: MTLDevice) throws {
        // Clear the input texture by using it as a render target briefly.
        // This just exercises the upscale path; contents don't matter.
        let queue = device.makeCommandQueue()!
        let commandBuffer = queue.makeCommandBuffer()!
        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = texture
        passDesc.colorAttachments[0].loadAction = .clear
        passDesc.colorAttachments[0].storeAction = .store
        passDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc)!
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    @Test("Spatial upscaler recreates its scaler when output size changes")
    func testSpatialScalerRecreatesOnSizeChange() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard MTLFXSpatialScalerDescriptor.supportsDevice(device) else {
            return
        }

        let input = makeTexture(width: 64, height: 64, usage: [.renderTarget, .shaderRead])
        let output1 = makeTexture(width: 128, height: 128, usage: [.renderTarget, .shaderWrite, .shaderRead])
        let output2 = makeTexture(width: 256, height: 256, usage: [.renderTarget, .shaderWrite, .shaderRead])
        try fillInputTexture(input, device: device)

        // First render at 128x128 -> initial scaler created.
        let first = CommandBufferElement(completion: .commitAndWaitUntilCompleted) {
            MetalFXSpatial(inputTexture: input, outputTexture: output1)
        }
        try first.run()

        // Second render at 256x256 -> size-change branch recreates the scaler.
        let second = CommandBufferElement(completion: .commitAndWaitUntilCompleted) {
            MetalFXSpatial(inputTexture: input, outputTexture: output2)
        }
        try second.run()
    }

    @Test("Spatial upscaler encodes into command buffer")
    func testSpatialScalerEncodes() throws {
        let device = MTLCreateSystemDefaultDevice()!
        // Ensure MetalFX spatial scaling is supported.
        guard MTLFXSpatialScalerDescriptor.supportsDevice(device) else {
            return
        }

        let input = makeTexture(width: 64, height: 64, usage: [.renderTarget, .shaderRead])
        let output = makeTexture(width: 128, height: 128, usage: [.renderTarget, .shaderWrite, .shaderRead])

        try fillInputTexture(input, device: device)

        let element = CommandBufferElement(completion: .commitAndWaitUntilCompleted) {
            MetalFXSpatial(inputTexture: input, outputTexture: output)
        }
        try element.run()
    }
}
#endif
