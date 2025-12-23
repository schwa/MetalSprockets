# ``MetalSprockets``

A declarative, composable framework for Metal rendering—like SwiftUI, but for GPU work.

## Overview

MetalSprockets lets you describe render graphs in Swift the same way you describe views in SwiftUI. You compose `Element` types into a tree that represents GPU work: render passes, pipelines, and draw commands.

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
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
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

Unlike SwiftUI's `body`, Element bodies can throw errors—useful since Metal operations can fail.

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

### Render Pipeline

- ``RenderPass``
- ``RenderPipeline``
- ``Draw``

### Shaders

- ``ShaderLibrary``
- ``VertexShader``
- ``FragmentShader``
- ``ComputeKernel``

### Compute

- ``ComputePass``
- ``ComputeDispatch``

### Mesh Shading

- ``MeshRenderPipeline``
- ``MeshShader``
- ``ObjectShader``

### State Management

- ``MSState``
- ``MSBinding``
- ``MSEnvironment``

### Composition

- ``Group``
- ``ForEach``
- ``EmptyElement``

### Offscreen Rendering

- ``OffscreenRenderer``
- ``OffscreenVideoRenderer``
