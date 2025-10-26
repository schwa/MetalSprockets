![MetalSprocketsLogo](Documentation/MetalSprockets.png)

# [MetalSprockets](https://github.com/schwa/MetalSprockets)

> "It's like SwiftUI — but for Metal."

MetalSprockets is a Swift package that brings a **declarative, composable** layer to Metal.
You describe render graphs in Swift the same way you describe views in SwiftUI while keeping full control over shaders, buffers, and GPU resources.

---

## Highlights

- **Declarative & composable:**
  Compose your GPU workload as a tree of `Element`s — each representing a _pass_, _pipeline_, or composition of both.
  Combine them naturally with Swift result builders to create render graphs in pure Swift.

- **SwiftUI-inspired design:**
  `Element` ≈ `View`.
  `@MSState`, `@MSBinding`, and `@MSEnvironment` mirror SwiftUI’s data-flow model, making the framework immediately familiar to anyone who’s built SwiftUI UIs — except here it drives GPU state and frame updates.

- **Automatic resource binding:**
  Forget manual Metal shader uniform/buffer/texture indices.
  The `.parameter()` API uses **reflection** to bind values by name across shader stages.

- **Unified graph for all GPU stages:**
  Mix render, compute, mesh, and object shaders in a single graph.
  Passes can feed resources into subsequent pipelines explicitly, giving you predictable GPU dependency flow.

- **Swift-native integration:**
  Use `RenderView` to embed live Metal rendering in SwiftUI, or `OffscreenRenderer` for headless pipelines — the same API works everywhere.

---

## SwiftUI Parallels

| SwiftUI        | MetalSprockets   | Purpose                                             |
| -------------- | ---------------- | --------------------------------------------------- |
| `View`         | `Element`        | Declaratively describes GPU work instead of layout. |
| `@State`       | `@MSState`       | Local element state that triggers GPU updates.      |
| `@Binding`     | `@MSBinding`     | Two-way data flow through the render graph.         |
| `@Environment` | `@MSEnvironment` | Scoped GPU context or shared resources.             |
| `View` host    | `RenderView`     | Embeds an `Element` tree into SwiftUI.              |

While SwiftUI drives UI layout and compositing, MetalSprockets drives GPU command encoding and resource management — both use the same declarative mental model.

---

## Requirements

- Apple Silicon Mac, iOS, or visionOS device
- Swift 6.1 / Xcode 16+
- **Apple GPUs only:** Intel Macs are not supported. MetalSprockets targets Apple Silicon / Apple GPU devices.

**Notes:**

- Build natively for `arm64`.
- Prefer real hardware over simulators for accurate GPU behavior.
- Reuse pipeline and buffer resources across frames.
- Use Xcode’s Metal frame capture + API validation to debug GPU work.

---

## Targets

MetalSprockets is organized into several Swift package targets:

| Target                       | Purpose                                                                                                                 |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **MetalSprockets**           | Core framework — declarative `Element` API, render graph composition, and automatic resource binding.                   |
| **MetalSprocketsUI**         | SwiftUI integration — provides `RenderView` for embedding Metal rendering in SwiftUI apps.                              |
| **MetalSprocketsSupport**    | Internal support utilities and shared infrastructure used by other targets. Not intended for use outside MetalSprockets |
| **MetalSprocketsSnapshotUI** | MetalSprockets can record snapshots of the render graph.                                                                |
| **MetalSprocketsMacros**     | Swift macros implementation — powers `@MSState`, `@MSBinding`, `@MSEnvironment`, and other property wrappers.           |

For most use cases, you'll link **MetalSprockets** (for core rendering) and **MetalSprocketsUI** (for SwiftUI integration).

---

## Installation

Add via Swift Package Manager:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/schwa/MetalSprockets", branch: "main")
],
targets: [
    .target(
        name: "MyRenderer",
        dependencies: [
            .product(name: "MetalSprockets", package: "MetalSprockets"),
            .product(name: "MetalSprocketsUI", package: "MetalSprockets")
        ]
    )
]
```

Or in Xcode: **File ▸ Add Packages…** and paste the repo URL.

Then link `MetalSprockets` and `MetalSprocketsUI` in your target.

---

## Quick Start

```swift
import SwiftUI
import MetalSprockets
import MetalSprocketsUI

struct ContentView: View {
    var body: some View {
        RenderView { _, _ in
            try RedTriangle()
        }
    }
}

struct RedTriangle: Element {
    let vertexShader: VertexShader
    let fragmentShader: FragmentShader

    init() throws {
        let src = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn { float2 pos [[attribute(0)]]; };
        struct VertexOut { float4 pos [[position]]; };

        [[vertex]] VertexOut vertex_main(VertexIn in [[stage_in]]) {
            VertexOut out;
            out.pos = float4(in.pos, 0, 1);
            return out;
        }

        [[fragment]] float4 fragment_main(VertexOut, constant float4 &color [[buffer(0)]]) {
            return color;
        }
        """
        vertexShader = try VertexShader(source: src)
        fragmentShader = try FragmentShader(source: src)
    }

    var body: some Element {
        try RenderPass {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { enc in
                    let verts: [SIMD2<Float>] = [[0,0.75],[-0.75,-0.75],[0.75,-0.75]]
                    enc.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * verts.count, index: 0)
                    enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: verts.count)
                }
                .parameter("color", value: SIMD4<Float>(1,0,0,1))
            }
        }
    }
}
```

For production, place shaders in `.metal` files (for syntax highlighting, caching, and frame-capture integration). Consider using the companion Metal compiler plugin for use within Swift Packages: https://github.com/schwa/MetalCompilerPlugin.

---

## Shader Types

| Type                     | Use                 | MS Type                                            |
| ------------------------ | ------------------- | -------------------------------------------------- |
| Render (vertex/fragment) | Rasterized geometry | `RenderPipeline`, `RenderPass`                     |
| Compute                  | GPGPU workloads     | `ComputeShader`, `ComputePass`                     |
| Mesh/Object (Metal 3)    | GPU-driven geometry | `MeshShader`, `ObjectShader`, `MeshRenderPipeline` |

Each integrates seamlessly via the same `Element` composition model — allowing render and compute workloads to coexist in one unified Swift graph.

---

## Examples

- **Minimalist demo app:** `Example/MetalSprockets-Example`
- **Larger examples (external):** https://github.com/schwa/MetalSprocketsExamples

---

## License

MIT — see [LICENSE](LICENSE)

---

## AI Usage

The core library is handwritten by humans. Some sample code and docs were drafted with AI assistance and then **reviewed and edited** before inclusion.
