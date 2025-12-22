#if os(iOS)
import ARKit
import CoreGraphics
import Metal
import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import simd

/// ARKit cube element that renders the spinning cube in AR space.
/// Uses the ARKit camera as background and positions the cube 2m in front of the camera.
struct ARKitCubeElement: Element {
    let shaderLibrary: ShaderLibrary
    let time: Float
    let textureY: MTLTexture
    let textureCbCr: MTLTexture
    let textureCoordinates: [SIMD2<Float>]
    let projectionMatrix: simd_float4x4
    let viewMatrix: simd_float4x4

    init(
        time: TimeInterval,
        textureY: MTLTexture,
        textureCbCr: MTLTexture,
        textureCoordinates: [SIMD2<Float>],
        projectionMatrix: simd_float4x4,
        viewMatrix: simd_float4x4
    ) throws {
        self.shaderLibrary = try ShaderLibrary(bundle: .main)
        self.time = Float(time)
        self.textureY = textureY
        self.textureCbCr = textureCbCr
        self.textureCoordinates = textureCoordinates
        self.projectionMatrix = projectionMatrix
        self.viewMatrix = viewMatrix
    }

    var body: some Element {
        get throws {
            // Single RenderPass for both camera background and cube
            try RenderPass {
                // First, render the camera background
                YCbCrBillboardRenderPass(
                    textureY: textureY,
                    textureCbCr: textureCbCr,
                    textureCoordinates: textureCoordinates
                )

                // Render the spinning cube in AR space
                try RenderPipeline(vertexShader: shaderLibrary.vertexMain, fragmentShader: shaderLibrary.fragmentMain) {
                    Draw { encoder in
                        // Position cube 2 meters in front of camera, with rotation and scale
                        let modelMatrix = float4x4.translation(0, 0, -2)
                            * cubeRotationMatrix(time: TimeInterval(time))
                            * float4x4.scale(0.15, 0.15, 0.15)
                        var transform = projectionMatrix * viewMatrix * modelMatrix
                        encoder.setVertexBytes(&transform, length: MemoryLayout<float4x4>.stride, index: 1)
                        var time = time
                        encoder.setFragmentBytes(&time, length: MemoryLayout<Float>.stride, index: 0)
                        var vertices = generateCubeVertices()
                        encoder.setVertexBytes(&vertices, length: MemoryLayout<Vertex>.stride * vertices.count, index: 0)
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
                    }
                }
                .vertexDescriptor(Vertex.descriptor)
                .depthCompare(function: .less, enabled: true)
            }
        }
    }
}
#endif
