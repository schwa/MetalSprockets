# RFC 0003 — Parameter Bindings via `.bindings(...)`

**Status:** Draft
**Author:** schwa
**Date:** 2026-04-18
**Depends on:** RFC 0002 (Metal 4) — Steps 0–2 landed; this is the
deferred "Step 2d" from that RFC.

## Summary

Replace the hand-built `MTL4ArgumentTable` usage in user `Draw` /
`ComputeDispatch` closures with a reflection-driven
`.bindings(...)` modifier on `RenderPipeline` / `ComputePipeline`.

Before:

```swift
RenderPipeline(vertexShader: vs, fragmentShader: fs) {
    Draw { encoder, state in
        encoder.setRenderPipelineState(state)
        encoder.setArgumentTable(vertexArgumentTable, stages: .vertex)
        encoder.setArgumentTable(fragmentArgumentTable, stages: .fragment)
        encoder.drawPrimitives(primitiveType: .triangle,
                               vertexStart: 0, vertexCount: 3)
    }
}
```

After:

```swift
RenderPipeline(vertexShader: vs, fragmentShader: fs) {
    Draw { encoder in
        encoder.drawPrimitives(primitiveType: .triangle,
                               vertexStart: 0, vertexCount: 3)
    }
}
.bindings(
    .buffer("vertices", vertexBuffer),
    .texture("gradient", gradientTexture),
    .sampler("linearSampler", linearSampler)
)
```

## Why

Today users have to:

1. Build one `MTL4ArgumentTable` per stage, sized by hand.
2. Remember which slot index each shader binding uses.
3. Call `setArgumentTable(_:stages:)` inside `Draw` closures.
4. Repeat for `ComputeDispatch`.

Reflection provides the information for these repetitive operations.
Metal 4 pipeline state exposes `reflection.vertexBindings`,
`fragmentBindings`, and `bindings`, each an array of `MTLBinding` with
`name`, `index`, and `type` (`.buffer` / `.texture` / `.sampler` / …).
The framework can resolve each name to a stage and slot, then write the binding.

## Design

### Shape

A **variadic modifier** on `RenderPipeline` / `ComputePipeline`:

```swift
public enum Bind {
    case buffer(_ name: String, _ buffer: any MTLBuffer)
    case texture(_ name: String, _ texture: any MTLTexture)
    case sampler(_ name: String, _ sampler: any MTLSamplerState)
}

public extension RenderPipeline {
    func bindings(_ bindings: Bind...) -> RenderPipeline { ... }
    func bindings(_ bindings: [Bind]) -> RenderPipeline { ... }
}

public extension ComputePipeline {
    func bindings(_ bindings: Bind...) -> ComputePipeline { ... }
    func bindings(_ bindings: [Bind]) -> ComputePipeline { ... }
}
```

`.bindings(...)` applies only to `RenderPipeline` / `ComputePipeline`. It is **not** an `Element` extension.
Attaching it to `RenderPass`, `Draw`, `Group`, or another element produces a compile error.
This prevents bindings at the wrong level.
Internally, each pipeline gains a private `bindings: [Bind]` field. The modifier returns a new pipeline value with that field populated.

The design uses variadic arguments rather than a result builder. This needs less implementation code for the common flat list.
The array overload supports conditional and loop-generated bindings:

```swift
.bindings([
    .buffer("vertices", vertexBuffer),
    hasLighting ? .buffer("lights", lightsBuffer) : nil,
].compactMap(\.self))
```

If callers need builder syntax later, `@BindingBuilder` can coexist with the variadic form.

### Naming

- `Bind` — avoids collision with SwiftUI's `Binding<Value>` and with
  Metal's `MTLBinding` protocol.
- `.bindings(...)` (plural modifier) — reads naturally, matches the
  underlying `MTLBinding` array.

### Where the work happens

**Setup phase** (once per pipeline, or when shaders change):

1. `RenderPipeline.setupEnter` already builds the
   `MTLRenderPipelineState` via `MTL4Compiler`. It now also sets
   `MTL4PipelineOptions.shaderReflection = .bindingInfo`.
2. Walk `reflection.vertexBindings` / `fragmentBindings`
   (or `reflection.bindings` for compute), producing a
   `name → (stage, MTLBindingType, index)` map.
3. Compute per-stage max buffer/texture/sampler slot counts.
4. Create one `MTL4ArgumentTable` per stage that has any bindings,
   sized to those maxima. Store on the node's environment.
5. Store the slot map on the node's environment.

**Workload phase** (every frame, in `RenderPipeline` / `ComputePipeline`
`workloadEnter`, *before* children run):

