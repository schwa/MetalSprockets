# Release Notes

## Unreleased

### Deployment requirements

- Minimum deployment targets are now macOS 26, iOS 26, and visionOS 26.
- CI builds with Xcode 26.6 (the newest on GitHub runners). Development used Xcode 27.
- The public API snapshot (`.public-api.yaml`) is generated with Xcode 27 by `Scripts/api-snapshot.sh`, which pins
  `swift-api-tool`. Buildkite checks the snapshot. GitHub Actions no longer checks it.

### Breaking shader API changes

- Shader wrappers now retain a `ShaderFunction` with library, name, constants, and optional specialized export name.
- Replace raw-function constructors with `try VertexShader(library: library, name: "vertex_main")` or the equivalent typed shader initializer.
- `.function` remains readable but is no longer directly mutable. Custom shaders implement `init(_ reference: ShaderFunction) throws` and provide `reference`.
- Custom `ShaderLoader` implementations now provide `shaderFunction(named:type:constants:)`.
- Linked and visible-function table modifiers now take `VisibleFunction` values, not raw `MTLFunction` objects.
- See [Porting to Metal 4](Documentation/Porting-to-Metal4.md#shaders-and-gpu-timing).
- New `.linkedFunctions(_:functionType:)` links functions into only the vertex or fragment stage of a `RenderPipeline`. `.linkedFunctions(_:)` still links into both (#383).

### Metal 4 backend (breaking)

All rendering now uses Metal 4. There is no Metal 3 fallback. Devices must support `MTLGPUFamily.metal4`.

- `Draw` receives an `MTL4RenderCommandEncoder`, with the pipeline, parameters and draw state already bound. Metal 4 has no `setVertexBytes`/`setFragmentTexture`: use `.vertexValues(_:index:)`, `.vertexBuffer(_:index:)` and `.parameter(...)`. Draw calls are spelled `drawPrimitives(primitiveType:vertexStart:vertexCount:)`.
- `ComputePass`/`ComputeDispatch` keep their structure. `ComputeCommand` provides raw compute access. Commands in a pass are unordered. Add `EncoderBarrier`, `QueueBarrier`, or `.barrierAfterPass(after:beforeQueueStages:)` for dependencies.
- Removed (see [Porting to Metal 4](Documentation/Porting-to-Metal4.md) for replacements): `BlitPass`/`Blit` (use `ComputeCommand`), `CommandBufferElement` (roots own submission; use `Runner.run` or `Runner.submit`), `onCommandBufferScheduled` (use `onSubmissionCommitted`), command-buffer descriptors and `.metalLoggingEnabled(_:)` (use the new `shaderLogging:` root option or `.metalShaderLogging(_:)` on `RenderView`; `MS_METAL_LOGGING=1` still sets the default), `GPUCounterSampler` and `GPUCounterSampleIndex` (use `.gpuCounters(label:_:)`), `MTLFunction`-based shader initializers and linked/visible-function overloads (use `ShaderFunction`/`VisibleFunction`), `Runner(commandQueue: MTLCommandQueue)`, legacy queue, buffer and descriptor modifiers, and the deprecated `renderPipelineDescriptorModifier(_:)` (use `renderPipelineDescriptorTransformer(_:)`). The old names are gone entirely; the compiler reports them as unknown.
- `onCommandBufferCompleted` receives a `SubmissionResult` with the outcome and optional GPU timing. `Runner.submit(_:)` submits immediately and returns a completion handle. `Runner.run(_:)` also waits. Deferred commit, `RecordedSubmission`, and the redundant `recordingIdentifier` are removed.
- `maximumInFlightSubmissions` explicitly limits CPU/GPU overlap (default: 3). At the limit, `Runner` waits, `RenderView` skips frames, and immersive rendering awaits capacity. Command buffers and allocators are recycled only after successful GPU retirement.
- Environment queue, buffer, encoder and descriptor values use Metal 4 types. Descriptor modifiers take `MTL4RenderPassDescriptor`/`MTL4RenderPipelineDescriptor` (blending: `blendingState = .enabled`).
- Samplers bound with `.parameter(_:samplerState:)` need `supportArgumentBuffers = true`.
- Parameter values must be `BitwiseCopyable`. A parameter with no stage filter binds every stage that declares it.
- `.useResource(s)` keeps resources resident and alive. It no longer implies hazard tracking.
- `.capture()` must wrap whole passes. `GPUCounterSample.fragment` is always `nil`. `.depthBias` can wrap a pass. A size-less `ComputeDispatch(threadgroups:)` now uses one SIMD group per threadgroup.
- Visible-function tables that name an unlinked function are an error.
- `YCbCrBillboardRenderPass` takes `owners` (and `init(frameData:)` on iOS) so camera textures outlive GPU use.
- visionOS immersive rendering uses the compositor's Metal 4 queue and requires a device. The simulator reports an error.

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
