# Metal4HelloTriangle

This standalone example renders one triangle with Metal 4 APIs.
It does not use MetalSprockets or third-party dependencies.


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

## What it does not cover

- `MTL4CommitOptions` and commit-feedback callbacks that deliver `onCommandBufferCompleted` results
- Residency sets
- Suspending / resuming render passes
- Compute / blit encoders
- Multiple command buffers per frame