1. Read the slot map and argument tables from the environment.
2. Read `[Bind]` from the environment (populated by `.bindings(...)`).
3. For each `Bind`, resolve `name → (stage, type, index)` and write
   the right `setAddress` / `setTexture` / `setSamplerState` call on
   the right table.
4. Call `encoder.setArgumentTable(_:stages:)` for each populated table.
5. Call `encoder.setRenderPipelineState(_:)` /
   `setComputePipelineState(_:)`.
6. Children's `Draw` / `ComputeDispatch` closures run with the encoder
   already fully configured.

### `Draw` / `ComputeDispatch` simplification

Closure signatures drop the pipeline-state argument:

```swift
// Before:
Draw { encoder, state in ... }
ComputeDispatch { encoder, state in ... }

// After:
Draw { encoder in ... }
ComputeDispatch { encoder in ... }
```

`state` was only ever used by user code to call `setRenderPipelineState`
/ `setComputePipelineState`, which the framework now does.

### Auto-residency

Every resource passed via `.bindings(...)` is registered with the
enclosing `CommandBufferLifecycle`'s root residency set during setup.
The existing `.useResource(_:)` modifier covers resources that the GPU reads without a named argument binding.

### Missing / extra bindings

- **Missing binding:** If reflection expects a name that the caller omits, throw during setup rather than produce undefined fragment output.
- **Extra binding:** If the caller supplies a name absent from the shader, throw during setup. A shader rename can cause this error.
- **Duplicate name in `.bindings(...)`:** The last value wins, with a warning. An error is another option. The proposed warning permits switching code paths during development.

### Out of scope for v1

1. **Per-draw binding overrides.** `Draw { encoder in ... }.bindings(...)`
   does not exist. Bindings live at the pipeline level. If different
   draws need different bindings, use separate `RenderPipeline` blocks
   or write the argument table by hand inside `Draw`.
2. **`.value("name", someEquatable)`** — bind arbitrary CPU-side values
   by copying them into a scratch buffer. Needs a per-frame bump
   allocator on the lifecycle; covered by a follow-on RFC.
3. **Argument-table sharing across pipelines.** Each pipeline builds
   its own tables. If two pipelines share binding shapes, they each
   get separate tables. Sharing is a Step 5 optimization.
4. **Function constants / specialization.** Separate work in RFC 0002, Step 5.
5. **Namespaced bindings / structs.** Bindings are flat `(name,
   resource)` pairs. Named struct members (`.foo.bar`) get pushed to
   a later RFC.

## Worked example — HelloTriangle

```swift
var body: some View {
    RenderView { _, _ in
        let kernel:  ComputeKernel  = try library.gradient_kernel
        let vs:      VertexShader   = try library.vertex_main
        let fs:      FragmentShader = try library.fragment_main

        try Group {
            ComputePass {
                ComputePipeline(computeKernel: kernel) {
                    ComputeDispatch { encoder in
                        encoder.dispatchThreads(
                            threadsPerGrid: MTLSize(width: 256, height: 256, depth: 1),
                            threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1)
                        )
                    }
                }
                .bindings(
                    .texture("output", gradientTexture),
                    .buffer("time", timeBuffer)
                )
            }
            .barrier(afterStages: .dispatch, beforeStages: .fragment)

            RenderPass {
                RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                    Draw { encoder in
                        encoder.drawPrimitives(primitiveType: .triangle,
                                               vertexStart: 0, vertexCount: 3)
                    }
                }
                .bindings(
                    .buffer("vertices", vertexBuffer),
                    .texture("gradient", gradientTexture),
                    .sampler("linearSampler", linearSampler)
                )
            }
        }
    }
}
```

The example removes six lines of argument-table code and three argument tables.
Callers need shader binding names rather than argument-table indices, stage routing, and residency-set details.

## Implementation notes

- Pipeline reflection on Metal 4 requires
  `MTL4PipelineOptions.shaderReflection = .bindingInfo`; set it when
  we build pipelines. The `MTLRenderPipelineState.reflection` property
  is only populated when that flag was set at build time.
- `MTL4ArgumentTable` has `setAddress(_:index:)`,
  `setTexture(_:index:)`, `setSamplerState(_:index:)` — direct 1-to-1
  mapping from `Bind` cases.
- Argument-table sizing: `MTL4ArgumentTableDescriptor` takes
  `maxBufferBindCount` (≤31), `maxTextureBindCount` (≤128),
  `maxSamplerStateBindCount` (≤16). Size to the maximum slot index + 1
  we actually see in reflection, per stage.
