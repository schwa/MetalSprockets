@preconcurrency import Metal
import MetalSprockets

// MARK: - YCbCrBillboardRenderPass

/// Renders YCbCr video textures as a full-screen billboard.
///
/// Use this element to display camera feeds or video frames that use YCbCr
/// color encoding (common in ARKit, AVFoundation, and video codecs).
///
/// ## Overview
///
/// YCbCr separates luminance (Y) from chrominance (CbCr), which is more
/// efficient for video compression. This element converts YCbCr to RGB
/// and renders it as a full-screen quad.
///
/// ## ARKit Camera Background
///
/// Display ARKit camera feed as a background layer:
///
/// ```swift
/// RenderPass {
///     if let textureY = frameData.textureY,
///        let textureCbCr = frameData.textureCbCr {
///         YCbCrBillboardRenderPass(
///             textureY: textureY,
///             textureCbCr: textureCbCr,
///             textureCoordinates: frameData.textureCoordinates
///         )
///     }
///     // Render 3D content on top...
/// }
/// ```
///
/// ## Texture Coordinates
///
/// The default texture coordinates assume the texture is oriented correctly.
/// For camera feeds, apply the display transform to match screen orientation:
///
/// ```swift
/// let transform = frame.displayTransform(for: orientation, viewportSize: size)
/// let texCoords = baseCoords.map { $0.applying(transform) }
/// ```
///
/// ## Topics
///
/// ### Related Types
/// - ``ARFrameData``
public struct YCbCrBillboardRenderPass: Element {
    @MSState
    private var vertexShader = ShaderLibrary.metalSprocketsUI
        .namespaced("YCbCrBillboard")
        .requiredFunction(named: "vertex_main", type: VertexShader.self)

    @MSState
    private var fragmentShader = ShaderLibrary.metalSprocketsUI
        .namespaced("YCbCrBillboard")
        .requiredFunction(named: "fragment_main", type: FragmentShader.self)

    let textureY: MTLTexture
    let textureCbCr: MTLTexture
    let textureCoordinates: [SIMD2<Float>]

    /// Creates a YCbCr billboard render pass.
    /// - Parameters:
    ///   - textureY: The Y (luminance) texture in r8Unorm format.
    ///   - textureCbCr: The CbCr (chrominance) texture in rg8Unorm format.
    ///   - textureCoordinates: The texture coordinates for the 4 corners of the quad
    ///     (bottom-left, bottom-right, top-left, top-right). Apply display transform here.
    public init(textureY: MTLTexture, textureCbCr: MTLTexture, textureCoordinates: [SIMD2<Float>]) {
        self.textureY = textureY
        self.textureCbCr = textureCbCr
        self.textureCoordinates = textureCoordinates
    }

    /// Creates a YCbCr billboard render pass with default texture coordinates.
    /// - Parameters:
    ///   - textureY: The Y (luminance) texture in r8Unorm format.
    ///   - textureCbCr: The CbCr (chrominance) texture in rg8Unorm format.
    public init(textureY: MTLTexture, textureCbCr: MTLTexture) {
        self.init(
            textureY: textureY,
            textureCbCr: textureCbCr,
            textureCoordinates: [
                [0, 1],  // bottom-left
                [1, 1],  // bottom-right
                [0, 0],  // top-left
                [1, 0]   // top-right
            ]
        )
    }

    // Vertex descriptor: attribute 0 in buffer 0, attribute 1 in buffer 1
    nonisolated(unsafe) private static let vertexDescriptor: MTLVertexDescriptor = {
        let desc = MTLVertexDescriptor()
        // Position: float2 in buffer 0
        desc.attributes[0].format = .float2
        desc.attributes[0].offset = 0
        desc.attributes[0].bufferIndex = 0
        desc.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride
        desc.layouts[0].stepFunction = .perVertex
        // Texture coordinate: float2 in buffer 1
        desc.attributes[1].format = .float2
        desc.attributes[1].offset = 0
        desc.attributes[1].bufferIndex = 1
        desc.layouts[1].stride = MemoryLayout<SIMD2<Float>>.stride
        desc.layouts[1].stepFunction = .perVertex
        return desc
    }()

    public var body: some Element {
        get throws {
            // Clip-space quad positions (full screen)
            let positions: [SIMD2<Float>] = [
                [-1, -1],  // bottom-left
                [+1, -1],  // bottom-right
                [-1, +1],  // top-left
                [+1, +1]   // top-right
            ]

            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    // Set vertex data
                    var positions = positions
                    encoder.setVertexBytes(&positions, length: MemoryLayout<SIMD2<Float>>.stride * positions.count, index: 0)

                    var texCoords = textureCoordinates
                    encoder.setVertexBytes(&texCoords, length: MemoryLayout<SIMD2<Float>>.stride * texCoords.count, index: 1)

                    // Set textures
                    encoder.setFragmentTexture(textureY, index: 0)
                    encoder.setFragmentTexture(textureCbCr, index: 1)

                    // Set sampler
                    let samplerDescriptor = MTLSamplerDescriptor()
                    samplerDescriptor.minFilter = .linear
                    samplerDescriptor.magFilter = .linear
                    let sampler = encoder.device.makeSamplerState(descriptor: samplerDescriptor)
                    encoder.setFragmentSamplerState(sampler, index: 0)

                    // Draw quad as triangle strip
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                }
            }
            .vertexDescriptor(Self.vertexDescriptor)
            .depthCompare(function: .always, enabled: false)  // Background layer, no depth test
        }
    }
}
