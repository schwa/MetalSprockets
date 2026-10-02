# RFC 0005 — Metal 3 / MPS work inside a Metal 4 submission

**Status:** Draft
**Author:** schwa
**Date:** 2026-09-30
**Issue:** #451

## Problem

Elements receive only an `MTL4CommandBuffer`. MPS compatibility depends on the kernel family, as checked against the OS 27 SDK:

- `MPSNDArray` kernels have `encode(withMTL4CommandEncoder:…)` and already work inside a `ComputeCommand`
  (`MPSInteropTests`). They are out of scope.
- MPSGraph runs on an `MTL4CommandQueue` but commits its own work, so it cannot join a submission.
- Image kernels (for example `MPSImageGaussianBlur.encode(commandBuffer:sourceTexture:destinationTexture:)`) accept
  only a Metal 3 `MTLCommandBuffer`. This RFC is about these.

An element cannot solve this with its own Metal 3 queue. Elements encode the Metal 4 command buffer before the root commits it.
Work committed on another queue at that point runs before earlier passes produce its inputs.
The root owns commit, so an element cannot control that ordering.

Each submission contains one `MTL4CommandBuffer`.
`Metal4Context.commit` calls `commandQueue.commit([commandBuffer])`, then `signalEvent(completionEvent, value: identifier)`.

## Options

### A. Document MPS as unsupported

Say so in `Porting-to-Metal4.md`. Clients port MPS image kernels to compute shaders, as MetalSprocketsAddOns did for
`GaussianBlurPipeline`.

- No library change.
- Each MPS client must port its kernels. CNN, matrix, and image-statistics kernels can require substantial work.

### B. Split the submission around Metal 3 work

Add an element that hands a Metal 3 command buffer to a closure:

```swift
RenderPass { … }                       // segment 1 (Metal 4)
Metal3Command { commandBuffer in       // Metal 3, ordered between segments
    blur.encode(commandBuffer: commandBuffer, sourceTexture: color, destinationTexture: blurred)
}
RenderPass { … }                       // segment 2 (Metal 4)
```

Recording:

1. When `Metal3Command` runs, the recorder ends the current `MTL4CommandBuffer` (segment N) and starts segment N+1.
2. It creates an `MTLCommandBuffer` on a context-owned Metal 3 queue, encodes `waitForEvent(interop, N)`, runs the
   closure, then encodes `signalEvent(interop, N + 1)`. Nothing is committed yet.

Commit, in order, for each segment:

1. Metal 4 queue: `waitForEvent(interop, previous value)` if a Metal 3 buffer precedes it, commit the segment, then
   `signalEvent(interop, N)`.
2. Metal 3 queue: commit the Metal 3 command buffer for that boundary.

Discarding a recording drops the uncommitted Metal 3 buffers, which is safe.

Costs and open questions:

- This option gives a submission several `MTL4CommandBuffer`s. The current runner submits one command buffer and retains its allocator through GPU completion.
- The `Submission` result must include Metal 3 buffer status and errors. Without an extension, `gpuDuration` covers only the Metal 4 segments.
- Metal 4 barriers do not cross queues, so the event is the only ordering. Every boundary costs a queue round trip.
- Textures shared across the boundary must stay resident for Metal 4 and alive until both queues finish.
- `Metal3Command` inside a pass is an error: it must sit between passes.
- Presentation and `.gpuCounters` need checking with more than one segment.

### C. Ship compute replacements for common MPS kernels

Provide Metal 4 elements for common MPS kernels, such as Gaussian blur, Sobel, and image scaling.
This complements option A but does not solve the general case.

## Recommendation

Use option A now. The porting guide's "MetalPerformanceShaders" section describes NDArray support and directs image-kernel users to compute replacements.
If a second MPS-dependent client needs interop, use option B as the design basis.
It is the only option that preserves ordering. It also changes the single-command-buffer assumption in encoding, completion, and timing.