- Argument tables are set on the encoder in
  `RenderPipeline`/`ComputePipeline`'s `workloadEnter`, after the
  render/compute pass has created its encoder and before any child
  elements run.

## Risks

- **Reflection names != symbol names.** Metal reflection returns the
  name as it appears in the MSL source (`[[buffer(0)]]` declarations
  etc.). If users rename a shader parameter, their `.bindings(...)`
  call breaks. Error message at setup needs to list the names
  reflection actually saw, so the fix is obvious.
- **Stage sharing.** A buffer named `uniforms` can appear in both vertex and fragment stages. The framework writes it to both tables.
  Its slot can differ between stages, so the map uses `(stage, name)` as the key, not `name` alone.
- **Forgetting `.bindings(...)`.** If the user passes none and the
  shader expects some, setup throws. If the shader expects none and
  the user passes some, setup throws. If both are empty, everything
  needs no binding work.

## Future: compile-time safety via codegen

The v1 design uses string keys and validates bindings through reflection during pipeline setup.
It catches missing bindings and name mismatches on the first frame after a shader change.
Compile-time validation requires Swift types that represent the bindings declared in the `.metal` file.

The path: a SwiftPM build plugin (extending `MetalCompilerPlugin`)
parses the `.metal` sources (or consumes `xcrun metal --reflection`
JSON) and generates a Swift file with typed constructors on `Bind`:

```swift
// Generated — do not edit:
public extension Bind {
    /// vertex_main([[buffer(0)]] vertices)
    static func vertex_main_vertices(_ buffer: any MTLBuffer) -> Bind {
        .buffer("vertices", buffer)
    }
    /// fragment_main([[texture(0)]] gradient)
    static func fragment_main_gradient(_ texture: any MTLTexture) -> Bind {
        .texture("gradient", texture)
    }
    /// fragment_main([[sampler(0)]] linearSampler)
    static func fragment_main_linearSampler(_ sampler: any MTLSamplerState) -> Bind {
        .sampler("linearSampler", sampler)
    }
}
```

Users migrate one call site at a time:

```swift
// v1, string-keyed:
.bindings(
    .buffer("vertices", vertexBuffer),
    .texture("gradient", gradientTexture),
    .sampler("linearSampler", linearSampler)
)

// After codegen, same meaning, compile-checked:
.bindings(
    .vertex_main_vertices(vertexBuffer),
    .fragment_main_gradient(gradientTexture),
    .fragment_main_linearSampler(linearSampler)
)
```

The generated forms coexist with the hand-written forms, so users can
mix and match while migrating. Renaming a shader binding becomes a
compile error at every call site the codegen touches. The type of the
argument (`MTLBuffer` vs `MTLTexture` vs `MTLSamplerState`) is also
checked — passing the wrong kind of resource is no longer possible.

This is deliberately deferred to a follow-on RFC because:

- Real implementation cost. Parsing MSL, plumbing the generated file
  through `MetalCompilerPlugin`, handling multi-library projects.
- v1's runtime check is already a large improvement over today's
  hand-built argument-table code.
- The string-keyed v1 and the codegen form share one mental model and
  one type (`Bind`). No throwaway surface.

Generated types still cannot distinguish two buffers with the same type, such as vertex buffer A and vertex buffer B.
Passing the wrong one remains a semantic error.

The separate RFC 0004 will track this work.

## Alternatives considered

- **Chained `.parameter(...)` modifiers.** Each modifier wraps the
  element. 10 parameters = 10 wrapper nodes. Verbose tree, reflection
  runs once per modifier unless we cache. Rejected.
- **`@BindingBuilder` result builder.** Nicer syntax for conditionals
  but overkill for the common flat case. Can be added later as a
  source-compatible expansion. Rejected for v1.
- **Per-draw bindings.** Changes the mental model (pipeline = binding
  scope vs draw = binding scope). Pipeline-scoped is closer to how
  Metal 4 argument tables actually work and how users think about
  shader I/O. Rejected for v1.

## Rollout

One commit contains this RFC. RFC 0004 covers code generation.

One commit:

- `Bind` enum and `.bindings(...)` modifier (with array overload).
- Reflection walk in `RenderPipeline` / `ComputePipeline` setup,
  argument-table construction.
- Slot map + auto-bind in `RenderPipeline` / `ComputePipeline`
  workload.
- Drop `state` from `Draw` / `ComputeDispatch` closures.
- Update HelloTriangle experiment to the new shape; runtime-verify.
- Unit test coverage on the slot-resolution path (pure reflection →
  map).
