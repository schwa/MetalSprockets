# MetalSprockets Example

This project demonstrates the core concepts of MetalSprockets through a simple spinning cube. It shows how to integrate Metal rendering into SwiftUI using `RenderView`, compose render passes using the Element pattern (similar to SwiftUI's View hierarchy), and extend to platform-specific features like ARKit camera passthrough on iOS and immersive mixed reality on visionOS.

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
