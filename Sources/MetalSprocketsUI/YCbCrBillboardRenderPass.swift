import Metal
import MetalSprockets

// MARK: - YCbCrBillboardRenderPass

/// Renders YCbCr video textures as a full-screen billboard.
///
/// Use this element to display camera feeds or video frames that use YCbCr color encoding (common in ARKit,
/// AVFoundation, and video codecs). It converts BT.601 YCbCr to RGB and draws a full-screen quad with no depth test or
/// depth write, so it works as a background layer.
///
/// ## ARKit Camera Background
///
/// ```swift
/// RenderPass {
///     if frameData.isReady {
///         try YCbCrBillboardRenderPass(frameData: frameData)
///     }
///     // Render 3D content on top...
/// }
/// ```
///
/// Camera textures are valid only while their `CVMetalTexture`s live. Pass those as `owners` (the `frameData`
/// initializer does this), so they stay alive until the GPU has finished reading, not just until the next camera
/// frame arrives.
///
/// ## Texture Coordinates
///
/// The default texture coordinates assume the texture is oriented correctly. For camera feeds, apply the display
/// transform to match screen orientation:
///
/// ```swift
/// let transform = frame.displayTransform(for: orientation, viewportSize: size)
/// let texCoords = baseCoords.map { $0.applying(transform) }
/// ```
public struct YCbCrBillboardRenderPass: Element {
    let textureY: MTLTexture
    let textureCbCr: MTLTexture
    let textureCoordinates: [SIMD2<Float>]
    let owners: [AnyObject]

    /// Creates a YCbCr billboard.
    ///
    /// - Parameters:
    ///   - textureY: The luma plane (`r8Unorm`).
    ///   - textureCbCr: The chroma plane (`rg8Unorm`).
    ///   - textureCoordinates: Bottom-left, bottom-right, top-left, top-right texture coordinates.
    ///   - owners: Objects that must outlive GPU use of the textures, such as `CVMetalTexture`s.
    public init(textureY: MTLTexture, textureCbCr: MTLTexture, textureCoordinates: [SIMD2<Float>] = [[0, 1], [1, 1], [0, 0], [1, 0]], owners: [AnyObject] = []) {
        self.textureY = textureY
        self.textureCbCr = textureCbCr
        self.textureCoordinates = textureCoordinates
        self.owners = owners
    }

    #if os(iOS)
    /// Creates a billboard for an ARKit frame, keeping its `CVMetalTexture`s alive until the GPU is done.
    public init(frameData: ARFrameData) throws {
        let textureY = try frameData.textureY.orThrow(.validationError("ARFrameData has no Y texture"))
        let textureCbCr = try frameData.textureCbCr.orThrow(.validationError("ARFrameData has no CbCr texture"))
        self.init(textureY: textureY, textureCbCr: textureCbCr, textureCoordinates: frameData.textureCoordinates, owners: frameData.textureOwners)
    }
    #endif

    public var body: some Element {
        YCbCrBillboard(textureY: textureY, textureCbCr: textureCbCr, textureCoordinates: textureCoordinates, owners: owners)
    }
}
