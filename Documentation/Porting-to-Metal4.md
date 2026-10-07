# Porting to MetalSprockets on Metal 4

MetalSprockets now renders only with Metal 4. This guide covers changes for projects that used an earlier version.
The element model, builders, roots, and most modifiers are unchanged. Most edits are inside `Draw` closures.

Removed APIs are gone, not deprecated: the compiler reports them as unknown names. Use the tables below to find each
replacement.

## Requirements

- macOS 26, iOS 26 or visionOS 26, on a device that supports `MTLGPUFamily.metal4`. There is no Metal 3 fallback.
- visionOS immersive rendering needs a device; the simulator reports an error.

## `Draw` closures

`Draw` now receives an `MTL4RenderCommandEncoder`. The pipeline, parameters and draw state are bound before your
closure runs. Metal 4 encoders have no `setVertexBytes`, `setVertexBuffer` or `setFragmentTexture`.

```swift
// Before
Draw { encoder in
    encoder.setVertexBytes(&vertices, length: MemoryLayout<Vertex>.stride * vertices.count, index: 0)
    encoder.setFragmentTexture(texture, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
}

// After
Draw { encoder in
    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: vertices.count)
}
.vertexValues(vertices, index: 0)          // or .vertexBuffer(buffer, index: 0)
.parameter("texture", texture: texture)    // bound by the shader argument name
```

- Draw calls use Metal 4 labels: `drawPrimitives(primitiveType:vertexStart:vertexCount:)`,
  `drawMeshThreadgroups(threadgroupsPerGrid:threadsPerObjectThreadgroup:threadsPerMeshThreadgroup:)` (was
  `drawMeshThreadgroups(_:threadsPerObjectThreadgroup:threadsPerMeshThreadgroup:)`).
- Vertex amplification: `encoder.setVertexAmplificationCount(viewMappings)` with a
  `[MTLVertexAmplificationViewMapping]`, or `setVertexAmplificationCount(count)` without mappings. The old
  `setVertexAmplificationCount(count, viewMappings: &array)` form does not compile.
- For raw encoder work without a pipeline (for example a compositor mask), use `RenderCommand { encoder in … }`.
- Each `Draw` resets cull mode, triangle fill mode, front-facing winding and vertex amplification count to Metal's
  defaults. Set them inside the closure of every draw that needs them.

### Indexed draws and meshes

`drawIndexedPrimitives` now takes a GPU address and a byte length, not an `MTLBuffer`, and the index buffer must be
resident. Use the `Draw` initializers instead. They calculate both values, check the range, and keep the buffer resident.

```swift
// Before
Draw { encoder in
    encoder.setVertexBuffers(of: mesh)
    encoder.draw(mesh)
}

// After
Draw(mesh: mesh)
    .vertexBuffers(of: mesh)

Draw(primitiveType: .triangle, indexBuffer: indices, indexType: .uint16, indexCount: count)
    .vertexBuffer(vertices, index: 0)
```

If you call `drawIndexedPrimitives` yourself, pass `indexBuffer.gpuAddress + offset` and the byte length, and declare
the buffer with `.useResource(_:usage:stages:)`. Without that, the GPU can read freed memory.

### MetalSupport encoder helpers

The `MTLRenderCommandEncoder` extensions in MetalSupport do not apply to `MTL4RenderCommandEncoder`.

| Before | After |
| --- | --- |
| `encoder.setVertexBuffers(of: mesh)` | `.vertexBuffers(of: mesh)` on the `Draw` |
| `encoder.draw(mesh)` | `Draw(mesh: mesh)` |
| `encoder.setVertexUnsafeBytes(…)` | `.vertexValues(values, index:)` |
| `encoder.withDebugGroup("Label") { … }` | `.debugGroup("Label")` on the element |

## Parameters

- `.parameter(_:value:)`, `.parameter(_:values:)` and `.vertexValues(_:index:)` need `BitwiseCopyable` values.
  For a public generic type from another module, that module must declare the conformance. GeometryLite3D `Packed3<Float>` is one example.
  You cannot add the conformance externally. First, convert the value to a SIMD type or a struct in your module.
