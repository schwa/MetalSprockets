# RFC 0001 — MetalFX Temporal Upscaling

**Status:** Draft
**Author:** schwa
**Date:** 2026-04-17

## Summary

Add a `MetalFXTemporal` element wrapping `MTLFXTemporalScaler`, mirroring
the existing `MetalFXSpatial` element. Temporal upscaling accumulates
information across frames using motion vectors and sub-pixel jitter,
producing significantly better image quality than spatial upscaling at
low input resolutions (0.25× and below).

## Motivation

`MetalFXSpatial` already exists and is used to trade resolution for
perf. At low input resolutions (≤ 0.5×) spatial upscaling introduces
visible blur on thin features and high-contrast edges. Temporal
upscaling is the industry-standard next step: it uses prior-frame
history, per-pixel motion vectors, and a jittered projection to
reconstruct detail that would otherwise be lost.

For MetalSprockets' use cases — rasterized scenes with available motion
vectors, or ray-marched scenes that can synthesize them — temporal is
often the cheapest way to stay at 60 fps when the fragment shader is
expensive (e.g. SDF scenes with many primitives).

## Non-goals

- Automatic jitter / motion-vector generation. Callers compute and pass
  these; we're not offering a higher-level "just make my scene temporal"
  abstraction.
- Reactive mask / transparency mask support. Can be added later.
- Convenience over `MTLFXFrameInterpolator` (different feature; its own
  RFC when we want it).

## Proposed API

Mirroring `MetalFXSpatial`, with the additional inputs temporal
requires:

```swift
public struct MetalFXTemporal: Element {
    public init(
        inputTexture: MTLTexture,     // low-res color
        depthTexture: MTLTexture,     // low-res depth
        motionTexture: MTLTexture,    // low-res motion vectors
        outputTexture: MTLTexture,    // upscaled color
        jitter: SIMD2<Float> = .zero, // sub-pixel offset applied to projection
        reset: Bool = false           // discard history this frame
    )

    public var body: some Element { ... }
}
```

### Input conventions

- **Motion vectors**: per-pixel displacement from the *previous* frame
  position to the *current* frame position, in **input-texture pixels**.
  Pixel format should be 2-channel float (`.rg16Float` works well).
  Zero motion = static pixel.
- **Jitter**: the sub-pixel offset (in input pixels, typically in
  `[-0.5, 0.5]` on each axis) that the caller applied to their projection
  matrix for this frame. The scaler uses this to correctly resolve the
  jittered samples against history. A Halton `(2, 3)` sequence is the
  standard choice.
- **Reset**: set `true` for one frame whenever scene topology, camera,
  or projection parameters change in a way that invalidates history
  (e.g. camera teleport, scale change, render-settings flip). The scaler
  clears its history and starts fresh.

### Scaler lifecycle

- Created on `onSetupEnter` from the descriptor. Cached in `@MSState`
  across frames so history persists.
- Recreated on `onWorkloadEnter` if any of the input/output dimensions
  change, matching the pattern in `MetalFXSpatial`.
- Encoded directly on the current command buffer from the environment.

### Error surface

- Fails with `MetalSprocketsError.resourceCreationFailure` if the scaler
  can't be created (wrong texture formats, unsupported device, etc.).
- Does not validate that `motionTexture` contains reasonable data; silly
  inputs produce smearing / ghosting but don't error.

## Implementation sketch

A single new file, `Sources/MetalSprockets/Metal/MetalFXTemporal.swift`,
structured identically to `MetalFXSpatial.swift`:

1. `@MSState var scaler: MTLFXTemporalScaler?`
2. `AnyBodylessElement().onSetupEnter { ... }.onWorkloadEnter { ... }`
3. Descriptor stores color/depth/motion/output pixel formats +
   dimensions and builds the scaler on demand.
4. `onWorkloadEnter` recreates the scaler when input or output
   dimensions change between frames.

The `@MSEnvironment(\.commandBuffer)` pattern gives us the current
command buffer to encode into, same as spatial.

## Caller responsibilities

