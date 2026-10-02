import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Metal
import MetalSprocketsSupport
import MetalSupport

public final class OffscreenVideoRenderer {
    public let size: CGSize
    public let frameRate: Double
    public let outputURL: URL
    public let pixelFormat: MTLPixelFormat
    public let videoCodec: AVVideoCodecType
    let device: MTLDevice
    let commandQueue: any MTL4CommandQueue
    let runner: Runner
    let writer: VideoFrameWriter
    let colorTexture: MTLTexture
    let depthTexture: MTLTexture
    let renderPassDescriptor: MTL4RenderPassDescriptor
    private var isCancelled = false

    var writtenFrameCount: Int { writer.frameNumber }
    var residentAllocationCount: Int { runner.context.residentAllocationCount }

    public convenience init(size: CGSize, frameRate: Double = 30.0, outputURL: URL, pixelFormat: MTLPixelFormat = .bgra8Unorm, videoCodec: AVVideoCodecType = .h264, shaderLogging: ShaderLogging = .processDefault) throws {
        try self.init(size: size, frameRate: frameRate, outputURL: outputURL, pixelFormat: pixelFormat, videoCodec: videoCodec, shaderLogging: shaderLogging, waitUntilReady: nil)
    }

    /// Designated init. `waitUntilReady` is the back-pressure strategy; when
    /// `nil`, the default KVO-based implementation is used against the
    /// writer's own `AVAssetWriterInput`.
    internal init(size: CGSize, frameRate: Double = 30.0, outputURL: URL, pixelFormat: MTLPixelFormat = .bgra8Unorm, videoCodec: AVVideoCodecType = .h264, shaderLogging: ShaderLogging = .processDefault, waitUntilReady: (() async -> Void)?) throws {
        self.size = size
        self.frameRate = frameRate
        self.outputURL = outputURL
        self.pixelFormat = pixelFormat
        self.videoCodec = videoCodec

        // The writer reads BGRA bytes directly, so the color attachment must match that layout.
        guard pixelFormat == .bgra8Unorm || pixelFormat == .bgra8Unorm_srgb else {
            throw MetalSprocketsError.configurationError("Video export requires a BGRA8 pixel format, not \(pixelFormat).")
        }
        runner = try Runner(shaderLogging: shaderLogging)
        device = runner.device
        commandQueue = runner.commandQueue

        let colorTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        colorTextureDescriptor.usage = [.renderTarget, .shaderRead]
        colorTexture = try device.makeTexture(descriptor: colorTextureDescriptor).orThrow(.resourceCreationFailure("Failed to create video color texture"))
        colorTexture.label = "Video Color Texture"

        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        depthTextureDescriptor.usage = [.renderTarget]
        depthTexture = try device.makeTexture(descriptor: depthTextureDescriptor).orThrow(.resourceCreationFailure("Failed to create video depth texture"))
        depthTexture.label = "Video Depth Texture"
        let resources = try ResourceCollection(device: device)
        try resources.register(colorTexture)
        try resources.register(depthTexture)
        runner.residency.collections = [resources]

        renderPassDescriptor = MTL4RenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = colorTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 1
        renderPassDescriptor.depthAttachment.storeAction = .dontCare

        writer = try VideoFrameWriter(size: size, frameRate: frameRate, outputURL: outputURL, videoCodec: videoCodec, waitUntilReady: waitUntilReady)
    }

    /// Renders one frame and appends it. An encoding error throws before anything is appended.
    nonisolated(nonsending) public func render<Content>(_ element: Content) async throws where Content: Element {
        guard !isCancelled else {
            throw MetalSprocketsError.validationError("The video export was cancelled.")
        }
        let wrapped = element
            .renderPassDescriptor(renderPassDescriptor)
            .drawableSize(size)

        // TODO: #220 Setup should be smart enough to skip elements that are already configured - avoid redundant setup every frame
        // Runner.run commits and waits, so the texture is complete before the writer reads it.
        try runner.run(wrapped)
        try await writer.append(colorTexture)
    }

    nonisolated(nonsending) public func finalize() async throws {
        try await writer.finalize()
    }

    func cancel() {
        isCancelled = true
        writer.cancel()
    }
}