- Acceleration structures bind with `.parameter(_:accelerationStructure:)`. Metal 4 encoders have no
  `setAccelerationStructure`.
- A parameter without a stage filter binds every stage that declares the name. Use `functionType:` to target one.
- Samplers must be created with `supportArgumentBuffers = true`.
- Every binding a shader uses must be set; API Validation reports unset ones.

## Compute and copies

`ComputePass`, `ComputePipeline` and `ComputeDispatch` are unchanged. `BlitPass` and `Blit` are gone.

```swift
// Before
BlitPass { Blit { $0.copy(from: source, sourceOffset: 0, to: destination, destinationOffset: 0, size: size) } }

// After
ComputePass {
    ComputeCommand { $0.copy(sourceBuffer: source, sourceOffset: 0, destinationBuffer: destination, destinationOffset: 0, size: size) }
}
.useComputeResources([source, destination], usage: [.read, .write])
```

### MetalPerformanceShaders

Support depends on the kind of MPS kernel.

- **`MPSNDArray` kernels** (`MPSNDArrayUnaryKernel` and `MPSNDArrayMultiaryKernel` subclasses such as
  `MPSNDArrayMatrixMultiplication`) have `encode(withMTL4CommandEncoder:sourceArrays:destinationArray:)` (or
  `sourceArray:`) on OS 27 and later. Call it inside a `ComputeCommand`. Order it after earlier work with
  `EncoderBarrier(after: .dispatch, before: .dispatch)`, and declare the arrays' buffers with
  `.useComputeResources`. Not available in the simulator. An array made with `MPSNDArray(buffer:offset:descriptor:)`
  needs a buffer large enough for MPS's row padding, or `preferPackedRows = true` on the descriptor.

  ```swift
  ComputeCommand { encoder in
      multiply.encode(withMTL4CommandEncoder: encoder, sourceArrays: [a, b], destinationArray: result)
  }
  .useComputeResources([aBuffer, bBuffer, resultBuffer], usage: [.read, .write])
  ```

- **Image kernels** (`MPSImageGaussianBlur` and other `MPSUnaryImageKernel` / `MPSBinaryImageKernel` subclasses)
  encode only into a Metal 3 `MTLCommandBuffer`. They are not supported inside an element tree. Committing them on
  your own Metal 3 queue from inside an element does not work either: that work runs before the earlier passes of
  the same submission. Replace them with compute kernels in a `ComputePass`.
- **MPSGraph** can run on an `MTL4CommandQueue`, but it commits its own work, so it cannot join a MetalSprockets
  submission. Run it outside the element tree.

See `RFCs/0005-metal3-interop.md` for a possible route for image kernels.

Texture copies use `$0.copy(sourceTexture: source, destinationTexture: destination)`, not `copy(from:to:)`.

Buffers you set by index in `onWorkloadEnter` become `.parameter("name", buffer: buffer)` on the dispatch.

## Ordering and resources

Metal 4 does not track hazards between commands.

- Inside one pass, order dependent commands with `EncoderBarrier(after:before:)`.
- Across passes, use `.barrierAfterPass(after:beforeQueueStages:)` on the producer, or `QueueBarrier(after:before:)`
  at the start of the consumer.
- `.useResource(s)` and `.useComputeResource(s)` keep resources resident and alive for the submission. They no
  longer imply ordering. Declare anything a raw closure touches, or a shader reaches through an argument buffer.

A missing barrier does not cause an error. The code builds, validation does not report it, and the output is
usually correct, because the GPU often runs the passes in order anyway. The result is an intermittent race.

**If the rendering looks wrong, check your barriers first.** Without a barrier, the consumer can read the producer's
output before the producer writes it. Then it uses data from an earlier frame. Symptoms:

- The first frame is empty. The buffers have no data yet, so an indirect draw has an instance count of 0.
- The output is one or more frames late, which you see only during motion. With one buffer copy per frame in
  flight, the consumer reads the data from the last time that copy was used.
