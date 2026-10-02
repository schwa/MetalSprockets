# Tutorial 1: Your First Metal Triangle

Render a colorful triangle with MetalSprockets. The GPU interpolates the red, green, and blue corner colors across the surface.

📦 **[Companion Code](https://github.com/schwa/MetalSprocketsTutorials/tree/main/Tutorial%201)**

---

## Step 1: Create an Xcode Project

1. Open Xcode → **File → New → Project**
2. Select **Multiplatform → App**
3. Name it something like "ColorfulTriangle"
4. Click Create

The same code will run on macOS, iOS, and visionOS.

---

## Step 2: Add MetalSprockets

1. Select your project in the navigator
2. Select your app target → **General** tab
3. Scroll to **Frameworks, Libraries, and Embedded Content**
4. Click **+** → **Add Package Dependency**
5. Enter: `https://github.com/schwa/MetalSprockets`
6. Add both **MetalSprockets** and **MetalSprocketsUI** to your target

---

## Step 3: Create an Empty RenderView

Open `ContentView.swift` and replace it with:

```swift
import MetalSprockets
import MetalSprocketsUI
import SwiftUI

struct ContentView: View {
    var body: some View {
        RenderView { context, size in
            try RenderPass {
                // Nothing here yet
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
```

**What's happening:**

- **`RenderView`** is a SwiftUI view that runs Metal. It calls your drawing closure every frame and handles errors that the closure throws.
- **`RenderPass`** clears the screen and prepares drawing. Creating Metal resources can fail, so this call needs `try`. A RenderView needs a RenderPass to render the scene. The following steps add render pipelines inside that pass.

Run the app (**⌘R**).

The app shows a black square. Metal clears the screen to black each frame, but there are no drawing commands yet. The fixed aspect ratio prevents distortion when the window resizes.

---

## Step 4: Create the Shader File

Create a new file: **File → New → File → Metal File**. Name it `Shaders.metal`.

Replace its contents with:

```metal
#include <metal_stdlib>
using namespace metal;

// Output from vertex shader, input to fragment shader
struct VertexOut {
    float4 position [[position]];  // Required: clip-space position
    float4 color;                  // Interpolated across the triangle
};

vertex VertexOut colorfulTriangleVertexShader(uint vertexID [[vertex_id]]) {
    // Hardcoded triangle vertices (clip space: -1 to 1)
    const float2 positions[] = {
        float2(0.0, 0.75),      // Top
        float2(-0.75, -0.75),   // Bottom-left
        float2(0.75, -0.75)     // Bottom-right
    };

    // Hardcoded colors (RGBA)
    const float4 colors[] = {
        float4(1.0, 0.0, 0.0, 1.0),  // Red
        float4(0.0, 1.0, 0.0, 1.0),  // Green
        float4(0.0, 0.0, 1.0, 1.0)   // Blue
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.color = colors[vertexID];
    return out;
}

fragment float4 colorfulTriangleFragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}
```

> **Note:** This example stores vertex data directly in the shader. A later tutorial passes vertex data from Swift through buffers and descriptors.

**How a RenderPass uses these shaders:**

A RenderPass contains one or more *render pipelines*. Each pipeline combines a vertex shader, a fragment shader, and possibly other configuration.

When you issue a draw command:

1. The **vertex shader** runs once per vertex. Each call receives a `[[vertex_id]]` (0, 1, or 2) and outputs a position and color.

2. The GPU figures out which pixels the triangle covers.

3. The **fragment shader** runs once per pixel. It receives the color values from the vertex shader, automatically interpolated based on position. A pixel halfway between a red vertex and a green vertex gets yellow.

```
Vertex Shader (3x) → Fragment Shader (once per pixel) → Screen
```

---

## Step 5: Load the Shaders

Back in `ContentView.swift`, add a property to load your shader file:

```swift
struct ContentView: View {
    let library = try! ShaderLibrary(bundle: .main)
    
    var body: some View {
        // ...
    }
}
```

This example uses `try!` for brevity. Production apps need error handling. A shader file bundled with the app is expected to load successfully.

`ShaderLibrary` loads and compiles your `.metal` file. This example performs that expensive work once, when the view is created. It does not repeat the work in the per-frame `RenderView` closure.

---

## Step 6: Set Up the Render Pipeline

Wrap your rendering in a `RenderPass` and `RenderPipeline`:

```swift
RenderView { context, size in
    try RenderPass {
        try RenderPipeline(
            vertexShader: library.colorfulTriangleVertexShader,
            fragmentShader: library.colorfulTriangleFragmentShader
        ) {
            // Draw commands go here
        }
    }
}
.aspectRatio(1, contentMode: .fit)
```

`RenderPipeline` combines the vertex and fragment shaders into one pipeline for the GPU.

---

## Step 7: Draw the Triangle

Inside the `RenderPipeline`, add a `Draw` block:

```swift
try RenderPipeline(
    vertexShader: library.colorfulTriangleVertexShader,
    fragmentShader: library.colorfulTriangleFragmentShader
) {
    Draw { encoder in
        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
```

The `Draw` block provides the Metal encoder for drawing commands. This command draws a triangle with three vertices. The vertex shader receives each vertex ID (0, 1, 2). It looks up the position and color, then passes them to the fragment shader.

---

## Step 8: Run It

Press **⌘R**.

The app shows a triangle with colors that blend from red (top) to green (bottom-left) to blue (bottom-right).

![A colorful triangle rendered with Metal](tutorial-01-result)

---

## Complete Code

**ContentView.swift:**

```swift
import MetalSprockets
import MetalSprocketsUI
import SwiftUI

struct ContentView: View {
    let library = try! ShaderLibrary(bundle: .main)

    var body: some View {
        RenderView { context, size in
            try RenderPass {
                try RenderPipeline(
                    vertexShader: library.colorfulTriangleVertexShader,
                    fragmentShader: library.colorfulTriangleFragmentShader
                ) {
                    Draw { encoder in
                        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                }
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

// Output from vertex shader, input to fragment shader
struct VertexOut {
    float4 position [[position]];  // Required: clip-space position
    float4 color;                  // Interpolated across the triangle
};

vertex VertexOut colorfulTriangleVertexShader(uint vertexID [[vertex_id]]) {
    const float2 positions[] = {
        float2(0.0, 0.75),
        float2(-0.75, -0.75),
        float2(0.75, -0.75)
    };

    const float4 colors[] = {
        float4(1.0, 0.0, 0.0, 1.0),
        float4(0.0, 1.0, 0.0, 1.0),
        float4(0.0, 0.0, 1.0, 1.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.color = colors[vertexID];
    return out;
}

fragment float4 colorfulTriangleFragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}
```

