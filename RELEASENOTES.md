# Release Notes

## 0.1.7

### New: MetalSprocketsShaders target

- Added `MetalSprocketsShaders` — a C target providing cross-environment preprocessor macros for shared Metal/Swift header files (`TEXTURE2D`, `DEPTH2D`, `TEXTURECUBE`, `SAMPLER`, `BUFFER`, `ATTRIBUTE`, `MS_ENUM`)

### Fixes

- Fixed RenderView per-frame allocation churn and resource leak on view removal

### Other

- README: removed incorrect mention of `for/in` support in `@ElementBuilder`
- Documentation updates

---

## 0.1.6

### Frame timing

- Added `FrameTimingView` and frame timing statistics
- GPU timing support via command buffer timestamps
- FPS logging in `RenderView` (controlled by `MS_RENDERVIEW_LOG_FRAME`)

### Fixes

- Fixed retain cycle in `RenderViewViewModel.draw()`
- Fixed `onCommandBufferCompleted` and `onCommandBufferScheduled` reliability
- Fixed warnings-as-errors build failures on Xcode 26

### Other

- Environment variables renamed to `MS_` prefix (legacy names still work)
- Improved logging: symmetrical Enter/Exit messages, thread info in draw callbacks
- CI bumped to Xcode 26.4 and Node.js 24 compatible GitHub Actions

---

## 0.1.5

### Visible function tables

- Added `VisibleFunctionTableModifier` for binding visible functions to shaders

### Other

- Added `useResources` helper for marking multiple `MTLResource`s in use
- Enhanced logging in `LoggingElement`
- Better error hints when `.parameter()` is used incorrectly
- Fixed device mismatch in `OffscreenRenderer.render`
- Marked `Node` and `System` as `final`
- Concurrency cleanups: removed `@preconcurrency`, fixed Sendable conformances

---

## 0.1.4

- Updated `swift-tools-version` and platform deployment targets

---

## 0.1.3

### MSAA Support

- Added full MSAA (Multisample Anti-Aliasing) support
- New `.metalSampleCount()` modifier now works correctly with `RenderView`
- `RenderPipeline` and `MeshRenderPipeline` automatically infer `rasterSampleCount` from render pass textures
- New `.msaa(sampleCount:)` element modifier for render-to-texture MSAA scenarios
- `RenderView` now detects sample count changes and triggers pipeline recreation

### ARKit Integration

- Added ARKit camera session support for iOS

### Documentation

- Added DocC documentation with tutorials
- Documentation hosted on GitHub Pages

### Other

- Removed MetalSprocketsSnapshotUI module

---

## 0.1.2

### visionOS Support

- Full visionOS immersive scene support
- Fixed visionOS-specific issues
- Improved CI for iOS and visionOS

### Bug Fixes

- Fixed command buffer completion handler issues

---

## 0.1.1

### Major Changes

- Initial visionOS 26 immersive rendering support
- Removed `@MainActor` requirements for better concurrency
- Improved test serialization and stability

### Architecture

- Made `System` properties read-only externally
- Switched to `TaskLocal` for global current System
- Shader types now `Equatable`

### Bug Fixes

- Fixed `RenderPassDescriptorModifier` to read fresh descriptor each frame
- Fixed `RenderPipelineDescriptorModifier` timing issues
- Golden image test infrastructure improvements

---

## 0.1.0

Initial release.