- Flicker, or the output changes between runs or between machines.

The common case is a compute pass that produces data for a draw, for example a GPU sort or cull followed by an
indirect draw. Put the barrier on the producer, so that every consumer is covered:

```swift
try ComputePass(label: "Sort") {
    // ... dispatches, with EncoderBarrier between dependent dispatches ...
}
.barrierAfterPass(after: .dispatch, beforeQueueStages: .vertex)

try RenderPass {
    try MyPipeline(sortedIndices: indices)   // reads indices and indirect args in the vertex stage
}
```

`.vertex` also covers the read of indirect draw arguments. Use `.fragment` (or `[.vertex, .fragment]`) when only
the fragment stage reads the data, for example a texture that a compute pass wrote.

Ordering also applies in the other direction. If a pass writes a buffer that an earlier pass or an earlier frame
still reads, that is a write-after-read hazard. Buffers reused every frame need either one copy per frame in flight
(see `maximumInFlightSubmissions`) or a barrier before the write.

To check the ordering, take a GPU capture and open the Dependencies view in Xcode. A correct producer and consumer
have a Barrier node (for example "Dispatch → Vertex") and edges between the two encoders. Two encoders with no
edge between them are not ordered.

## Persistent and manual residency

Automatic residency remains the default. Unregistered client resources stay resident until their submitted work retires.

**Automatic residency is for short-lived resources.** It counts the uses of each allocation per submission. When a
frame retires before the next frame commits, the count goes to zero and the allocation is removed from the
residency set. The next frame adds it again. A long-lived buffer (mesh data, a splat cloud, sort scratch) is then
removed and added again every frame. A GPU capture shows this as a block of `removeAllocation` calls and a
`commit`, then a block of `addAllocation` calls and a `commit`, for the same allocations on each frame. Put
anything that lives longer than one frame in a `ResourceCollection`.

Framework-owned scratch buffers, MSAA targets, offscreen targets, stencil targets, and visible-function tables stay resident for their owning lifetime.
`RenderView` keeps its non-memoryless depth/MSAA attachments resident across frames. Resizing or changing the sample count updates that collection.
Replaced attachments stay resident until earlier submissions finish. Drawable textures use the layer's residency set, not this collection.
Externally supplied replacement textures use automatic submission-scoped residency unless explicitly registered.

For persistent client resources, keep a `ResourceCollection` with the resource owner:

```swift
let resources = try ResourceCollection(device: device)
try resources.register(texture)
try resources.register(buffer)
let residency = ResidencyConfiguration(collections: [resources])
let runner = try Runner(device: device, residency: residency)
```

`RenderView(residency: residency) { context, size in ... }` accepts the same configuration.
`runner.residency` changes apply to subsequent submissions. View configuration changes apply to subsequent frames.
Collections, residency sets, and the renderer must use the same device.

Elements can attach a collection from inside the tree, with no root configuration.
Use this when a reusable pipeline owns long-lived buffers:

```swift
MyPipeline(...)
    .useResourceCollection(resources)
```

The collection applies to every submission the subtree encodes into.

When a type owns its buffers (for example one set of buffers per frame in flight, or buffers that grow), give the
type the collection. Register every buffer when you make it. When you replace buffers, unregister the old ones and
register the new ones. Buffers that a submission still uses stay resident until that submission completes.

```swift
final class SortResources {
    let resourceCollection: ResourceCollection
    private(set) var slots: [Slot]

    init(device: any MTLDevice, capacity: Int) throws {
        resourceCollection = try ResourceCollection(device: device)
        slots = try (0..<3).map { _ in try Slot(device: device, capacity: capacity) }
        for buffer in slots.flatMap(\.buffers) {
            try resourceCollection.register(buffer)
        }
    }

    func grow(to capacity: Int, device: any MTLDevice) throws {
        let newSlots = try (0..<3).map { _ in try Slot(device: device, capacity: capacity) }
        for buffer in slots.flatMap(\.buffers) {
            resourceCollection.unregister(buffer)
        }
        slots = newSlots
        for buffer in slots.flatMap(\.buffers) {
            try resourceCollection.register(buffer)
        }
    }
}

// In the element that uses them:
try ComputePass { ... }
    .useResourceCollection(sortResources.resourceCollection)
```

