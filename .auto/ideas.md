# Ideas backlog

Ranked roughly by uncovered lines per unit of effort. Numbers are from the run at ~88% line coverage.

- **Parameters.swift (27)** — the ambiguous-name precondition, the missing-binding throw, buffer/sampler/texture
  and array value kinds, and the compute-encoder rejection of non-kernel stages. Golden-testable: bind the same
  uniform to different stages and check the rendered result.
- **VisibleFunctionTableModifier (27)** — visible function tables, linked functions, the setup and workload
  halves. A golden image of a shader dispatching through a function table would assert real behaviour.
- **SystemSnapshot (25)** and **System+Snapshot (11)** — `textDump` variants, environment inclusion, dirty
  markers, node hierarchies with state. Pure data, easy to assert exactly.
- **ShaderLibrary (23)** — namespaced lookup failures, the debug.metallib branch, compile-options paths,
  `ID` equality, cache adoption by a `ShaderStore`.
- **RenderPipeline (19)** — the cache-miss/cache-hit split, linked functions, the depth-stencil build branch,
  and the new cross-device check (`ShaderDeviceCheck`).
- **EnvironmentValues (16)** — storage parent chains, `transformEnvironment`, debug description.
- **OffscreenVideoRenderer (15)** — writing a short video and checking frame count/dimensions.
- **UVEnvironmentValues+Implementation (13)** — `colorAttachment0`/`depthAttachment`/`stencilAttachment` and the
  Model I/O vertex descriptor overload.
- **StateBox (12)** — dependency pruning when nodes die, late writes through a binding after teardown (#331).
- **Error.swift (12)** — `orThrow`/`orFatalError` variants and `MS_FATALERROR_ON_THROW` gating, now reachable
  through `SystemEnvironment.$current`.
- **ComputePass (10)** — compute pipeline cache hits, threadgroup sizing, a golden image of a compute-written
  texture.
- **DynamicProperty (10)** — the property-visiting machinery, including elements with several wrappers.
- **Logging (MetalSprocketsUI 12 at 0%, Support 11)** — the `Logger.verbose` gate is per-call and reachable via
  `SystemEnvironment.$current`; the module-level `logger` globals latch at first use and are not.

Golden-image candidates not yet written:
- Blend modes via `renderPipelineDescriptorModifier` beyond the existing two.
- `ForEach` drawing N instances, to pin down structural identity across a changing collection.
- A compute pass writing a gradient, rendered or read back directly.
- Stencil attachment behaviour.
- MSAA — blocked on #354.
