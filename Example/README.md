# MetalSprockets Example

This project demonstrates MetalSprockets with a spinning cube. It uses `RenderView` to integrate Metal rendering into SwiftUI. Render passes form an element tree, similar to a SwiftUI view hierarchy.

Platform examples include ARKit camera passthrough on iOS and immersive mixed reality on visionOS.

## Platforms

- **macOS** — View based rendering
- **iOS/iPadOS** — View based + ARKit camera passthrough mode
- **visionOS** — View based + immersive mixed reality mode

## What it demonstrates

- `RenderView` (MetalSprocketsUI) — SwiftUI integration for Metal rendering
- `RenderPass` (MetalSprockets) — Creates a render command encoder
- `RenderPipeline` (MetalSprockets) — Binds shaders and pipeline state
- `Draw` (MetalSprockets) — Direct access to MTLRenderCommandEncoder
- `ShaderLibrary` (MetalSprockets) — Type-safe shader access via macro
- `YCbCrBillboardRenderPass` (MetalSprocketsUI) — Camera background rendering (iOS)
- `ImmersiveRenderContent` (MetalSprocketsUI) — CompositorServices integration (visionOS)
- `OffscreenRenderer` (MetalSprockets) — Render to texture for screenshots
