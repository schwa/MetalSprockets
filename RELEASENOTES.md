# Release Notes

## Unreleased (since 0.1.2)

### MSAA Support

- Added full MSAA (Multisample Anti-Aliasing) support
- New `.metalSampleCount()` modifier now works correctly with `RenderView`
- `RenderPipeline` and `MeshRenderPipeline` automatically infer `rasterSampleCount` from render pass textures
- New `.msaa(sampleCount:)` element modifier for render-to-texture MSAA scenarios
- Fixed `System.update()` to preserve `needsSetup` flags set by `markAllNodesNeedingSetup()`
- `RenderView` now detects sample count changes and triggers pipeline recreation

### Documentation

- Added comprehensive DocC documentation with tutorials
- New step-by-step tutorials: Rainbow Quad, 3D Spinning Cube
- Improved README structure and content
- Documentation now hosted on GitHub Pages

### ARKit Integration

- Added ARKit camera session support for iOS
- New `ARViewModel` for managing AR sessions
- Refactored AR and rendering views

### Example App

- Added MSAA toggle with device-supported sample count picker
- Added pause/play animation controls
- Added frame step button when paused
- New `MSAADemoView` for side-by-side MSAA comparison

### Other

- Removed MetalSprocketsSnapshotUI module
- Various code cleanup and refactoring

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