Using this element correctly will require a fair bit of work on the
caller's side. We should document these in the API comments and provide
an example in `MetalSprocketsExamples`:

1. **Allocate three extra textures** at low-res: color, depth, motion.
   The depth and motion textures must live alongside the color target.
2. **Jitter the projection matrix** every frame using a consistent
   low-discrepancy sequence. Pass the same jitter into the scaler.
3. **Write motion vectors** from your fragment shader. For rasterized
   scenes, emit `current_clip.xy - previous_clip.xy` per vertex and
   convert to pixel delta in the fragment. For ray-marched scenes,
   approximate with camera-only motion (sufficient for static scenes)
   or track per-object transforms (correct but expensive).
4. **Reset the scaler** on any change that breaks history continuity.
   Scaler silently accepts stale history and produces smearing
   otherwise.
5. **Respect the minimum input size** (~192×192 on current hardware).
   Below this `makeTemporalScaler` returns `nil`.

## Interaction with existing API

- `MetalFXSpatial` stays as-is. They share neither code nor a protocol;
  callers choose one or the other.
- Both expect to be composed inside `RenderView` or `OffscreenRenderer`
  that has set up a command buffer environment.
- Both allocate internal resources on setup; swapping between them at
  runtime requires view reconstruction (same as spatial).

## Anticipated pitfalls

A few integration issues likely to bite first-time callers. Worth
surfacing here so docs + examples can address them proactively.

### Two fragment entry points

For shaders that write motion vectors, we recommend a **separate
fragment entry point** rather than a runtime flag. The motion variant's
pipeline has two color attachments (color + motion) vs. the
non-temporal variant's one; Metal pipeline state is fixed at
compile/link time, so there's no single shader that can do both. A
Swift-side `enum Variant { case color, colorAndMotion }` selects the
appropriate entry point and the matching render-pass descriptor.

### Jitter math for Metal-style projection

The standard jitter trick for a Metal-native perspective matrix is:

```swift
proj.columns.2.x += 2 * jx / Float(inputWidth)
proj.columns.2.y += 2 * jy / Float(inputHeight)
```

This shifts clip-space x/y by `(jx, jy)` in input-pixel units after the
perspective divide. Halton `(2, 3)` over a 64-frame cycle is a
reasonable default.

### Multi-attachment render pass incompatibility

A motion-writing fragment pipeline has two color attachments. External
rasterized overlays (grid shaders, debug line renderers, etc.) are
single-attachment pipelines and cannot share a render pass with the
motion-writing pipeline. Callers have two options:

- Render overlays **after** the upscale, at full resolution, in a
  separate render pass. Keeps overlays crisp; costs one extra pass.
- Give the overlay its own motion-writing variant. Expensive to retrofit
  for third-party elements.

Our existing `MetalFXSpatial` path has no such problem because its
pipeline is single-attachment. Docs should call out that switching from
spatial to temporal may force callers to restructure their render-pass
graph.

### Per-frame state is caller-owned

Jitter counter, previous view-projection matrix, and reset flag are all
caller-managed. MetalSprockets deliberately does **not** own a per-view
"temporal state" concept — it'd couple the rendering core to scene graph
assumptions. Callers that want convenience can build it on top.

### ElementBuilder and per-frame side effects

`ElementBuilder` does not tolerate Swift statement-level mutations
(side-effectful ifs, assignments) between elements. Callers that need to
advance per-frame state mid-build (e.g. increment a jitter counter,
update a `previousVP` cache) have to do it outside the builder body or
via a ternary-wrapped no-op expression. Minor ergonomic papercut; worth
documenting alongside the temporal example so the workaround is
discoverable.

## Future work

- A reactive-mask texture parameter for marking transparent / fast-moving
  pixels.
- Frame-interpolation wrapper via `MTLFXFrameInterpolator`.
- A higher-level "auto-temporal render view" that tracks camera matrix
  and motion for you. Questionable whether MetalSprockets should go
  there — it couples too tightly to scene graph assumptions. Probably
  lives in an addons package or a sample app, not core.
