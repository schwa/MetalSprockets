# Release Notes

## 0.2.3

### Performance

Per-frame CPU cost is much lower for scenes with many draw elements. See [RFC 0006](RFCs/0006-frame-cpu-performance.md).

- Cheaper reconciliation: cached structural-identifier hashes, reuse of previous nodes without lookups, and no removed-node diff when every node is reused (#497).
- Element equality uses cached per-type `Equatable` facts. Elements that can never be equal skip reflection (#495, #506).
- Dynamic-property reflection is skipped for element types that have none (#496).
- Chained `.parameter()` modifiers and mixed chains of workload-only modifiers (parameters, draw state, depth bias, scope) collapse into one node.
- Environment `setValue` updates one key in place (#498). Typed environment boxes (#515).
- Argument tables no longer allocate per-draw dictionaries or arrays. Table labels are precomputed (#514).

### Profiling and timing

- New `.gpuTimed(_:)` and `.onGPUTimings(_:)` for pass-level GPU timings. The FPS HUD shows them (#448).
- New `CPUPhaseTimings` exposes per-phase CPU timings (on `FrameTiming` and `OffscreenRenderer.Rendering`). The FPS HUD shows them (#488).
- Shared signposter with Frame/Drawable/Content/Commit/pass intervals and skipped-frame events (#508–#512).

### Other

- Removed the deprecated `MetalSprocketsError.missingEnvironment(_: PartialKeyPath)` (#494).
- Dependencies pinned to the latest versions. Non-swiftlang packages use `upToNextMinor`.
- Example: instanced-cubes vs `ForEach` toggle, cube-count picker, grouped FPS HUD layout (#502, #504).

## 0.2.2

- New `submissionIndex` and `maximumInFlightSubmissions` environment values, so elements can pick per-frame resources (#485).
- `RenderView` defaults `preferredFramesPerSecond` to the screen maximum.

## 0.2.1

- New `.linkedFunctions(_:functionType:)` links functions into only the vertex or fragment stage of a `RenderPipeline`. `.linkedFunctions(_:)` still links into both (#383).
- New `.parameters { }` binds several shader parameters with one modifier (#480).
- New `RenderView.metalWantsExtendedDynamicRangeContent(_:)` modifier.
- `ImmersiveRenderContent`: `foveation` option (default on) and `onRenderLoopChange` callback. Render loop failures are always logged.
- `OffscreenRenderer` and `OffscreenVideoRenderer`: `clearDepth` option (use 0 for reverse-Z).
- Residency release is deferred, which removes per-frame residency-set churn.
- Reconciliation no longer re-compares whole subtrees at each container (#479).
- Missing environment values are named with stable strings (#461).
- Fixed a priority inversion in `MetalContext.waitForResult`.
- Fixed immersive frames skipped during world-tracking startup not ending their submission.
- `FrameTimingView`: FPS colour no longer flashes at half refresh rate (#397).

## 0.2.0

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
- New `.useResourceCollection(_:)` and `.useResidencySet(_:)` attach persistent residency (#474).
- Automatic threadgroup sizing defaults to 1D.

## 0.1.15

- Updated MetalCompilerPlugin to 0.3.0.
- Fixed `endSubmission` on an invalidated frame when leaving an immersive space.

## 0.1.14

- Updated MetalCompilerPlugin to 0.2.0.

## 0.1.13

- Release builds no longer embed development-only Metal shader source (#395).

## 0.1.12

- `.gpuCounters` adds a vertex/fragment stage breakdown and supports compute passes (#393).
- `OffscreenRenderer.Rendering` exposes command-buffer GPU time (#394).
- Fixed a crash when setting `@MSState` from `onCommandBufferCompleted` (#392).
- Updated MetalSupport to 1.0.5.

## 0.1.11

### New

- `.gpuCounters` modifier for GPU counter sampling (#50).
- `.depthBias()`, `.debugGroup()`, `.id()` (#187) and `.transformEnvironment()` (#282) element modifiers.
- `useComputeResources` array variant (#350).
- Indirect dispatch in `ComputeDispatch` (#351). `threadsPerThreadgroup` is derived automatically (#328).
- `FunctionTypes` option set for multi-stage parameter binding.
- Public `MSDynamicProperty` protocol (#42).
- `RenderView` takes `colorPixelFormat`, `depthStencilPixelFormat` and `sampleCount`. Render attachment formats are published in the environment, and `RenderPipeline` reads them (#362, #363).
- Metal logging and the command buffer descriptor are per-subtree environment values (#360, #361).
- `ShaderLoader` port for shader function lookup. Shader libraries can choose their device and catch mismatches.
- `@Observable` reads during body evaluation are tracked.
- FPS is colour-coded against the target frame rate.

### Changes

- `renderPipelineDescriptorModifier` renamed to `renderPipelineDescriptorTransformer` (#260).
- `BodylessElement` split into `SetupElement` and `WorkloadElement`.
- The environment is now a value type, not a parent chain.
- Clean subtrees are skipped during update (#367–#371). `ForEach` children get identity from their data ids (#209).
- `System.render(root:)` is the single phase-ordered entry point (#374).
- `MTKView` depth/stencil textures default to memoryless storage.
- `RenderView` pauses and detaches its `MTKView` when dismantled.

### Fixes

- `.msaa()` now anti-aliases, and misplacement is diagnosed (#354, #355).
- `.capture()` can write a `.gputrace` document (#356).
- Workload encoders unwind when an error is thrown mid-pass (#357).
- Stale depth-stencil state after the first frame (#358). PSO cache key includes the configured descriptor (#359).
- `Optional` nodes no longer run the wrapped element's phases twice (#381). Collapsed parameters are keyed by name and stage (#382).
- Concurrency and invalidation fixes (#364–#366, #380, #384–#388).
- `RenderView` no longer creates an `MTLCommandQueue` during body evaluation (#344), and resyncs drawable size (#311).
- Visible function tables check `supportsFunctionPointers` (#268).
- Specific error cases in `OffscreenVideoRenderer` (#177).

## 0.1.10

- New `Runner` type for amortized element-tree execution (#345).
- Updated swift-syntax to 602.0.0.

## 0.1.9

### New

- `ShaderStore` replaces the process-global `LibraryRegistry`, with `shaderStore` environment/view modifier API (#339).
- `MetalFXTemporal` element.
- `.capture()` element and `RenderView` modifiers wrapping `MTLCaptureManager`.
- `.linkedFunctions(_:)`, `.workloadEnabled()` (#53) and `.onDisappear` (#214) element modifiers.
- Shader uniforms bind by name via reflection, not hardcoded indices.

### Changes

- Duplicated Metal utilities replaced by the MetalSupport dependency. `MTKMesh+Extensions` moved there (#322).
- `ViewAdaptor` is internal (#104). Less public `System` API.
- Pipelines and MetalFXSpatial use a per-node cache (#319, #327, #333).
- Asserts when an element body returns `any Element` (#248).

### Fixes

- PSO cache never hitting, or rebuilding every frame (#341, #342).
- Depth-stencil state keyed on descriptor contents (#314).
- `ComputePipeline` ignored changes to kernel/linked functions (#327). `visibleFunctionTable` for `ComputePipeline` (#324).
- Data race on `System.dirtyIdentifiers` (#330). Dangling `MSBinding` reference (#331).
- Back-pressure uses an async KVO wait instead of `Thread.sleep` polling (#321).

## 0.1.8

- `ImmersiveRuntime` exposes frame timing statistics (#313).
- Fixed `BlitPass` environment access (#306).
- Demo app UI fixes on iOS/iPad.
- Added Cross-Environment Shader Headers documentation.

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
