import Metal
import simd
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum TraditionalRedTriangle {
    static func main() throws -> MTLTexture {
        let pixelFormat = MTLPixelFormat.bgra8Unorm
        let device = MTLCreateSystemDefaultDevice()!

        // Load shaders
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertex_main")!
        let fragmentFunction = library.makeFunction(name: "fragment_main")!

        // Create vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.size

        // Create pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat

        // Create pipeline state
        let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        // Create render target texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: 1_600,
            height: 1_200,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget]
        let texture = device.makeTexture(descriptor: textureDescriptor)!

        // Create command queue and buffer
        let commandQueue = device.makeCommandQueue()!
        let commandBuffer = commandQueue.makeCommandBuffer()!

        // Configure render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0, green: 0, blue: 0, alpha: 1
        )
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        // Create encoder and render
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        )!
        renderEncoder.setRenderPipelineState(pipelineState)

        // Set vertex data
        // Hardcoded buffer indices are fragile — if the shader changes,
        // these can silently break. Binding by name (via shader reflection)
        // is safer but adds complexity in raw Metal.
        let vertices: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
        renderEncoder.setVertexBytes(
            vertices,
            length: MemoryLayout<SIMD2<Float>>.stride * 3,
            index: 0
        )

        // Set fragment uniform
        var color: SIMD4<Float> = [1, 0, 0, 1]
        renderEncoder.setFragmentBytes(
            &color,
            length: MemoryLayout<SIMD4<Float>>.stride,
            index: 0
        )

        // Draw and finish
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Export texture to PNG
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(origin: .init(), size: .init(width: width, height: height, depth: 1)),
            mipmapLevel: 0
        )

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )!
        let image = context.makeImage()!

        let url = URL(fileURLWithPath: "RedTriangle.png")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)

        return texture
    }
}
