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
    let context: ImmersiveContext
    let shaderLibrary: ShaderLibrary

    init(context: ImmersiveContext) throws {
        self.context = context
        self.shaderLibrary = try ShaderLibrary(bundle: .main)
    }

    nonisolated var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: shaderLibrary.vertexImmersive, fragmentShader: shaderLibrary.fragmentMain) {
                Draw { encoder in
                    // Vertex amplification renders geometry twice (once per eye) in a single draw call.
                    var viewMappings = (0 ..< context.viewCount).map { MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: UInt32($0), renderTargetArrayIndexOffset: UInt32($0)) }
                    encoder.setVertexAmplificationCount(context.viewCount, viewMappings: &viewMappings)
                    encoder.setViewports(context.viewports)

                    // Position cube in world space: 2m in front, 1.5m up, scaled to 30cm
                    let modelMatrix = float4x4.translation(0, 1.5, -2) * cubeRotationMatrix(time: context.time) * float4x4.scale(0.3, 0.3, 0.3)

                    // ImmersiveContext provides head-tracked view/projection matrices for each eye
                    let leftView = context.viewMatrix(eye: 0)
                    let rightView = context.viewCount > 1 ? context.viewMatrix(eye: 1) : leftView
                    let leftProj = context.projectionMatrix(eye: 0)
                    let rightProj = context.viewCount > 1 ? context.projectionMatrix(eye: 1) : leftProj

                    var uniforms = Uniforms(modelMatrix: modelMatrix, cameras: (CameraUniforms(viewMatrix: leftView, projectionMatrix: leftProj), CameraUniforms(viewMatrix: rightView, projectionMatrix: rightProj)))
                    encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

                    var time = Float(context.time)
                    encoder.setFragmentBytes(&time, length: MemoryLayout<Float>.stride, index: 0)

                    var vertices = generateCubeVertices()
                    encoder.setVertexBytes(&vertices, length: MemoryLayout<Vertex>.stride * vertices.count, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
                }
            }
            .vertexDescriptor(Vertex.descriptor)
            .depthCompare(function: .greater, enabled: true)  // visionOS uses reverse-Z depth buffer
            .renderPipelineDescriptorModifier { descriptor in
                descriptor.maxVertexAmplificationCount = context.viewCount
                descriptor.colorAttachments[0].pixelFormat = context.drawable.colorTextures[0].pixelFormat
                descriptor.depthAttachmentPixelFormat = context.drawable.depthTextures[0].pixelFormat
            }
        }
    }
}
#endif