A collection that an element owns can be kept in `@MSState` and made the first time the body runs.
`.useResidencySet(set)` does the same for an externally owned `MTLResidencySet`. The rules for raw sets below apply.

`register` is idempotent. `unregister` removes collection membership immediately.
The collection keeps the resource resident until all submissions that already use it complete successfully.
Encoding failures release resources without submission. Failed or timed-out GPU submissions keep their resources retained and resident.
After collection removal, future uses can still receive automatic submission-scoped residency.

For existing client-owned Metal sets, use `ResidencyConfiguration(residencySets: [set])`.
Resources covered by those sets or collections do not enter the automatic tracker again. Heap membership also covers its resources.
**Commit client-owned sets before encoding. Keep their allocations resident until every submission that uses them completes.**
Unlike a `ResourceCollection`, a raw set cannot defer removals made by the client.

`ResidencyConfiguration(mode: .manual, residencySets: [set])` disables automatic residency for client allocations.
The client must cover every allocation used by its work, including render attachments and indirectly referenced resources.
Framework-owned storage still manages its own residency. Manual mode does not disable retention of declared resources until completion.
Raw encoder closures still require `.useResource(s)` or `.useComputeResource(s)` declarations for lifetime safety.

## Submission and callbacks

`Runner.submit(content)` encodes and submits immediately. `Runner.run(content)` also waits for completion.
There is no deferred-commit object.

```swift
let submission = try runner.submit(content)
let result = try await submission.value()
```

`value()` waits without blocking the caller's actor. GPU errors appear in `result.outcome` rather than as thrown errors.
Canceling this wait throws `CancellationError` but does not cancel the GPU work.
For synchronous code, `try submission.waitUntilCompleted()` returns the result and blocks the calling thread.

`SubmissionResult.recordingIdentifier` is removed. Use `submissionIdentifier`, which identifies commit order within the renderer.

`maximumInFlightSubmissions` is a positive limit that defaults to 3. At the limit:

- `Runner` waits for earlier work.
- `RenderView` skips the frame without blocking.
- `ImmersiveRenderContent` awaits capacity before it starts a compositor submission.

| Before | After |
| --- | --- |
| `CommandBufferElement(completion: .commitAndWaitUntilCompleted)` | `Runner().run(content)` or `content.run()` |
| `CommandBufferElement(completion: .none)`, then commit yourself | `let submission = try runner.submit(content)`; encoding and submission are one operation |
| `.onCommandBufferCompleted { buffer in buffer.gpuEndTime - buffer.gpuStartTime }` | `.onCommandBufferCompleted { result in result.gpuDuration }` |
| `.onCommandBufferScheduled { … }` | `.onSubmissionCommitted { submissionIdentifier in … }` (CPU commit, not GPU start) |
| `.commandBufferDescriptor(…)`, `.metalLoggingEnabled(true)` | `Runner(shaderLogging: .logger)` (also on `OffscreenRenderer`), or `.metalShaderLogging(.logger)` on a `RenderView`. `.handler { message in … }` sends messages to your code. `MS_METAL_LOGGING=1` still sets the default. |

`onCommandBufferCompleted` runs on a completion executor, not your actor. Encoding failures report
nothing. To write `@MSState` (or other isolated state) from the result, use the isolation-aware overload
`.onCommandBufferCompleted(perform:)`, which hops to the calling isolation (for example the `@MainActor`) before
running; the hop is asynchronous.

## Descriptors and environment

- `.renderPassDescriptor(_:)` takes `MTL4RenderPassDescriptor`.
- `.renderPipelineDescriptorTransformer` gives you an `MTL4RenderPipelineDescriptor`. Metal 4 pipeline descriptors
  have no depth or stencil format; those come from the pass.
