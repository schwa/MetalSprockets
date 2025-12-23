# Getting Started with MetalSprockets

Create your first Metal render using declarative Swift.

## Overview

MetalSprockets lets you build GPU render graphs using familiar SwiftUI patterns. This guide walks you through the core concepts.

### The Element Protocol

``Element`` is the fundamental building block—like SwiftUI's `View`, but for GPU work. Elements compose together to form render graphs:

```swift
struct ColorfulTriangle: Element {
    let library: ShaderLibrary
    
    init() throws {
        library = try ShaderLibrary(bundle: .main)
    }
    
    var body: some Element {
        get throws {
            try RenderPass {
                try RenderPipeline(
                    vertexShader: library.myVertexShader,
                    fragmentShader: library.myFragmentShader
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

### Passes and Pipelines

A **render pass** (``RenderPass``) clears the screen and sets up render targets. A **render pipeline** (``RenderPipeline``) binds shaders together. The hierarchy is:

```
RenderPass
└── RenderPipeline (vertex + fragment shaders)
    └── Draw (issues GPU commands)
```

You can have multiple pipelines in a pass (for different materials) and multiple passes in a frame (for shadow maps, post-processing, etc.).

### Loading Shaders

``ShaderLibrary`` loads compiled shaders from your `.metal` files:

```swift
let library = try ShaderLibrary(bundle: .main)
let vertexShader: VertexShader = library.myVertexFunction
let fragmentShader: FragmentShader = library.myFragmentFunction
```

Use dynamic member lookup with type annotation to get the correct shader type.

### Passing Data to Shaders

Use the `.parameter()` modifier to bind values by name:

```swift
Draw { encoder in
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
}
.parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
.parameter("transform", value: modelMatrix)
```

MetalSprockets uses reflection to match parameter names to shader uniforms automatically.

### Displaying in SwiftUI

Use `RenderView` from MetalSprocketsUI to embed Metal rendering in SwiftUI:

```swift
import MetalSprocketsUI

struct ContentView: View {
    var body: some View {
        RenderView { context, size in
            try RenderPass {
                try MyRenderPipeline()
            }
        }
    }
}
```

The closure runs every frame. Access timing information via `context.frameUniforms.time`.

## See Also

- ``Element``
- ``RenderPass``
- ``RenderPipeline``
- ``ShaderLibrary``
