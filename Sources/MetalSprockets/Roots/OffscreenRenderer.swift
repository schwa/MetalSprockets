import CoreGraphics
import Metal
import MetalSprocketsSupport

// MARK: - OffscreenRenderer

/// Renders MetalSprockets elements to an offscreen texture.
///
/// Use `OffscreenRenderer` for headless rendering, image generation, or
/// render-to-texture workflows without a display.
///
/// ## Overview
///
/// Create a renderer and render elements to a texture:
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
/// let cgImage = try rendering.cgImage
/// ```
///
/// ## Custom Textures
///
/// Provide your own textures for more control:
///
/// ```swift
/// let renderer = try OffscreenRenderer(
///     size: size,
///     colorTexture: myColorTexture,
///     depthTexture: myDepthTexture
/// )
/// ```
///
/// ## Topics
///
/// ### Related Types
/// - ``OffscreenVideoRenderer``
public struct OffscreenRenderer {
    public var device: MTLDevice
    public var size: CGSize
    public var colorTexture: MTLTexture
    public var depthTexture: MTLTexture
    public var renderPassDescriptor: MTLRenderPassDescriptor
    public var commandQueue: MTLCommandQueue

    /// Creates an offscreen renderer with custom textures.
    ///
    /// - Parameters:
    ///   - size: The size of the rendering area.
    ///   - colorTexture: The texture to render color output to.
    ///   - depthTexture: The texture to use for depth testing.
    public init(size: CGSize, colorTexture: MTLTexture, depthTexture: MTLTexture) throws {
        self.device = colorTexture.device
        self.size = size
        self.colorTexture = colorTexture
        self.depthTexture = depthTexture

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = colorTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 1
        renderPassDescriptor.depthAttachment.storeAction = .store // TODO: #25 This is hardcoded. Should usually be .dontCare but we need to read back in some examples.
        self.renderPassDescriptor = renderPassDescriptor

        commandQueue = try device._makeCommandQueue()
    }

    /// Creates an offscreen renderer with automatically created textures.
    ///
    /// Creates color (BGRA8Unorm_sRGB) and depth (Depth32Float) textures
    /// at the specified size.
    ///
    /// - Parameter size: The size of the rendering area in pixels.
    ///
    /// - Note: TODO #20 - Most of this belongs on a RenderSession type API. We should be able to render multiple times with the same setup.
    public init(size: CGSize) throws {
        let device = _MTLCreateSystemDefaultDevice()
        let colorTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: Int(size.width), height: Int(size.height), mipmapped: false)
        colorTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite] // TODO: #25 this is all hardcoded :-(
        let colorTexture = try device.makeTexture(descriptor: colorTextureDescriptor).orThrow(.resourceCreationFailure("Failed to create color texture"))
        colorTexture.label = "Color Texture"

        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(size.width), height: Int(size.height), mipmapped: false)
        depthTextureDescriptor.usage = [.renderTarget, .shaderRead] // TODO: #25 this is all hardcoded :-(
        let depthTexture = try device.makeTexture(descriptor: depthTextureDescriptor).orThrow(.resourceCreationFailure("Failed to create depth texture"))
        depthTexture.label = "Depth Texture"

        try self.init(size: size, colorTexture: colorTexture, depthTexture: depthTexture)
    }

    /// The result of an offscreen render operation.
    public struct Rendering {
        /// The texture containing the rendered output.
        public var texture: MTLTexture
    }
}

public extension OffscreenRenderer {
    /// Renders the specified element and returns the result.
    ///
    /// - Parameter content: The element to render.
    /// - Returns: A ``Rendering`` containing the output texture.
    /// - Throws: Any errors that occur during rendering.
    func render<Content>(_ content: Content) throws -> Rendering where Content: Element {
        // Use the device and commandQueue from init, not new ones
        // Creating a new device here would cause a device mismatch with the textures
        let content = CommandBufferElement(completion: .commitAndWaitUntilCompleted) {
            content
        }
        .environment(\.device, device)
        .environment(\.commandQueue, commandQueue)
        .environment(\.renderPassDescriptor, renderPassDescriptor)
        .environment(\.drawableSize, size)
        let system = System()
        try system.update(root: content)
        try system.withCurrentSystem {
            try system.processSetup()
            try system.processWorkload()
        }
        return .init(texture: colorTexture)
    }
}

public extension OffscreenRenderer.Rendering {
    /// Converts the rendered texture to a Core Graphics image.
    ///
    /// Use this to save the rendering to disk or display in UIKit/AppKit.
    ///
    /// ```swift
    /// let rendering = try renderer.render(myElement)
    /// let image = try rendering.cgImage
    /// ```
    var cgImage: CGImage {
        get throws {
            try texture.toCGImage()
        }
    }
}
