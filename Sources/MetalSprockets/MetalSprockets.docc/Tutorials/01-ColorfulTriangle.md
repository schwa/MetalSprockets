# Tutorial 1: Your First Metal Triangle

Render a colorful triangle using MetalSprockets. The GPU will blend red, green, and blue corners across the surface—this interpolation is fundamental to how GPUs shade geometry.

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

- **`RenderView`** is a SwiftUI view that runs Metal. Its closure is called every frame, giving you a chance to draw. The closure can throw errors—RenderView catches them and handles them for you.
- **`RenderPass`** clears the screen and sets up drawing. The `try` is needed because creating Metal resources can fail. A RenderView needs at least one RenderPass to render anything interesting. Inside a RenderPass, you'll add one or more *render pipelines*—we'll get to those shortly.

Run it (**⌘R**). You'll see a black square. This is a valid Metal program—it just doesn't draw anything yet. But Metal is actively rendering: clearing the screen to black every frame, ready for your drawing commands. The fixed aspect ratio keeps our triangle from stretching when the window resizes. The `RenderView` closure executes every frame, ready for your rendering code.

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

> **Note:** We're hardcoding vertex data directly in the shader for simplicity. Real projects pass vertex data from Swift using vertex buffers and descriptors—you'll learn that pattern in a later tutorial.

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

We use `try!` here for simplicity—in a real app you'd handle the error properly. But if your shader file is bundled with the app, it should always load successfully.

`ShaderLibrary` loads and compiles your `.metal` file. This is expensive, so we do it once when the view is created—not inside the `RenderView` closure, which runs every frame. 

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

Here we're taking the shaders we wrote earlier and telling the GPU about them. The `RenderPipeline` binds our vertex and fragment shaders together into a single unit that the GPU can execute.

---

## Step 7: Draw the Triangle

Inside the `RenderPipeline`, add a `Draw` block:

```swift
try RenderPipeline(
    vertexShader: library.colorfulTriangleVertexShader,
    fragmentShader: library.colorfulTriangleFragmentShader
) {
    Draw { encoder in
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
```

This ties it all together. The `Draw` block gives you access to the Metal encoder, where you issue drawing commands. We tell the GPU to draw a triangle using 3 vertices—and our vertex shader receives each vertex ID (0, 1, 2), looks up the position and color, and passes them to the fragment shader.

---

## Step 8: Run It

Press **⌘R**. You should see a triangle with colors smoothly blending from red (top) to green (bottom-left) to blue (bottom-right).

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
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
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

