# RFC 0001 — MetalFX Temporal Upscaling

**Status:** Draft
**Author:** schwa
**Date:** 2026-04-17

## Summary

Add a `MetalFXTemporal` element around `MTLFXTemporalScaler`, with the same structure as `MetalFXSpatial`.
Temporal upscaling combines information across frames through motion vectors and sub-pixel jitter.
At low input resolutions (0.25× and below), it produces better image quality than spatial upscaling.

## Motivation

`MetalFXSpatial` trades resolution for performance. At low input resolutions (≤ 0.5×), spatial upscaling blurs thin features and high-contrast edges.
Temporal upscaling reconstructs detail from earlier frames, per-pixel motion vectors, and a jittered projection.

MetalSprockets scenes can provide motion vectors through rasterization or ray marching.
For expensive fragment shaders, temporal upscaling is often the least expensive way to maintain 60 fps.
Examples include SDF scenes with many primitives.

## Non-goals

- Automatic jitter or motion-vector generation. Callers calculate and supply both. This RFC does not propose automatic temporal rendering.
- Reactive mask / transparency mask support. Can be added later.
- A wrapper for `MTLFXFrameInterpolator`. This separate feature needs its own RFC.

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
  The recommended pixel format is two-channel float, such as `.rg16Float`.
  Zero motion = static pixel.
- **Jitter**: the sub-pixel offset (in input pixels, typically in
  `[-0.5, 0.5]` on each axis) that the caller applied to their projection
  matrix for this frame. The scaler uses this to correctly resolve the
  jittered samples against history. A Halton `(2, 3)` sequence is the
  standard choice.
- **Reset**: set `true` for one frame whenever scene topology, camera,
  or projection parameters change in a way that invalidates history
  (for example camera teleport, scale change, render-settings flip). The scaler
  clears its history and starts fresh.

### Scaler lifecycle

- Created on `onSetupEnter` from the descriptor. Cached in `@MSState`
  across frames so history persists.
- Recreated on `onWorkloadEnter` if any of the input/output dimensions
  change, matching the pattern in `MetalFXSpatial`.
- Encoded directly on the current command buffer from the environment.

### Error surface

- If scaler creation fails, throws `MetalSprocketsError.resourceCreationFailure`. Causes include incompatible texture formats and unsupported devices.
- Does not validate the contents of `motionTexture`. Invalid motion data produces smearing or ghosting without an error.

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

Callers have the following responsibilities. The proposal includes API comments and a `MetalSprocketsExamples` example that explains them:

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

- `MetalFXSpatial` remains unchanged. The two elements share neither code nor a protocol. Callers choose one.
- Both expect to be composed inside `RenderView` or `OffscreenRenderer`
  that has set up a command buffer environment.
- Both allocate internal resources during setup. Switching between them at runtime requires view reconstruction, as with spatial upscaling.

## Anticipated pitfalls

Documentation and examples need to explain these integration constraints.

### Two fragment entry points

For shaders that write motion vectors, the recommendation is a **separate fragment entry point**, not a runtime flag.
The motion variant uses two color attachments: color and motion. The non-temporal variant uses one.
Metal fixes pipeline state at compile/link time, so one shader cannot serve both configurations.
A Swift-side `enum Variant { case color, colorAndMotion }` selects the entry point and matching render-pass descriptor.

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

The existing `MetalFXSpatial` pipeline uses one attachment and avoids this problem.
Switching to temporal upscaling can require changes to the render-pass graph. The documentation needs to explain this constraint.

### Per-frame state is caller-owned

Callers manage the jitter counter, previous view-projection matrix, and reset flag.
MetalSprockets does **not** own per-view temporal state because that couples the rendering core to scene-graph assumptions.
Clients can add that convenience separately.

### ElementBuilder and per-frame side effects

`ElementBuilder` does not support statement-level mutations between elements, such as assignments or conditional statements with side effects.
Per-frame state changes belong outside the builder body or in a ternary-wrapped no-op expression.
Examples include incrementing a jitter counter and updating a `previousVP` cache. The temporal example needs to document this constraint.

## Future work

- A reactive-mask texture parameter for marking transparent / fast-moving
  pixels.
- Frame-interpolation wrapper via `MTLFXFrameInterpolator`.
- A higher-level "auto-temporal render view" that tracks camera matrix
  and motion for you. Questionable whether MetalSprockets should go
  there — it couples too tightly to scene graph assumptions. Probably
  lives in an addons package or a sample app, not core.
