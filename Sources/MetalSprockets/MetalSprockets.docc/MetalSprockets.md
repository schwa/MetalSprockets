# ``MetalSprockets``

A declarative framework that composes Metal rendering operations, like SwiftUI for GPU work.

## Overview

MetalSprockets describes render graphs in Swift, as SwiftUI describes views. `Element` types form a tree of GPU work: render passes, pipelines, and draw commands.

```swift
struct MyTriangle: Element {
    let library: ShaderLibrary
    
    init() throws {
        library = try ShaderLibrary(bundle: .main)
    }
    
    var body: some Element {
        get throws {
            try RenderPass {
                try RenderPipeline(
                    vertexShader: library.vertexMain,
                    fragmentShader: library.fragmentMain
                ) {
                    Draw { encoder in
                        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                }
            }
        }
    }
}
```

### SwiftUI Parallels

MetalSprockets mirrors SwiftUI's design patterns:

| SwiftUI | MetalSprockets | Purpose |
|---------|----------------|---------|
| `View` | ``Element`` | Declaratively describes GPU work |
| `@State` | `@MSState` | Local element state |
| `@Binding` | `@MSBinding` | Two-way data flow |
| `@Environment` | `@MSEnvironment` | Scoped context and resources |
| View host | `RenderView` | Embeds elements in SwiftUI |

Unlike SwiftUI's `body`, Element bodies can throw errors because Metal operations can fail.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Comparison>

### Tutorials

- <doc:TutorialOverview>

### Deep Dive

- <doc:Architecture>
- <doc:Internals>
- <doc:FAQ>

### Core Types

- ``Element``
- ``ElementBuilder``
- ``AnyElement``

### Render Pipeline

- ``RenderPass``
- ``RenderPipeline``
- ``Draw``
- ``RenderCommand``
- ``RenderPipelineDescriptorTransformer``
- ``RenderAttachmentFormats``

### Shaders

- ``ShaderLibrary``
- ``VertexShader``
- ``FragmentShader``
- ``ComputeKernel``
- ``ShaderFunction``
- ``ShaderNamespace``
- ``FunctionConstants``
- ``FunctionTypes``
- ``ShaderParameters``
- ``Reflection``

### Shader Loading and Caching

- ``ShaderLoader``
- ``MetalShaderLoader``
- ``ShaderStore``
- ``ShaderCache``
- ``ShaderLogging``

### Compute

- ``ComputePass``
- ``ComputePipeline``
- ``ComputeDispatch``
- ``ComputeCommand``

### Mesh Shading

- ``MeshRenderPipeline``
- ``MeshShader``
- ``ObjectShader``

### Synchronization

- ``EncoderBarrier``
- ``QueueBarrier``

### Resources and Residency

- ``ResourceCollection``
- ``ResidencyConfiguration``

### Upscaling

- ``MetalFXSpatial``
- ``MetalFXTemporal``

### State Management

- ``MSState``
- ``MSBinding``
- ``MSObservedObject``
- ``MSEnvironment``
- ``MSEnvironmentValues``
- ``MSEnvironmentKey``
- ``MSDynamicProperty``
- ``EnvironmentReader``

### Composition

- ``Group``
- ``ForEach``
- ``EmptyElement``
- ``TupleElement``

### Running Elements

- ``Runner``
- ``OffscreenRenderer``
- ``OffscreenVideoRenderer``
- ``Submission``
- ``SubmissionResult``

### Debugging and Profiling

- ``LoggingElement``
- ``CaptureTarget``
- ``GPUTiming``
- ``GPUCounterSample``
- ``CPUPhaseTimings``
- ``SystemSnapshot``
- ``NodeSnapshot``
- ``StatePropertySnapshot``
- ``EnvironmentSnapshot``
- ``StructuralIdentifier``
- ``ElementTypeIdentifier``
- ``AnyElementID``
- ``FunctionConstantInfo``
