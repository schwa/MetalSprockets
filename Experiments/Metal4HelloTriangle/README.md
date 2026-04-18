# Metal4HelloTriangle

Standalone proof-of-concept: renders a single triangle using Metal 4
APIs only. No MetalSprockets, no third-party dependencies.

Exists to validate the Metal 4 command / encoder / argument-table model
end-to-end before that knowledge feeds back into MetalSprockets.
See `../../RFCs/0002-metal-4.md`.

## Requirements

- macOS 26+
- Xcode 26+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build & run

```sh
xcodegen generate
open Metal4HelloTriangle.xcodeproj
# ... or build from CLI:
xcodebuild -project Metal4HelloTriangle.xcodeproj -scheme Metal4HelloTriangle -destination "platform=macOS" build
```

## What it exercises

- `MTL4CommandQueue` (created from `MTLDevice.makeMTL4CommandQueue`)
- `MTL4CommandAllocator`
- `MTL4CommandBuffer` with explicit `beginCommandBuffer(allocator:)` /
  `endCommandBuffer`
- `MTL4Compiler` + `MTL4RenderPipelineDescriptor` +
  `MTL4LibraryFunctionDescriptor`
- `MTL4ArgumentTable` with `setAddress(_:index:)` (no per-stage
  `setVertexBuffer`)
- `MTL4RenderPassDescriptor` targeting an `MTKView` drawable
- `MTL4RenderCommandEncoder` with
  `setArgumentTable(_:stages:)` and `drawPrimitives(primitiveType:…)`
- `MTL4CommandQueue.commit(_:)` + `signalDrawable(_:)` + `drawable.present()`

## What it doesn't exercise

- `MTL4CommitOptions` / commit-feedback callbacks (the MetalSprockets
  shape that needs to route `onCommandBufferCompleted` through them)
- Residency sets
- Suspending / resuming render passes
- Compute / blit encoders
- Multiple command buffers per frame
