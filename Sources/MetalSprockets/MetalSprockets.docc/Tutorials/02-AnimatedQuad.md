# Tutorial 2: Vertex Buffers and Custom Elements

In the previous tutorial, we hardcoded vertex data in the shader. That works for simple demos, but real projects define geometry in Swift and pass it to the GPU.

---

## What We're Building

A quad with a rainbow gradient across it. You'll learn:

- How to define vertex data in Swift and send it to the GPU
- How vertex descriptors tell Metal the layout of your data
- How to create reusable render pipeline Elements

---

## Step 1: Start With the Previous Tutorial

Start with the project from Tutorial 1, or create a new one following those steps. We'll modify it to use vertex buffers.

---

## Step 2: Update the Shader

Replace `Shaders.metal` with:

```metal
#include <metal_stdlib>
using namespace metal;

// Vertex input - matches the Swift Vertex struct
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 textureCoordinate [[attribute(1)]];
};

// Output from vertex shader, input to fragment shader
struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex VertexOut rainbowQuadVertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.textureCoordinate = in.textureCoordinate;
    return out;
}

// Convert hue (0-1) to RGB color
float3 hueToRGB(float hue) {
    float3 rgb = abs(fmod(hue * 6.0 + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0;
    return saturate(rgb);
}

fragment float4 rainbowQuadFragmentShader(VertexOut in [[stage_in]]) {
    // Diagonal position (0 to 1 across the quad)
    float hue = (in.textureCoordinate.x + in.textureCoordinate.y) * 0.5;
    
    float3 color = hueToRGB(hue);
    return float4(color, 1.0);
}
```

**What's new:**

- **`VertexIn`** uses `[[attribute(N)]]` to receive data from Swift. Each attribute maps to a field in our Swift struct.
- **`textureCoordinate`** tells the fragment shader where each pixel is within the quad (0-1 on each axis). We use it here for the rainbow gradient, but it's typically used for texture mapping.
- **`hueToRGB`** converts a hue value (0-1) to an RGB color—this creates our rainbow.
- The diagonal UV position creates a rainbow gradient from corner to corner.

---

## Step 3: Define the Vertex Struct in Swift

In Swift, we need a struct that matches `VertexIn` exactly. Create a new file `Vertex.swift`:

```swift
import Metal
import simd

struct Vertex {
    var position: SIMD2<Float>
    var textureCoordinate: SIMD2<Float>
}
```

The order and types must match the shader's `VertexIn`. Both use the same memory layout.

---

## Step 4: Create the Vertex Descriptor

The vertex descriptor tells Metal how to read your `Vertex` struct. Add this to `Vertex.swift`:

```swift
extension Vertex {
    static var descriptor: MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()

        // Attribute 0: position (float2) at offset 0
        descriptor.attributes[0].format = .float2
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0

        // Attribute 1: textureCoordinate (float2) at offset 8
        descriptor.attributes[1].format = .float2
        descriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        descriptor.attributes[1].bufferIndex = 0

        // Total stride per vertex
        descriptor.layouts[0].stride = MemoryLayout<Vertex>.stride

        return descriptor
    }
}
```

Each `[[attribute(N)]]` in the shader maps to `descriptor.attributes[N]` here. The offset is the byte position of each field within the struct.

---

## Step 5: Create a Reusable Render Pipeline

Instead of putting all our rendering code in the view, let's create a reusable Element. This is like a SwiftUI View, but for Metal rendering. Create `RainbowQuadRenderPipeline.swift`:

```swift
import Metal
import MetalSprockets
import simd

struct RainbowQuadRenderPipeline: Element {
    let library: ShaderLibrary

    // Quad vertices: two triangles forming a square
    //
    // GPUs only draw triangles, so a quad needs two:
    //
    //   3 ----- 2/5
    //   |     / |
    //   |   /   |
    //   | /     |
    //  0/4 --- 1
    //
    // Vertices 0 and 4 are the same position (bottom-left)
    // Vertices 2 and 5 are the same position (top-right)
    //
    let vertices: [Vertex] = [
        // First triangle (bottom-left, bottom-right, top-right)
        Vertex(position: [-0.75, -0.75], textureCoordinate: [0, 0]),
        Vertex(position: [0.75, -0.75], textureCoordinate: [1, 0]),
        Vertex(position: [0.75, 0.75], textureCoordinate: [1, 1]),
        // Second triangle (bottom-left, top-right, top-left)
        Vertex(position: [-0.75, -0.75], textureCoordinate: [0, 0]),
        Vertex(position: [0.75, 0.75], textureCoordinate: [1, 1]),
        Vertex(position: [-0.75, 0.75], textureCoordinate: [0, 1]),
    ]

    init() throws {
        self.library = try ShaderLibrary(bundle: .main)
    }

    var body: some Element {
        get throws {
            try RenderPipeline(
                vertexShader: library.rainbowQuadVertexShader,
                fragmentShader: library.rainbowQuadFragmentShader
            ) {
                Draw { encoder in
                    // Send vertex data to GPU
                    var verts = vertices
                    encoder.setVertexBytes(
                        &verts,
                        length: MemoryLayout<Vertex>.stride * vertices.count,
                        index: 0
                    )

                    // Draw the quad (6 vertices = 2 triangles)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                }
            }
            .vertexDescriptor(Vertex.descriptor)
        }
    }
}
```

