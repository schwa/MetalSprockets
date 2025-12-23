# Traditional Metal vs MetalSprockets

See how MetalSprockets simplifies Metal rendering with a side-by-side comparison.

## Overview

This article compares rendering a simple red triangle using traditional Metal code versus MetalSprockets. The contrast highlights how MetalSprockets reduces boilerplate while maintaining full control over the rendering pipeline.

## Traditional Metal Approach

Here's the traditional way to render a red triangle with Metal—approximately 100 lines of setup code:

```swift
import Metal
import simd

enum TraditionalRedTriangle {
    static func main() throws -> MTLTexture {
        // Shader source embedded for this example
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float2 position [[attribute(0)]];
        };

        struct VertexOut {
            float4 position [[position]];
        };

        [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
            VertexOut out;
            out.position = float4(in.position, 0.0, 1.0);
            return out;
        }

        [[fragment]] float4 fragment_main(
            VertexOut in [[stage_in]],
            constant float4 &color [[buffer(0)]]
        ) {
            return color;
        }
        """
        
        let pixelFormat = MTLPixelFormat.bgra8Unorm
        let device = MTLCreateSystemDefaultDevice()!
        
        // Load shaders
        let library = try device.makeLibrary(source: source, options: nil)
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
        
        // Create pipeline state with reflection
        let (pipelineState, reflection) = try device.makeRenderPipelineState(
            descriptor: pipelineDescriptor, 
            options: .bindingInfo
        )
        
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
        let vertices: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
        let verticesIndex = reflection!.vertexBindings.first { 
            $0.name == "vertexBuffer.0" 
        }!.index
        renderEncoder.setVertexBytes(
            vertices, 
            length: MemoryLayout<SIMD2<Float>>.stride * 3, 
            index: verticesIndex
        )
        
        // Set fragment uniform
        var color: SIMD4<Float> = [1, 0, 0, 1]
        let colorIndex = reflection!.fragmentBindings.first { 
            $0.name == "color" 
        }!.index
        renderEncoder.setFragmentBytes(
            &color, 
            length: MemoryLayout<SIMD4<Float>>.stride, 
            index: colorIndex
        )
        
        // Draw and finish
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return texture
    }
}
```

This requires understanding and manually managing:
- Device and command queue creation
- Shader compilation and function lookup
- Vertex descriptors
- Pipeline state creation with reflection
- Texture and render target setup
- Render pass descriptors
- Command encoding
- Buffer binding indices

## MetalSprockets Approach

Here's the same triangle with MetalSprockets:

```swift
import MetalSprockets

enum RedTriangleInline {
    @MainActor
    static func main() throws -> MTLTexture {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float2 position [[attribute(0)]];
        };

        struct VertexOut {
            float4 position [[position]];
        };

        [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
            VertexOut out;
            out.position = float4(in.position, 0.0, 1.0);
            return out;
        }

        [[fragment]] float4 fragment_main(
            VertexOut in [[stage_in]],
            constant float4 &color [[buffer(0)]]
        ) {
            return color;
        }
        """
        
        let vertexShader = try VertexShader(source: source)
        let fragmentShader = try FragmentShader(source: source)

        let root = try RenderPass {
            try RenderPipeline(
                vertexShader: vertexShader, 
                fragmentShader: fragmentShader
            ) {
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
                .parameter("color", value: SIMD4<Float>([1, 0, 0, 1]))
            }
            .vertexDescriptor(try vertexShader.inferredVertexDescriptor())
        }

        let offscreenRenderer = try OffscreenRenderer(
            size: CGSize(width: 1_600, height: 1_200)
        )
        return try offscreenRenderer.render(root).texture
    }
}
```

## Key Differences

| Aspect | Traditional Metal | MetalSprockets |
|--------|-------------------|----------------|
| Lines of code | ~100 | ~50 |
| Device setup | Manual | Automatic |
| Pipeline creation | Manual descriptor + state | Declarative |
| Vertex descriptor | Manual configuration | Inferred from shader |
| Parameter binding | Manual index lookup | By name with `.parameter()` |
| Render pass | Manual descriptor | ``RenderPass`` element |
| Command encoding | Manual encoder management | Automatic |

## What MetalSprockets Handles

MetalSprockets automatically manages:

- **Device and queue creation** — Uses system default or lets you inject your own
- **Pipeline state caching** — Compiles once, reuses across frames
- **Vertex descriptor inference** — Derives layout from shader attributes
- **Parameter binding** — Uses reflection to bind by name
- **Encoder lifecycle** — Creates and ends encoders at the right time
- **Render pass setup** — Configures clear colors, load/store actions

## What You Still Control

MetalSprockets doesn't hide Metal—you still have direct access to:

- **The render encoder** — Full control in ``Draw`` closures
- **Shader source** — Write standard Metal Shading Language
- **Pipeline configuration** — Use modifiers to customize descriptors
- **Resource management** — Create and bind your own buffers and textures

## See Also

- <doc:GettingStarted>
- ``RenderPass``
- ``RenderPipeline``
- ``OffscreenRenderer``
