import Metal
@testable import MetalSprockets
import Testing

/// Exercises the encoder-dispatch paths in `ParameterValue` — i.e. the
/// `setValue(_:index:...)` extensions that can't be hit through pure value
/// construction. We build a tiny real render/compute encoder pair and drive
/// every case through them. The goal is coverage of the switch arms, not
/// correctness of Metal behaviour.
@Suite("ParameterValue Encoder Dispatch Tests")
struct ParameterValueEncoderTests {
    @Test("MTLRenderCommandEncoder.setValue dispatches all ParameterValue cases")
    func renderEncoderDispatch() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        let commandBuffer = try #require(queue.makeCommandBuffer())

        // A minimal render pass just to get a live encoder.
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: 16, height: 16, mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = texture
        passDesc.colorAttachments[0].loadAction = .clear
        passDesc.colorAttachments[0].storeAction = .store
        let encoder = try #require(commandBuffer.makeRenderCommandEncoder(descriptor: passDesc))

        // .value
        encoder.setValue(ParameterValue<Float>.value(1.0), index: 0, functionType: .fragment)
        // .array
        encoder.setValue(ParameterValue<Float>.array([1, 2, 3, 4]), index: 1, functionType: .fragment)
        // .buffer
        let buffer = try #require(device.makeBuffer(length: 16))
        encoder.setValue(ParameterValue<Float>.buffer(buffer, 0), index: 2, functionType: .fragment)
        // .texture
        encoder.setValue(ParameterValue<Float>.texture(texture), index: 0, functionType: .fragment)
        // .samplerState
        let sampler = try #require(device.makeSamplerState(descriptor: MTLSamplerDescriptor()))
        encoder.setValue(ParameterValue<Float>.samplerState(sampler), index: 0, functionType: .fragment)

        // AnyParameterValue route
        let any = AnyParameterValue(ParameterValue<Float>.value(2.0))
        encoder.setValue(any, index: 3, functionType: .fragment)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    @Test("MTLComputeCommandEncoder.setValue dispatches all ParameterValue cases")
    func computeEncoderDispatch() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        let commandBuffer = try #require(queue.makeCommandBuffer())
        let encoder = try #require(commandBuffer.makeComputeCommandEncoder())

        // .value
        encoder.setValue(ParameterValue<Float>.value(1.0), index: 0)
        // .array
        encoder.setValue(ParameterValue<Float>.array([1, 2, 3, 4]), index: 1)
        // .buffer
        let buffer = try #require(device.makeBuffer(length: 16))
        encoder.setValue(ParameterValue<Float>.buffer(buffer, 0), index: 2)
        // .texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: 16, height: 16, mipmapped: false
        )
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        encoder.setValue(ParameterValue<Float>.texture(texture), index: 0)
        // .samplerState
        let sampler = try #require(device.makeSamplerState(descriptor: MTLSamplerDescriptor()))
        encoder.setValue(ParameterValue<Float>.samplerState(sampler), index: 0)

        // AnyParameterValue route
        let any = AnyParameterValue(ParameterValue<Float>.value(2.0))
        encoder.setValue(any, index: 3)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
