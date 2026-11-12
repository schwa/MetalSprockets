#if os(visionOS)
import CompositorServices
import Metal
import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import simd

// Swift counterparts of CameraUniforms and Uniforms in Shaders.metal.
struct CameraUniforms {
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
}

struct Uniforms {
    var modelMatrix: float4x4
    var cameras: (CameraUniforms, CameraUniforms)
}

// Immersive cube element for visionOS mixed reality rendering.
// Demonstrates stereo rendering with vertex amplification for efficient dual-eye output.
struct ImmersiveCubeContent: Element, @unchecked Sendable {
    nonisolated let context: ImmersiveContext
    nonisolated(unsafe) let shaderLibrary: ShaderLibrary

    init(context: ImmersiveContext) throws {
        self.context = context
        self.shaderLibrary = try ShaderLibrary(bundle: .main)
    }

    nonisolated var body: some Element {
        get throws {
            // Position cube in world space: 2m in front, 1.5m up, scaled to 30cm
            let modelMatrix = float4x4.translation(0, 1.5, -1.5) * cubeRotationMatrix(time: context.time) * float4x4.scale(0.3, 0.3, 0.3)

            // ImmersiveContext provides head-tracked view/projection matrices for each eye
            let views = context.stereoViews
            let cameras = zip(views.viewMatrices, views.projectionMatrices).map { CameraUniforms(viewMatrix: $0, projectionMatrix: $1) }
            let uniforms = Uniforms(modelMatrix: modelMatrix, cameras: (cameras[0], cameras[views.isStereo ? 1 : 0]))

            return try RenderPipeline(vertexShader: shaderLibrary.vertexImmersive, fragmentShader: shaderLibrary.fragmentMain) {
                Draw { encoder in
                    // Vertex amplification renders geometry twice (once per eye) in a single draw call.
                    views.configure(encoder)
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: cubeVertexCount)
                }
                .vertexValues(generateCubeVertices(), index: 0)
                // Bind shader uniforms by name via reflection — no hardcoded buffer indices.
                .parameter("uniforms", value: uniforms)
                .parameter("time", value: Float(context.time))
            }
            .vertexDescriptor(Vertex.descriptor)
            .depthCompare(function: .greater, writes: true)  // visionOS uses reverse-Z depth buffer
            .vertexAmplification(count: views.count)
            .renderPipelineDescriptorTransformer { descriptor in
                // Attachment formats come from the render pass; Metal 4 pipeline descriptors have no depth format.
                descriptor.colorAttachments[0].pixelFormat = context.drawable.colorTextures[0].pixelFormat
            }
        }
    }
}
#endif