- `MTL4RenderPipelineColorAttachmentDescriptor` uses `blendingState = .enabled`, not `isBlendingEnabled`, wherever
  you configure it.
- Environment values `commandQueue`, `commandBuffer`, `renderCommandEncoder` and `computeCommandEncoder` are Metal 4
  types. The root owns the queue and command buffer; pass your own queue with `Runner(device:commandQueue:)` using
  `device.makeMTL4CommandQueue()`.
- `.renderPipelineDescriptorModifier(_:)` is removed; it was a deprecated name for
  `.renderPipelineDescriptorTransformer(_:)`.
- `.commandQueue(_:)`, `.commandBuffer(_:)` and `.computePassDescriptor(_:)` are removed, as are the environment
  values `blitCommandEncoder`, `commandBufferDescriptor` and `computePassDescriptor`. Label a compute pass with
  `ComputePass(label:)`.

## GPU capture labels

`RenderPass(label:)` and `ComputePass(label:)` label their encoders.
Pipeline labels also label argument tables by shader stage.
For example, `RenderPipeline(label: "Cube", ...)` produces labels such as `Cube: Vertex Arguments` and `Cube: Fragment Arguments`.
Compute, object, and mesh stages follow the same convention. Without a pipeline label, the prefix is `MetalSprockets`.
Reused tables keep the correct pipeline and stage labels.

## Shaders and GPU timing

| Before | After |
| --- | --- |
| `VertexShader(function)` (any shader type from an `MTLFunction`) | `try VertexShader(library: library, name: "vertex_main")`, or `try VertexShader(ShaderFunction(...))` |
| `.linkedFunctions([MTLFunction])`, `.visibleFunctionTable(_:functions: [MTLFunction])` | The same modifiers with `VisibleFunction` values |
| `GPUCounterSampler`, `GPUCounterSampleIndex` | `.gpuCounters(label:) { sample in … }` on a pass |

`SubmissionResult` reports only GPU time (`gpuStartTime`, `gpuEndTime`, `gpuDuration`), sourced from
`MTL4CommitFeedback`. Metal 3's `MTLCommandBuffer.kernelStartTime`/`kernelEndTime` (the CPU-side scheduling window)
have no Metal 4 equivalent — `MTL4CommitFeedback` exposes `GPUStartTime`/`GPUEndTime` only — so kernel timing is gone.
Use `gpuDuration`, or measure CPU time around `submit` yourself.

## Other behavior changes

- `.capture()` must wrap whole passes, not sit inside one. Shader logging disables capture for the whole process.
- `GPUCounterSample.fragment` is always `nil`. Use `duration` and `vertex` instead.
- `.depthBias` and `.stencilReferenceValue` are per-draw state. They can wrap a whole pass.
- `ComputeDispatch(threadgroups:)` without a threadgroup size uses one SIMD group per threadgroup.
- A visible-function table that names a function not passed to `.linkedFunctions` is an error. The function must be
  linked into the table's stage: use `.linkedFunctions(_:functionType:)` to link into only the vertex or fragment stage.
- `YCbCrBillboardRenderPass(frameData:)` (iOS) keeps ARKit's `CVMetalTexture`s alive until the GPU is done. Pass
  `owners:` when you supply camera textures yourself.

## Checklist

1. Build. Removed APIs show up as unknown names; find each one in the tables above.
2. Move vertex data and textures out of `Draw` closures into modifiers.
3. Add barriers where one command reads what another wrote, inside a pass and between passes.
4. Put resources that live longer than one frame in a `ResourceCollection`.
5. Run with `MTL_DEBUG_LAYER=1` (Metal API Validation) and fix any unset bindings it reports.
6. Take a GPU capture. In the Dependencies view, check that every producer and consumer pass has an edge between
   them, and that the command list has no per-frame `addAllocation`/`removeAllocation` for long-lived resources.

See `RELEASENOTES.md` for the full list of changes.
