# Tutorial 3: Animated Rainbow Quad

The previous tutorial created a static rainbow gradient. This tutorial animates it with a time value from RenderView.

📦 **[Companion Code](https://github.com/schwa/MetalSprocketsTutorials/tree/main/Tutorial%203)**

---

## What we are Building

This tutorial renders a rainbow quad with colors that cycle continuously. It covers:

- How to access frame timing from RenderView's context
- How to pass parameters from Swift to shaders using `.parameter()`
- How MetalSprockets automatically binds named parameters

---

## Step 1: Start With the Previous Tutorial

Start with the project from Tutorial 2. This tutorial adds animation.

---

## Step 2: Update the Shader

Update `Shaders.metal` to accept a time parameter:

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

fragment float4 rainbowQuadFragmentShader(VertexOut in [[stage_in]],
                                          constant float &time [[buffer(0)]]) {
    float hue = (in.textureCoordinate.x + in.textureCoordinate.y) * 0.5 + time * 0.5;
    hue = fmod(hue, 1.0);
    float3 color = hueToRGB(hue);
    return float4(color, 1.0);
}
```

**What's new:**

- **`constant float &time [[buffer(0)]]`** — The fragment shader now receives a time value from a buffer. The `constant` address space is for read-only data.
- **`time * 0.5`** — Time changes the hue so the rainbow scrolls. The `* 0.5` controls the animation speed.
- **`fmod(hue, 1.0)`** — Wraps the hue to the 0-1 range so the animation repeats without a visible jump.

---

## Step 3: Update the Render Pipeline

Update `RainbowQuadRenderPipeline.swift` to accept and pass the time parameter:

```swift
import Metal
import MetalSprockets
import simd

struct RainbowQuadRenderPipeline: Element {
    let library: ShaderLibrary
    let time: Float

    // Two triangles forming a quad (6 vertices, 2 shared positions)
    let vertices: [Vertex] = [
        Vertex(position: [-0.75, -0.75], textureCoordinate: [0, 0]),
        Vertex(position: [0.75, -0.75], textureCoordinate: [1, 0]),
        Vertex(position: [0.75, 0.75], textureCoordinate: [1, 1]),
        Vertex(position: [-0.75, -0.75], textureCoordinate: [0, 0]),
        Vertex(position: [0.75, 0.75], textureCoordinate: [1, 1]),
        Vertex(position: [-0.75, 0.75], textureCoordinate: [0, 1]),
    ]

    init(time: Float) throws {
        self.library = try ShaderLibrary(bundle: .main)
        self.time = time
    }

    var body: some Element {
        get throws {
            try RenderPipeline(
                vertexShader: library.rainbowQuadVertexShader,
                fragmentShader: library.rainbowQuadFragmentShader
            ) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 6)
                }
                .vertexValues(vertices, index: 0)
                .parameter("time", value: time)
            }
            .vertexDescriptor(Vertex.descriptor)
        }
    }
}
```

**What's new:**

- **`let time: Float`** — The pipeline now stores the current time.
- **`init(time: Float)`** — Accept time when creating the pipeline.
- **`.parameter("time", value: time)`** — Passes data to the shader by name. MetalSprockets matches `"time"` to the shader parameter and binds the value to its buffer index.

---

## Step 4: Update the View

Update `ContentView.swift` to pass time from the RenderView context:

```swift
import MetalSprockets
import MetalSprocketsUI
import SwiftUI

struct ContentView: View {
    var body: some View {
        RenderView { context, size in
            try RenderPass {
                try RainbowQuadRenderPipeline(time: context.frameUniforms.time)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
```

**What's new:**

- **`context.frameUniforms.time`** — Gives the elapsed time in seconds since the view started rendering. RenderView updates this value each frame.

---

## Step 5: Run It

Press **⌘R**.

The rainbow colors cycle across the quad.

![An animated rainbow quad](tutorial-03-result)

---

## Complete Code

**ContentView.swift:**

```swift
import MetalSprockets
import MetalSprocketsUI
import SwiftUI

struct ContentView: View {
    var body: some View {
        RenderView { context, size in
            try RenderPass {
                try RainbowQuadRenderPipeline(time: context.frameUniforms.time)
            }
        }
        .aspectRatio(1, contentMode: .fit)
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
    let time: Float

    let vertices: [Vertex] = [
        Vertex(position: [-0.75, -0.75], textureCoordinate: [0, 0]),
        Vertex(position: [0.75, -0.75], textureCoordinate: [1, 0]),
        Vertex(position: [0.75, 0.75], textureCoordinate: [1, 1]),
        Vertex(position: [-0.75, -0.75], textureCoordinate: [0, 0]),
        Vertex(position: [0.75, 0.75], textureCoordinate: [1, 1]),
        Vertex(position: [-0.75, 0.75], textureCoordinate: [0, 1]),
    ]

    init(time: Float) throws {
        self.library = try ShaderLibrary(bundle: .main)
        self.time = time
    }

    var body: some Element {
        get throws {
            try RenderPipeline(
                vertexShader: library.rainbowQuadVertexShader,
                fragmentShader: library.rainbowQuadFragmentShader
            ) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 6)
                }
                .vertexValues(vertices, index: 0)
                .parameter("time", value: time)
            }
            .vertexDescriptor(Vertex.descriptor)
        }
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

fragment float4 rainbowQuadFragmentShader(VertexOut in [[stage_in]],
                                          constant float &time [[buffer(0)]]) {
    float hue = (in.textureCoordinate.x + in.textureCoordinate.y) * 0.5 + time * 0.5;
    hue = fmod(hue, 1.0);
    float3 color = hueToRGB(hue);
    return float4(color, 1.0);
}
```

**Vertex.swift:** (unchanged from Tutorial 2)

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

---

## What You Learned

1. **Frame uniforms** — Access timing and other per-frame data from `context.frameUniforms`
2. **Parameter binding** — Use `.parameter("name", value:)` to pass values to shaders declaratively
3. **Shader animation** — Use time to create smooth, continuous animations in Metal shaders