**What's happening:**

- **`Element`** is MetalSprockets' equivalent of SwiftUI's `View`. It has a `body` that returns other Elements. Unlike SwiftUI, Element bodies can throw errors—useful since Metal operations can fail.
- **`init`** loads the shader library once when the element is created—not in `body`, which runs every frame.
- **`vertices`** defines a quad as two triangles. Each vertex has a position and texture coordinate.
- **`setVertexBytes`** sends our vertex array to the GPU at buffer index 0. Unlike Tutorial 1 where we hardcoded vertices in the shader, here we define them in Swift and send them to the GPU each frame.
- **`.vertexDescriptor()`** tells the pipeline how to interpret our vertex data—matching Swift's `Vertex` struct to the shader's `VertexIn`.

---

## Step 6: Use the Element in Your View

Update `ContentView.swift`:

```swift
import MetalSprockets
import MetalSprocketsUI
import SwiftUI

struct ContentView: View {
    var body: some View {
        RenderView { context, size in
            try RenderPass {
                try RainbowQuadRenderPipeline()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
```

Notice how clean this is—all the rendering logic is encapsulated in `RainbowQuadRenderPipeline`.

---

## Step 7: Run It

Press **⌘R**. You should see a quad with a rainbow gradient flowing diagonally from one corner to the other.

---

## Complete Code

**Vertex.swift:**

```swift
import Metal
import simd

struct Vertex {
    var position: SIMD2<Float>
    var textureCoordinate: SIMD2<Float>
}

extension Vertex {
    static var descriptor: MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].format = .float2
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0
        descriptor.attributes[1].format = .float2
        descriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        descriptor.attributes[1].bufferIndex = 0
        descriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        return descriptor
    }
}
```

**RainbowQuadRenderPipeline.swift:**

```swift
import Metal
import MetalSprockets
import simd

struct RainbowQuadRenderPipeline: Element {
    let library: ShaderLibrary

    // Two triangles forming a quad (6 vertices, 2 shared positions)
    let vertices: [Vertex] = [
        Vertex(position: [-0.75, -0.75], textureCoordinate: [0, 0]),
        Vertex(position: [0.75, -0.75], textureCoordinate: [1, 0]),
        Vertex(position: [0.75, 0.75], textureCoordinate: [1, 1]),
        Vertex(position: [-0.75, -0.75], textureCoordinate: [0, 0]),
        Vertex(position: [0.75, 0.75], textureCoordinate: [1, 1]),
        Vertex(position: [-0.75, 0.75], textureCoordinate: [0, 1]),
    ]

    init() throws {
        self.library = try ShaderLibrary(bundle: .main)
    }

    var body: some Element {
        get throws {
            try RenderPipeline(
                vertexShader: library.rainbowQuadVertexShader,
                fragmentShader: library.rainbowQuadFragmentShader
            ) {
                Draw { encoder in
                    var verts = vertices
                    encoder.setVertexBytes(
                        &verts,
                        length: MemoryLayout<Vertex>.stride * vertices.count,
                        index: 0
                    )
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                }
            }
            .vertexDescriptor(Vertex.descriptor)
        }
    }
}
```

**ContentView.swift:**

```swift
import MetalSprockets
import MetalSprocketsUI
import SwiftUI

struct ContentView: View {
    var body: some View {
        RenderView { context, size in
            try RenderPass {
                try RainbowQuadRenderPipeline()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
```

**Shaders.metal:**

```metal
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 textureCoordinate [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex VertexOut rainbowQuadVertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.textureCoordinate = in.textureCoordinate;
    return out;
}

float3 hueToRGB(float hue) {
    float3 rgb = abs(fmod(hue * 6.0 + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0;
    return saturate(rgb);
}

fragment float4 rainbowQuadFragmentShader(VertexOut in [[stage_in]]) {
    float hue = (in.textureCoordinate.x + in.textureCoordinate.y) * 0.5;
    float3 color = hueToRGB(hue);
    return float4(color, 1.0);
}
```

---

## What You Learned

1. **Vertex buffers** — Define geometry in Swift, send it to the GPU with `setVertexBytes`
2. **Vertex descriptors** — Tell Metal how to interpret your vertex struct layout
3. **Custom Elements** — Encapsulate rendering logic in reusable, composable units
