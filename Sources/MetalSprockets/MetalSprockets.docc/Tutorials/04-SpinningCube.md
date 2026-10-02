# Tutorial 4: 3D Spinning Cube

This tutorial renders a spinning cube with depth testing and perspective projection.

📦 **[Companion Code](https://github.com/schwa/MetalSprocketsTutorials/tree/main/Tutorial%204)**

---

## What we are Building

This tutorial renders a colorful 3D cube that spins continuously. It covers:

- The MVP (Model-View-Projection) matrix pipeline
- How to enable depth testing for correct 3D rendering
- Working with 3D vertex data and uniforms

---

## Key Concepts

### The MVP Matrix Pipeline

3D graphics use three transformation matrices applied in sequence:

1. **Model Matrix** — Transforms from local object space to world space (rotation, position, scale)
2. **View Matrix** — Transforms from world space to camera/eye space (camera position and orientation)
3. **Projection Matrix** — Transforms to clip space with perspective (near objects appear larger)

### Depth Testing

Without depth testing, triangles render in draw order. Back faces can appear over front faces. Depth testing determines visibility from the distance to the camera.

---

## Step 1: Start Fresh or Build on Tutorial 3

Start with the project from Tutorial 3, or create a new project. This tutorial replaces most of the code for 3D rendering.

---

## Step 2: Create the Shaders

Replace `Shaders.metal` with:

```metal
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

// Uniforms containing our 3 matrices
struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

vertex VertexOut cubeVertexShader(VertexIn in [[stage_in]],
                                   constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;

    // Transform vertex through model -> view -> projection
    float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    out.position = uniforms.projectionMatrix * viewPosition;

    out.color = in.color;
    return out;
}

fragment float4 cubeFragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}
```

**What's new:**

- **`float3 position`** — Stores a position in 3D space.
- **`float4 color`** — Each vertex has its own color (RGBA).
- **`Uniforms` struct** — Contains all three transformation matrices.
- **Matrix chain** — The vertex shader applies model → view → projection transforms in sequence.

---

## Step 3: Update the Vertex Struct

Replace `Vertex.swift` with:

```swift
import Metal
import simd

struct Vertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

extension Vertex {
    static var descriptor: MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()

        // position: float3 at offset 0
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0

        // color: float4 at offset 16 (SIMD3 has stride of 16, not 12)
        descriptor.attributes[1].format = .float4
        descriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        descriptor.attributes[1].bufferIndex = 0

        descriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        return descriptor
    }
}

// MARK: - Cube Generation

/// Generates a unit cube (-1 to 1) with RGB colors based on vertex position.
func generateCubeVertices() -> [Vertex] {
    // Map position components to RGB: (-1,1) -> (0,1)
    func colorForPosition(_ p: SIMD3<Float>) -> SIMD4<Float> {
        let r = (p.x + 1) * 0.5
        let g = (p.y + 1) * 0.5
        let b = (p.z + 1) * 0.5
        return SIMD4<Float>(r, g, b, 1)
    }

    // Each face defined by 4 corners in counter-clockwise order (for correct culling)
    let faces: [[SIMD3<Float>]] = [
        [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]],       // Front +Z
        [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]],   // Back -Z
        [[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]],       // Top +Y
        [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]],   // Bottom -Y
        [[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]],       // Right +X
        [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]],   // Left -X
    ]

    // Build two triangles per face (6 vertices per face, 36 total)
    var vertices: [Vertex] = []
    for face in faces {
        vertices.append(Vertex(position: face[0], color: colorForPosition(face[0])))
        vertices.append(Vertex(position: face[1], color: colorForPosition(face[1])))
        vertices.append(Vertex(position: face[2], color: colorForPosition(face[2])))
        vertices.append(Vertex(position: face[0], color: colorForPosition(face[0])))
        vertices.append(Vertex(position: face[2], color: colorForPosition(face[2])))
        vertices.append(Vertex(position: face[3], color: colorForPosition(face[3])))
    }
    return vertices
}
```

**What's new:**

- **3D position** — `SIMD3<Float>` instead of `SIMD2<Float>`.
- **Vertex colors** — Each vertex gets a color based on its 3D position (X→Red, Y→Green, Z→Blue).
- **`generateCubeVertices()`** — Creates all 36 vertices (6 faces × 2 triangles × 3 vertices) for a unit cube.
- **SIMD3 stride** — Alignment requires a stride of 16 bytes for `SIMD3<Float>`, not 12.

---

## Step 4: Create Matrix Helpers

Create a new file `MatrixHelpers.swift`:

```swift
import simd
import Foundation

extension float4x4 {
    /// Creates a translation matrix
    static func translation(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
        float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(x, y, z, 1)
        ))
    }

    /// Creates a standard perspective projection matrix
    static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let y = 1 / tan(fovY * 0.5)
        let x = y / aspect
        let z = far / (near - far)
        let w = (near * far) / (near - far)
        return float4x4(columns: (
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, -1),
            SIMD4<Float>(0, 0, w, 0)
        ))
    }
}

/// Creates a tumbling rotation matrix for the spinning cube animation
func cubeRotationMatrix(time: TimeInterval) -> float4x4 {
    let rotationY = float4x4(simd_quatf(angle: Float(time), axis: [0, 1, 0]))
    let rotationX = float4x4(simd_quatf(angle: Float(time) * 0.7, axis: [1, 0, 0]))
    return rotationX * rotationY
}
```

**What's here:**

- **`translation`** — Moves objects in 3D space. We use this to position the camera.
- **`perspective`** — Creates a perspective projection matrix with a field of view, aspect ratio, and near/far clipping planes.
- **`cubeRotationMatrix`** — Combines two rotations (around Y and X axes) for a tumbling effect.

---

## Step 5: Create the Render Pipeline

Create `SpinningCubeRenderPipeline.swift`:

```swift
import Metal
import MetalSprockets
import simd

/// Uniforms struct matching the Metal shader - contains our 3 transformation matrices
struct Uniforms {
    var modelMatrix: float4x4
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
}

struct SpinningCubeRenderPipeline: Element {
    let library: ShaderLibrary
    let uniforms: Uniforms

    init(uniforms: Uniforms) throws {
        self.library = try ShaderLibrary(bundle: .main)
        self.uniforms = uniforms
    }

    var body: some Element {
        get throws {
            let cubeVertices = generateCubeVertices()
            try RenderPipeline(
                vertexShader: library.cubeVertexShader,
                fragmentShader: library.cubeFragmentShader
            ) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: cubeVertices.count)
                }
                .vertexValues(cubeVertices, index: 0)
                .parameter("uniforms", value: uniforms)
            }
            .vertexDescriptor(Vertex.descriptor)
            // Enable depth testing so back faces don't render over front faces
            .depthCompare(function: .less, enabled: true)
        }
    }
}
```

**What's new:**

- **`Uniforms` struct** — Matches the shader's struct layout exactly. Contains all three matrices.
- **`.parameter("uniforms", value: uniforms)`** — Binds uniforms by shader argument name. `.vertexValues` sends vertices to layout index 0.
- **`.depthCompare(function: .less, enabled: true)`** — Enables depth testing. A fragment renders only when it is closer than the stored depth.

---

## Step 6: Update the View

Replace `ContentView.swift`:

```swift
import MetalSprockets
import MetalSprocketsUI
import SwiftUI
import simd

struct ContentView: View {
    var body: some View {
        RenderView { context, size in
            // Get elapsed time for animation
            let time = context.frameUniforms.time

            // Model matrix: rotation based on time (spinning cube)
            let modelMatrix = cubeRotationMatrix(time: TimeInterval(time))

            // View matrix: camera positioned back along Z axis
            let viewMatrix = float4x4.translation(0, 0, -6)

            // Projection matrix: perspective with 45° FOV
            let aspect = size.height > 0 ? Float(size.width / size.height) : 1.0
            let projectionMatrix = float4x4.perspective(
                fovY: .pi / 4,  // 45 degrees
                aspect: aspect,
                near: 0.1,
                far: 100.0
            )

            let uniforms = Uniforms(
                modelMatrix: modelMatrix,
                viewMatrix: viewMatrix,
                projectionMatrix: projectionMatrix
            )

            try RenderPass {
                try SpinningCubeRenderPipeline(uniforms: uniforms)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        // Required for depth testing - without this, back faces render over front faces
        .metalDepthStencilPixelFormat(.depth32Float)
    }
}
```

**What's new:**

- **Model matrix** — Rotates the cube based on elapsed time.
- **View matrix** — Positions the "camera" 6 units back along the Z axis.
- **Projection matrix** — Creates perspective with a 45° field of view.
- **`.metalDepthStencilPixelFormat(.depth32Float)`** — Tells RenderView to create a depth buffer. Depth testing requires this buffer.

---

## Step 7: Run It

Press **⌘R**.

The app shows a spinning cube. Depth testing keeps nearer faces in front of farther faces.

![A spinning 3D cube](tutorial-04-result)

---

## Complete Code

**MatrixHelpers.swift:**

```swift
import simd
import Foundation

extension float4x4 {
    static func translation(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
        float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(x, y, z, 1)
        ))
    }

    static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let y = 1 / tan(fovY * 0.5)
        let x = y / aspect
        let z = far / (near - far)
        let w = (near * far) / (near - far)
        return float4x4(columns: (
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, -1),
            SIMD4<Float>(0, 0, w, 0)
        ))
    }
}

func cubeRotationMatrix(time: TimeInterval) -> float4x4 {
    let rotationY = float4x4(simd_quatf(angle: Float(time), axis: [0, 1, 0]))
    let rotationX = float4x4(simd_quatf(angle: Float(time) * 0.7, axis: [1, 0, 0]))
    return rotationX * rotationY
}
```

**Vertex.swift:**

```swift
import Metal
import simd

struct Vertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

extension Vertex {
    static var descriptor: MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0
        descriptor.attributes[1].format = .float4
        descriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        descriptor.attributes[1].bufferIndex = 0
        descriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        return descriptor
    }
}

func generateCubeVertices() -> [Vertex] {
    func colorForPosition(_ p: SIMD3<Float>) -> SIMD4<Float> {
        let r = (p.x + 1) * 0.5
        let g = (p.y + 1) * 0.5
        let b = (p.z + 1) * 0.5
        return SIMD4<Float>(r, g, b, 1)
    }

    let faces: [[SIMD3<Float>]] = [
        [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]],
        [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]],
        [[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]],
        [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]],
        [[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]],
        [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]],
    ]

    var vertices: [Vertex] = []
    for face in faces {
        vertices.append(Vertex(position: face[0], color: colorForPosition(face[0])))
        vertices.append(Vertex(position: face[1], color: colorForPosition(face[1])))
        vertices.append(Vertex(position: face[2], color: colorForPosition(face[2])))
        vertices.append(Vertex(position: face[0], color: colorForPosition(face[0])))
        vertices.append(Vertex(position: face[2], color: colorForPosition(face[2])))
        vertices.append(Vertex(position: face[3], color: colorForPosition(face[3])))
    }
    return vertices
}
```

**SpinningCubeRenderPipeline.swift:**

```swift
import Metal
import MetalSprockets
import simd

struct Uniforms {
    var modelMatrix: float4x4
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
}

struct SpinningCubeRenderPipeline: Element {
    let library: ShaderLibrary
    let uniforms: Uniforms

    init(uniforms: Uniforms) throws {
        self.library = try ShaderLibrary(bundle: .main)
        self.uniforms = uniforms
    }

    var body: some Element {
        get throws {
            let cubeVertices = generateCubeVertices()
            try RenderPipeline(
                vertexShader: library.cubeVertexShader,
                fragmentShader: library.cubeFragmentShader
            ) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: cubeVertices.count)
                }
                .vertexValues(cubeVertices, index: 0)
                .parameter("uniforms", value: uniforms)
            }
            .vertexDescriptor(Vertex.descriptor)
            .depthCompare(function: .less, enabled: true)
        }
    }
}
```

**ContentView.swift:**

```swift
import MetalSprockets
import MetalSprocketsUI
import SwiftUI
import simd

struct ContentView: View {
    var body: some View {
        RenderView { context, size in
            let time = context.frameUniforms.time
            let modelMatrix = cubeRotationMatrix(time: TimeInterval(time))
            let viewMatrix = float4x4.translation(0, 0, -6)
            let aspect = size.height > 0 ? Float(size.width / size.height) : 1.0
            let projectionMatrix = float4x4.perspective(
                fovY: .pi / 4,
                aspect: aspect,
                near: 0.1,
                far: 100.0
            )

            let uniforms = Uniforms(
                modelMatrix: modelMatrix,
                viewMatrix: viewMatrix,
                projectionMatrix: projectionMatrix
            )

            try RenderPass {
                try SpinningCubeRenderPipeline(uniforms: uniforms)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .metalDepthStencilPixelFormat(.depth32Float)
    }
}
```

**Shaders.metal:**

```metal
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

vertex VertexOut cubeVertexShader(VertexIn in [[stage_in]],
                                   constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    out.position = uniforms.projectionMatrix * viewPosition;
    out.color = in.color;
    return out;
}

fragment float4 cubeFragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}
```

---

## What You Learned

1. **MVP matrices** — The Model-View-Projection pipeline transforms 3D geometry to screen coordinates
2. **Depth testing** — Use `.depthCompare()` and `.metalDepthStencilPixelFormat()` for correct 3D occlusion
3. **3D vertices** — Working with `SIMD3<Float>` positions and generating cube geometry
4. **Uniforms** — Passing structured data (matrices) to shaders via buffer bindings
