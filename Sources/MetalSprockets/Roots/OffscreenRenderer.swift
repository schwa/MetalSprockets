import CoreGraphics
import Metal
import MetalSprocketsSupport
import MetalSupport

// MARK: - OffscreenRenderer

/// Renders MetalSprockets elements to an offscreen texture.
///
/// Use `OffscreenRenderer` for headless rendering, image generation, or render-to-texture workflows without a display.
///
/// ```swift
/// let renderer = try OffscreenRenderer(size: CGSize(width: 1920, height: 1080))
///
/// let rendering = try renderer.render(
///     RenderPass {
///         RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///             Draw { encoder in
///                 // Draw commands
///             }
///         }
///     }
/// )
///
/// // Access the rendered image
/// let image = try rendering.cgImage
/// ```
///
/// Content supplies its own ``RenderPass``; the renderer provides its ``renderPassDescriptor`` through the environment.
/// ``render(_:)`` returns after the GPU finishes, so the texture is safe to read.
public struct OffscreenRenderer {
    public var device: MTLDevice
    public var size: CGSize
    public var colorTexture: MTLTexture {
        willSet {
            if newValue !== colorTexture {
                ownedResources?.unregister(colorTexture)
            }
        }
    }
    public var depthTexture: MTLTexture {
        willSet {
            if newValue !== depthTexture {
                ownedResources?.unregister(depthTexture)
            }
        }
    }
    public var renderPassDescriptor: MTL4RenderPassDescriptor
    public var commandQueue: any MTL4CommandQueue
    private let runner: Runner
    private var ownedResources: ResourceCollection?

    public init(size: CGSize, colorTexture: MTLTexture, depthTexture: MTLTexture, shaderLogging: ShaderLogging = .processDefault) throws {
        self.device = colorTexture.device
        self.size = size
        self.colorTexture = colorTexture
        self.depthTexture = depthTexture
        let renderPassDescriptor = MTL4RenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = colorTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 1
        renderPassDescriptor.depthAttachment.storeAction = .store // TODO: #25 This is hardcoded. Should usually be .dontCare but we need to read back in some examples.
        self.renderPassDescriptor = renderPassDescriptor
        self.runner = try Runner(device: device, shaderLogging: shaderLogging)
        self.commandQueue = runner.commandQueue
    }

    public init(
        size: CGSize,
        device: MTLDevice? = nil,
        colorUsage: MTLTextureUsage = [.renderTarget, .shaderRead],
        depthUsage: MTLTextureUsage = [.renderTarget],
        shaderLogging: ShaderLogging = .processDefault
    ) throws {
        let device = device ?? _MTLCreateSystemDefaultDevice()
        let colorTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: Int(size.width), height: Int(size.height), mipmapped: false)
        colorTextureDescriptor.usage = colorUsage
        let colorTexture = try device.makeTexture(descriptor: colorTextureDescriptor).orThrow(.resourceCreationFailure("Failed to create color texture"))
        colorTexture.label = "Color Texture"
        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(size.width), height: Int(size.height), mipmapped: false)
        depthTextureDescriptor.usage = depthUsage
        let depthTexture = try device.makeTexture(descriptor: depthTextureDescriptor).orThrow(.resourceCreationFailure("Failed to create depth texture"))
        depthTexture.label = "Depth Texture"
        try self.init(size: size, colorTexture: colorTexture, depthTexture: depthTexture, shaderLogging: shaderLogging)
        let resources = try ResourceCollection(device: device)
        try resources.register(colorTexture)
        try resources.register(depthTexture)
        ownedResources = resources
        runner.residency.collections = [resources]
    }

    public struct Rendering {
        public var texture: MTLTexture
        /// GPU time for the whole submission, or `nil` when Metal reported no valid timing.
        public var gpuTime: TimeInterval?
    }
}

public extension OffscreenRenderer {
    /// Renders `content` and waits for the GPU. Earlier renderings keep their textures; reading them is safe.
    func render<Content>(_ content: Content) throws -> Rendering where Content: Element {
        let wrapped = content
            .renderPassDescriptor(renderPassDescriptor)
            .drawableSize(size)
        let submission = try runner.submit(wrapped)
        let result = try runner.context.waitForResult(submission)
        try runner.context.retireCompletedSubmissions()
        guard result.outcome == .completed else {
            throw MetalSprocketsError.validationError("Offscreen render did not complete: \(result.outcome)")
        }
        return .init(texture: colorTexture, gpuTime: result.gpuDuration)
    }
}

public extension OffscreenRenderer.Rendering {
    var cgImage: CGImage {
        get throws {
            try texture.toCGImage()
        }
    }
}
