import Metal
@testable import MetalSprockets
import Testing

@MainActor
@Suite("Render attachment formats environment")
struct RenderAttachmentFormatsTests {
    struct Leaf: Element, BodylessElement {
        typealias Body = Never
        var formats: RenderAttachmentFormats?
    }

    struct Probe: Element {
        @MSEnvironment(\.renderAttachmentFormats)
        var formats

        var body: some Element {
            Leaf(formats: formats)
        }
    }

    private func capturedFormats(_ element: some Element) throws -> RenderAttachmentFormats {
        let system = System()
        try system.update(root: element)
        let leaf = try #require(system.nodes.values.compactMap { $0.element as? Leaf }.first)
        return try #require(leaf.formats)
    }

    private static func makeTexture(device: MTLDevice, pixelFormat: MTLPixelFormat, sampleCount: Int = 1) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = sampleCount > 1 ? .type2DMultisample : .type2D
        descriptor.pixelFormat = pixelFormat
        descriptor.width = 16
        descriptor.height = 16
        descriptor.sampleCount = sampleCount
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        return try #require(device.makeTexture(descriptor: descriptor))
    }

    private static func makeDescriptor(device: MTLDevice) throws -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = try makeTexture(device: device, pixelFormat: .bgra8Unorm)
        descriptor.depthAttachment.texture = try makeTexture(device: device, pixelFormat: .depth32Float)
        return descriptor
    }

    @Test func `the render pass descriptor modifier publishes formats`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let descriptor = try Self.makeDescriptor(device: device)
        let formats = try capturedFormats(Probe().renderPassDescriptor(descriptor))
        #expect(formats.colorPixelFormat(at: 0) == .bgra8Unorm)
        #expect(formats.depthPixelFormat == .depth32Float)
        #expect(formats.stencilPixelFormat == .invalid)
        #expect(formats.rasterSampleCount == 1)
    }

    @Test func `MSAA republishes the multisample formats`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let descriptor = try Self.makeDescriptor(device: device)
        let formats = try capturedFormats(
            Probe()
                .msaa(sampleCount: 4)
                .renderPassDescriptor(descriptor)
                .device(device)
        )
        #expect(formats.colorPixelFormat(at: 0) == .bgra8Unorm)
        #expect(formats.depthPixelFormat == .depth32Float)
        #expect(formats.rasterSampleCount == 4)
    }

    @Test func `the descriptor modifier recomputes formats after mutation`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let descriptor = try Self.makeDescriptor(device: device)
        let stencilTexture = try Self.makeTexture(device: device, pixelFormat: .stencil8)
        let formats = try capturedFormats(
            Probe()
                .renderPassDescriptorModifier { $0.stencilAttachment.texture = stencilTexture }
                .renderPassDescriptor(descriptor)
                .device(device)
        )
        #expect(formats.stencilPixelFormat == .stencil8)
    }

    @Test func `formats derived from a descriptor match its attachment textures`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let descriptor = try Self.makeDescriptor(device: device)
        let formats = RenderAttachmentFormats(descriptor)
        #expect(formats.colorPixelFormats == [.bgra8Unorm])
        #expect(formats.colorPixelFormat(at: 3) == .invalid)
    }
}
