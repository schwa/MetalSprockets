import CoreGraphics
import Metal
import MetalSprockets
import MetalSprocketsSupport
import simd

// Standard cube element for macOS/iOS window rendering.
// Demonstrates basic MetalSprockets usage with a single-view perspective camera.
struct ExampleCubeElement: Element {
    let shaderLibrary: ShaderLibrary
    let transform: float4x4
    let time: Float

    init(time: TimeInterval, viewportSize: CGSize) throws {
        self.shaderLibrary = try ShaderLibrary(bundle: .main)
        self.time = Float(time)
        
        // Build the model-view-projection matrix
        let modelMatrix = cubeRotationMatrix(time: time)
        let viewMatrix = float4x4.translation(0, 0, -8)  // Camera 8 units back
        
        let fov: Float = .pi / 4  // 45 degree field of view
        let aspect = viewportSize.height > 0 ? Float(viewportSize.width / viewportSize.height) : 1.0
        let projectionMatrix = float4x4.perspective(fovY: fov, aspect: aspect, near: 0.1, far: 100.0)
        
        // Combine into single MVP transform (note: reverse order of application)
        self.transform = projectionMatrix * viewMatrix * modelMatrix
    }

    var body: some Element {
        get throws {
            // RenderPass creates a render command encoder from the current render pass descriptor
            try RenderPass {
                // RenderPipeline binds shaders and creates the pipeline state
                try RenderPipeline(vertexShader: shaderLibrary.vertexMain, fragmentShader: shaderLibrary.fragmentMain) {
                    // Draw executes the actual rendering commands
                    Draw { encoder in
                        var transform = transform
                        encoder.setVertexBytes(&transform, length: MemoryLayout<float4x4>.stride, index: 1)
                        
                        // Pass time to fragment shader for edge animation
                        var time = time
                        encoder.setFragmentBytes(&time, length: MemoryLayout<Float>.stride, index: 0)
                        
                        var vertices = generateCubeVertices()
                        encoder.setVertexBytes(&vertices, length: MemoryLayout<Vertex>.stride * vertices.count, index: 0)
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
                    }
                }
                .vertexDescriptor(Vertex.descriptor)
                .depthCompare(function: .less, enabled: true)  // Standard depth test
            }
        }
    }
}
