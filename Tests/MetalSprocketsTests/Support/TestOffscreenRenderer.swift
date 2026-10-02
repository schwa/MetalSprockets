import CoreGraphics
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport

/// Async offscreen renderer for tests: renders a pass body into owned color and depth attachments, and exposes the
/// underlying runner for engine assertions.
internal final class TestOffscreenRenderer {
    struct Rendering {
        let texture: any MTLTexture
        let gpuTime: TimeInterval?

        var cgImage: CGImage {
            get throws { try texture.toCGImage() }
        }
    }

    let runner: FrameRunner
    private(set) var size: CGSize
    let pixelFormat: MTLPixelFormat
    /// Samples per pixel. Above 1, rendering targets multisample attachments that resolve into `colorTexture`.
    let sampleCount: Int
    private(set) var colorTexture: any MTLTexture
    private(set) var depthTexture: any MTLTexture
    private var descriptor: MTL4RenderPassDescriptor

    init(size: CGSize, device: (any MTLDevice)? = nil, pixelFormat: MTLPixelFormat = .bgra8Unorm_srgb, sampleCount: Int = 1) throws {
        runner = try FrameRunner(device: device)
        guard sampleCount >= 1, runner.device.supportsTextureSampleCount(sampleCount) else {
            throw MetalSprocketsError.deviceCababilityFailure("Device '\(runner.device.name)' does not support \(sampleCount) samples per pixel.")
        }
        self.size = size
        self.pixelFormat = pixelFormat
        self.sampleCount = sampleCount
        (colorTexture, depthTexture, descriptor) = try Self.makeAttachments(size: size, pixelFormat: pixelFormat, sampleCount: sampleCount, device: runner.device)
    }

    /// Replaces the attachments. Earlier renderings keep their own textures alive.
    func resize(to size: CGSize) throws {
        (colorTexture, depthTexture, descriptor) = try Self.makeAttachments(size: size, pixelFormat: pixelFormat, sampleCount: sampleCount, device: runner.device)
        self.size = size
    }

    /// Renders `content` inside a render pass targeting the attachments. Readback is valid once this returns.
    nonisolated(nonsending) func render(_ content: some Element) async throws -> Rendering {
        let texture = colorTexture
        let result = try await runner.run(try RenderPass { content }.renderPassDescriptor(descriptor))
        guard result.outcome == .completed else {
            throw MetalSprocketsError.validationError("Metal 4 offscreen render did not complete: \(result.outcome)")
        }
        return Rendering(texture: texture, gpuTime: result.gpuDuration)
    }

    private static func makeAttachments(size: CGSize, pixelFormat: MTLPixelFormat, sampleCount: Int, device: any MTLDevice) throws -> (any MTLTexture, any MTLTexture, MTL4RenderPassDescriptor) {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0 else {
            throw MetalSprocketsError.configurationError("Offscreen render size must be positive, not \(size).")
        }
        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        colorDescriptor.usage = [.renderTarget, .shaderRead]
        let color = try device.makeTexture(descriptor: colorDescriptor).orThrow(.resourceCreationFailure("Failed to create color texture"))
        color.label = "Color Texture"
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
        depthDescriptor.usage = .renderTarget
        depthDescriptor.storageMode = .private
        if sampleCount > 1 {
            depthDescriptor.textureType = .type2DMultisample
            depthDescriptor.sampleCount = sampleCount
        }
        let depth = try device.makeTexture(descriptor: depthDescriptor).orThrow(.resourceCreationFailure("Failed to create depth texture"))
        depth.label = "Depth Texture"
        let descriptor = MTL4RenderPassDescriptor()
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        if sampleCount > 1 {
            let multisampleDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
            multisampleDescriptor.textureType = .type2DMultisample
            multisampleDescriptor.sampleCount = sampleCount
            multisampleDescriptor.usage = .renderTarget
            multisampleDescriptor.storageMode = .private
            let multisample = try device.makeTexture(descriptor: multisampleDescriptor).orThrow(.resourceCreationFailure("Failed to create multisample color texture"))
            multisample.label = "Multisample Color Texture"
            descriptor.colorAttachments[0].texture = multisample
            descriptor.colorAttachments[0].resolveTexture = color
            descriptor.colorAttachments[0].storeAction = .multisampleResolve
        } else {
            descriptor.colorAttachments[0].texture = color
            descriptor.colorAttachments[0].storeAction = .store
        }
        descriptor.depthAttachment.texture = depth
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.clearDepth = 1
        descriptor.depthAttachment.storeAction = .dontCare
        return (color, depth, descriptor)
    }
}
