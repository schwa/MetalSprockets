import MetalSprockets
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum RedTriangle {
    @MainActor
    static func main() throws -> MTLTexture {
        // Load shaders
        let library = try ShaderLibrary(bundle: .main)
        let vertexShader: VertexShader = try library.vertex_main
        let fragmentShader: FragmentShader = try library.fragment_main

        // Build render graph
        let root = try RenderPass {
            try RenderPipeline(
                vertexShader: vertexShader,
                fragmentShader: fragmentShader
            ) {
                // Draw the triangle
                Draw { encoder in
                    let vertices: [SIMD2<Float>] = [
                        [0, 0.75],
                        [-0.75, -0.75],
                        [0.75, -0.75]
                    ]
                    encoder.setVertexBytes(
                        vertices,
                        length: MemoryLayout<SIMD2<Float>>.stride * 3,
                        index: 0
                    )
                    encoder.drawPrimitives(
                        type: .triangle,
                        vertexStart: 0,
                        vertexCount: 3
                    )
                }
                // Hardcoded buffer indices are fragile — if the shader changes,
                // these can silently break. Binding by name (via shader reflection)
                // is safer but adds complexity in raw Metal.
                .parameter("color", value: SIMD4<Float>([1, 0, 0, 1]))
            }
            // Infer vertex layout from shader attributes
            .vertexDescriptor(vertexShader.inferredVertexDescriptor())
        }

        // Render offscreen
        let offscreenRenderer = try OffscreenRenderer(
            size: CGSize(width: 1_600, height: 1_200)
        )
        let rendering = try offscreenRenderer.render(root)

        // Export texture to PNG
        let image = try rendering.cgImage
        let url = URL(fileURLWithPath: "RedTriangle.png")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)

        return rendering.texture
    }
}
