# ISSUES.md

---

## 11: Address Type Safety

+++
status: open
priority: medium
kind: enhancement
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:01Z
+++

The elephant in room here is that MetalSprockets is not as type safe as it should be.

With SwiftUI you can make up almost any combination of View and pass it as content to another view and you will get runnable (albeit maybe bad…) UI.

With MetalSprockets you can't do that - you can make an utter nonsense element graph that is meaningless - that will compile but will either not do anything or crash (due to elements not being set up the way they need).

The same kind of thing exists in SwiftUI where views like TableView _expect_ TableRows/TableColumns.

We need to try and copy this.

This may mean we need _more_element builder types (in the same way I think SwiftUI has TableRowBuilder etc)

*Imported from #3*

---

## 13: Improve ParameterValues

+++
status: open
priority: medium
kind: enhancement
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:50Z
+++

It would be nice if `ParameterValues` had better constructors so that we know 2nd parameter of `.buffer(…, …)` is an offset in the buffer and to get rid of the `T` generic parameter.

Make make this a struct… that takes closures that will call `MTLXXXCommandEncoder.setXXXX` appropriately.

*Imported from #5*

- `2026-04-03T17:33:50Z`: Related: #54 (consolidate parameter nodes)

---

## 19: Refactor OffscreenRenderer architecture

+++
status: open
priority: medium
kind: enhancement
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:01Z
+++

Consolidate OffscreenRenderer improvements:

- Merge ComputePass.compute() & OffscreenRenderer into one thing (was #19)
- Break OffscreenRenderer into renderer & render session (was #20)  
- Make OffscreenRenderer more configurable (was #25)

The goal is a cleaner, more flexible offscreen rendering API.

---

## 20: Break OffscreenRenderer into renderer & render session

+++
status: closed
priority: none
kind: none
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:19:42Z
closed: 2026-03-31T18:19:42Z
+++

*Imported from #12*

- `2026-04-02T18:39:04Z`: Merged into #19 (Refactor OffscreenRenderer architecture)

---

## 22: Improve modifier architecture

+++
status: open
priority: medium
kind: enhancement
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:50Z
+++

Consolidate modifier architecture improvements:

- ElementModifier is not a true Element (was #22)
- Bring back modifiers (was #184)
- Investigate reducing closure usage in modifiers (was #186)

Related issues:
- #186 notes closures make element comparison impossible
- Need to decide if modifiers should be true Elements or a separate concept

- `2026-04-03T17:33:50Z`: Related: #31 (shaders as modifiers)

---

## 25: OffscreenRenderer should be more configurable

+++
status: closed
priority: none
kind: none
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:19:43Z
closed: 2026-03-31T18:19:43Z
+++

*Imported from #17*

- `2026-04-02T18:39:04Z`: Merged into #19 (Refactor OffscreenRenderer architecture)

---

## 31: Make shaders/kernels modifiers

+++
status: open
priority: low
kind: enhancement
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:50Z
+++

By default a vertex and fragment shader should be a modifier instead of a parameter

Right now we have `RenderPipeline(vertexShader, fragmentShader)` - it would be better to do `RenderPipeline().vertexShader(xxx).fragementShader(xxx)` where the shaders get stored in the environment.

This allows shaders to be propagated through environment and override if needed? (maybe - is this actually a useful thing?)

WE can also provide an init method on RenderPipeline that works the same as before.

Also make this change on compute shaders.

*Imported from #23*

- `2026-04-03T17:33:50Z`: Related: #22 (modifier architecture)

---

## 32: Re-visit MainActor usage through MetalSprockets

+++
status: closed
priority: none
kind: none
labels: concurrency, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:27:02Z
closed: 2026-03-31T18:27:02Z
+++

*Imported from #24*

- `2026-04-02T18:39:04Z`: Replaced by new consolidated concurrency issue

---

## 33: Provide a nice way to get FPS programmatically

+++
status: closed
priority: none
kind: none
labels: effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:27:48Z
closed: 2026-03-31T18:27:48Z
+++

*Imported from #25*

- `2026-04-02T18:39:04Z`: Already implemented: FrameTimingView, FrameTimingStatistics, and .onFrameTimingChange() modifier

---

## 34: Investigate flickering of Metal FPU counter

+++
status: open
priority: low
kind: bug
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T19:19:48Z
+++

*Imported from #26*

- `2026-04-09T20:13:12Z`: This is the same issue as #312 — the Metal GPU performance HUD disappears/flickers during drag gestures. Also note: flickering is reduced when shader validation is enabled (slower frame rate masks the issue).

---

## 38: Rename CommandBufferElement

+++
status: closed
priority: none
kind: none
labels: effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:28:53Z
closed: 2026-03-31T18:28:53Z
+++

File: Sources/MetalSprockets/Metal/CommandBufferElement.swift

*Imported from #30*

- `2026-04-02T18:39:04Z`: Name is fine as-is

---

## 42: Do we need DynamicProperty?

+++
status: open
priority: low
kind: enhancement
labels: effort:l, needs-info
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:09Z
+++

```
// TODO: SwiftUI.Environment adopts DynamicProperty.
```

File: Sources/MetalSprockets/Core/EnvironmentValues.swift

*Imported from #34*

---

## 44: Compute the correct threadsPerThreadgroup

+++
status: closed
priority: none
kind: none
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:31:14Z
closed: 2026-03-31T17:31:14Z
+++

In file Sources/UltraviolenceExamples/CheckerboardKernel.swift
https://github.com/schwa/Ultraviolence/blob/ebd49f199dbed51331e10ecaf7f9602f391f1d94/Sources/UltraviolenceExamples/CheckerboardKernel.swift#L23

*Imported from #35*

- `2026-04-02T18:39:04Z`: References old Ultraviolence paths that no longer exist

---

## 46: Make MTLTexture.toCGImage() robust

+++
status: closed
priority: none
kind: none
labels: effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:24:01Z
closed: 2026-03-31T18:24:01Z
+++

```
        // TODO: Hack
```

In file Sources/UltraviolenceSupport/MetalSupport.swift
https://github.com/schwa/Ultraviolence/blob/ebd49f199dbed51331e10ecaf7f9602f391f1d94/Sources/UltraviolenceSupport/MetalSupport.swift#L650

*Imported from #38*

- `2026-04-02T18:39:04Z`: References old paths that no longer exist

---

## 48: Add labels to everything

+++
status: open
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:09Z
+++

Ensure all Metal resources have descriptive labels set:
- MTLBuffer
- MTLTexture
- MTLRenderPipelineState
- MTLComputePipelineState
- Debug groups (pushDebugGroup/popDebugGroup)

This makes GPU debugging much easier in Xcode and Instruments.

---

## 49: Revisit MTLCaptureManager

+++
status: open
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:09Z
+++

Improve MTLCaptureManager integration:

## Current state
Basic support exists via `MTLCaptureManager.with(enabled:body:)` in MetalSupport.swift.

## Desired
Add a higher-level API for RenderView, something like:
```swift
.captureNextFrame(_ shouldCapture: Bool)
```

This would trigger a GPU capture of the next frame when the boolean becomes true, making it easy to wire up to a button or keyboard shortcut.

---

## 50: Provide a hook for GPU counters

+++
status: open
priority: low
kind: feature
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:09Z
+++

Expose Metal GPU counter APIs through the framework:
- Allow users to query GPU execution time, memory bandwidth, etc.
- Could integrate with FrameTimingStatistics or be a separate API
- Useful for performance profiling and optimization

---

## 51: Sanitize all debug groups and resource labels

+++
status: closed
priority: none
kind: none
labels: effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:16:34Z
closed: 2026-03-31T18:16:34Z
+++

*Imported from #43*

- `2026-04-02T18:39:04Z`: Duplicate of #48 (Add labels to everything)

---

## 53: add disabled() modifier

+++
status: open
priority: low
kind: feature
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:09Z
+++

Add a `.disabled(_ isDisabled: Bool)` modifier that skips an element's rendering when true. Similar to SwiftUI's `.hidden()`. Useful for:
- Toggling effects on/off for debugging
- A/B comparisons
- Conditional rendering without restructuring the element tree

---

## 54: Put parameters into one RenderPass object instead of having a bunch of nested ParameterRenderPasss

+++
status: open
priority: medium
kind: enhancement
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:50Z
+++

Optimization: consolidate multiple `.parameter()` modifiers into a single node.

## Current behavior
Each `.parameter()` call creates a nested `ParameterElementModifier`, leading to deep nesting:
```
ParameterElementModifier
  └── ParameterElementModifier
        └── ParameterElementModifier
              └── Draw
```

## Desired behavior
Combine consecutive parameter modifiers into a single node that holds all parameters:
```
CombinedParameters (color, transform, texture)
  └── Draw
```

This would reduce tree depth and improve traversal performance.

- `2026-04-03T17:33:50Z`: Related: #13 (improve ParameterValues)

---

## 55: Handle MTLCreateSystemDefaultDevice() everywhere

+++
status: open
priority: medium
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:09Z
+++

Audit usage of `MTLCreateSystemDefaultDevice()` throughout the codebase.

## Current situation
- On Apple Silicon (iPhones, ARM Macs) this never returns nil
- On Intel Macs it can return nil (no Metal support)
- Code smell: if Apple adds multi-GPU hardware in the future, using the 'default' device everywhere may be wrong

## Not urgent
This isn't a problem today, but could become one. Consider:
- Passing device explicitly through the API where possible
- Having a single validated device instance
- Being prepared for multi-GPU scenarios

---

## 59: Shader Graph

+++
status: closed
priority: none
kind: none
labels: effort:xl
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:36:08Z
closed: 2026-03-31T18:36:08Z
+++

*Imported from #51*

- `2026-04-02T18:39:04Z`: Out of scope for this project

---

## 61: Make API match SwiftUI shader API a little better (parameter vs argument etc)

+++
status: open
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:09Z
+++

Align MetalSprockets API terminology with SwiftUI's shader API where it makes sense:
- SwiftUI uses "argument", MetalSprockets uses "parameter"
- Review other naming differences
- Goal: make the API feel familiar to SwiftUI developers

---

## 62: Need some kind of `setNeedsUpdate`

+++
status: closed
priority: none
kind: none
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:36:54Z
closed: 2026-03-31T18:36:54Z
+++

*Imported from #54*

- `2026-04-02T18:39:04Z`: Unclear if needed - closing for now

---

## 67: Formalize element Input and Output

+++
status: open
priority: medium
kind: enhancement
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:50Z
+++

Formalize which environment keys each element reads (inputs) and writes (outputs).

## Problem
It's confusing what parts of the Metal stack each element is responsible for. Elements implicitly depend on certain environment values being set.

## Proposed solution
Use an extension on Node (possibly with parameter packs) to explicitly declare input/output environment keys. This would:
- Make data flow explicit
- Catch missing dependencies at compile time or with clear runtime errors
- Document what each element needs and provides

- `2026-04-03T17:33:50Z`: Related: #235 (split BodylessElement protocols)

---

## 70: Improve Attachment flow

+++
status: open
priority: medium
kind: enhancement
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:10Z
+++

We need a nice clean way to allow the user to customise attachments incl (but not limited to) color, depth, stencil etc.

*Imported from #62*

- `2026-04-02T18:39:04Z`: Needs concrete examples of what's painful today before addressing this.

---

## 73: Fix all SwiftLint disable comments

+++
status: open
priority: low
kind: task
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:13Z
+++

*Imported from #65*

---

## 76: Decide what to do with https://github.com/schwa/Compute

+++
status: closed
priority: low
kind: none
labels: effort:m, priority:low
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:38:08Z
closed: 2026-03-31T18:38:08Z
+++

*Imported from #68*

- `2026-04-02T18:39:04Z`: Decision deferred - not actionable

---

## 77: Rethink ACL of UltraviolenceSupport

+++
status: closed
priority: none
kind: none
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:34:24Z
closed: 2026-03-31T17:34:24Z
+++

*Imported from #69*

- `2026-04-02T18:39:04Z`: No longer relevant - project restructured from Ultraviolence to MetalSprockets; UltraviolenceSupport and Demo/Packages/UltraviolenceExamples no longer exist

---

## 79: Async shader compilation.

+++
status: closed
priority: none
kind: none
labels: effort:xl, concurrency
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:27:21Z
closed: 2026-03-31T18:27:21Z
+++

*Imported from #71*

- `2026-04-02T18:39:04Z`: Merged into #291 (Audit and improve Swift concurrency)

---

## 81: Clean up all Metal extension code - especially stuff on buffers etc to make sure it's not being stupid.

+++
status: open
priority: low
kind: task
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:14Z
+++

Audit Metal type extensions in MetalSprocketsSupport (especially buffer-related code):
- Remove unused extensions
- Fix any inefficient implementations
- Ensure consistency and good practices
- Check for duplication with MetalKit built-in functionality

---

## 82: Emit OS logging POIs for each frame

+++
status: open
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:14Z
+++

Add OSSignposter points of interest (POIs) for frame timing. This makes frames visible in Instruments' timeline, helping with profiling.

```swift
var poi = OSSignposter(subsystem: "...", category: .pointsOfInterest)
let id = poi.makeSignpostID()
let state = poi.beginInterval(#function, id: id, "\(value)")
// ... frame work ...
poi.endInterval(#function, state)
```

---

## 86: Clean up shader function lookup in ShaderLibrary

+++
status: open
priority: low
kind: task
labels: effort:m, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:14Z
+++

Clean up shader function lookup logic in ShaderLibrary.swift:
- Review error handling for missing functions
- Simplify the lookup API if possible
- Ensure clear error messages when functions aren't found

---

## 89: Improve environment/descriptor modification in CommandBufferElement and RenderPipeline

+++
status: open
priority: medium
kind: enhancement
labels: effort:l, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:14Z
+++

Consolidate issues about environment and descriptor access:

- Users cannot modify the environment in CommandBufferElement (was #89)
- No opportunity to modify the descriptor in CommandBufferElement (was #90)
- RenderPipeline copies from render pass descriptor instead of getting from environment (was #95)

The goal is a consistent pattern for environment-based configuration throughout the Metal element stack.

---

## 90: There isn't an opportunity to modify the descriptor here.

+++
status: closed
priority: none
kind: none
labels: effort:l, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:20:21Z
closed: 2026-03-31T18:20:21Z
+++

File: Sources/MetalSprockets/Metal/CommandBufferElement.swift

*Imported from #82*

- `2026-04-02T18:39:04Z`: Merged into #89 (Improve environment/descriptor modification)

---

## 91: is this actually necessary? Elements just use an environment?

+++
status: open
priority: low
kind: task
labels: effort:m, source:todo, needs-info
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:14Z
+++

File: Sources/MetalSprockets/Metal/RenderPipelineDescriptorModifier.swift (if it exists)

*Imported from #83*

---

## 95: This is copying everything from the render pass descriptor. But really we should be getting this entirely from the enviroment.

+++
status: closed
priority: none
kind: none
labels: effort:l, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:20:21Z
closed: 2026-03-31T18:20:21Z
+++

File: Sources/MetalSprockets/Metal/RenderPipeline.swift

*Imported from #87*

- `2026-04-02T18:39:04Z`: Merged into #89 (Improve environment/descriptor modification)

---

## 102: Also it could take a SwiftUI environment(). Also SRGB?

+++
status: open
priority: low
kind: enhancement
labels: effort:m, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:14Z
+++

Improve the `.parameter(_:color:)` modifier:
- Consider reading colors from SwiftUI's environment (e.g., accent color, tint)
- Handle SRGB color space correctly (currently uses deviceRGB)
- File: Sources/MetalSprocketsUI/Parameter+SwiftUI.swift

---

## 104: ViewAdaptor should be internal but is currently used externally

+++
status: open
priority: medium
kind: task
labels: source:todo, effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:14Z
+++

Make `ViewAdaptor` internal instead of public. It's only used by RenderView internally.

---

## 106: This is messy and needs organisation and possibly deprecation of unused elements.

+++
status: open
priority: low
kind: task
labels: effort:m, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:14Z
+++

Clean up UVEnvironmentValues+Implementation.swift (should probably be renamed to MSEnvironmentValues+Implementation.swift):
- Organize environment value definitions
- Remove/deprecate unused values
- Group related values together
- Rename file to match MS naming convention

---

## 112: Reduce MTLTexture descriptor usage flags to only necessary ones

+++
status: open
priority: low
kind: enhancement
labels: source:todo, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:14Z
+++

Audit MTLTexture creation to use only the necessary usage flags. Over-specifying usage flags can prevent GPU optimizations.

- Review texture creation in MetalSprocketsSupport
- Set minimal required flags for each use case
- Consider making usage configurable where appropriate

---

## 113: Fix hardcoded texture loading in MetalSupport

+++
status: closed
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:31:14Z
closed: 2026-03-31T17:31:14Z
+++

Found in Sources/UltraviolenceSupport/MetalSupport.swift at line 767

*Imported from #105*

- `2026-04-02T18:39:04Z`: References old Ultraviolence paths that no longer exist

---

## 119: Fix same parameter name with both shaders.

+++
status: closed
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:31:14Z
closed: 2026-03-31T17:31:14Z
+++

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Support/Transforms.swift at line 26

*Imported from #111*

- `2026-04-02T18:39:04Z`: References old Ultraviolence paths that no longer exist

---

## 122: Remove duplicate projection implementations

+++
status: closed
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:34:24Z
closed: 2026-03-31T17:34:24Z
+++

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Support/Projection.swift at line 39

*Imported from #114*

- `2026-04-02T18:39:04Z`: No longer relevant - project restructured from Ultraviolence to MetalSprockets; UltraviolenceSupport and Demo/Packages/UltraviolenceExamples no longer exist

---

## 126: Make generic for any VectorArithmetic and add a transform closure for axis handling?

+++
status: closed
priority: none
kind: none
labels: effort:m, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:24:01Z
closed: 2026-03-31T18:24:01Z
+++

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Interaction/DraggableValueViewModifier.swift at line 20

*Imported from #118*

- `2026-04-02T18:39:04Z`: References old paths that no longer exist

---

## 127: DragGestures' predictions are mostly junk. Refactor to this to keep own prediction logic.

+++
status: closed
priority: none
kind: none
labels: effort:m, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:31:14Z
closed: 2026-03-31T17:31:14Z
+++

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Interaction/DraggableValueViewModifier.swift at line 69

*Imported from #119*

- `2026-04-02T18:39:04Z`: References old Ultraviolence paths that no longer exist

---

## 128: Remove offscreen-specific texture setup from general rendering code

+++
status: closed
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:31:14Z
closed: 2026-03-31T17:31:14Z
+++

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/ExampleElements/MixedExample.swift at line 29

*Imported from #120*

- `2026-04-02T18:39:04Z`: References old Ultraviolence paths that no longer exist

---

## 129: Flesh out Packed3 implementation

+++
status: closed
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:31:14Z
closed: 2026-03-31T17:31:14Z
+++

Packed3 should work identically to SIMD3. We need to flesh it out with more operators etc.

*Imported from #121*

- `2026-04-02T18:39:04Z`: Packed3 does not exist in current codebase

---

## 137: Add unit tests for `ElementBuilder.buildEither`.

+++
status: open
priority: low
kind: task
labels: source:todo, testing, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:17Z
+++

File: Sources/MetalSprockets/Core/ElementBuilder.swift

*Imported from #129*

---

## 138: Dangerous `@unchecked Sendable` usage in SplatCloud and SplatIndices

+++
status: closed
priority: none
kind: none
labels: effort:s, concurrency, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:31:14Z
closed: 2026-03-31T17:31:14Z
+++

Both `SplatCloud` and `SplatIndices` are marked as `@unchecked Sendable`, which bypasses Swift's concurrency safety checks.

## Issues:

### SplatCloud
- It's a class (reference type) with mutable state
- Contains mutable properties that could cause data races
- No synchronization mechanisms in place

### SplatIndices  
- Contains `TypedMTLBuffer` which is not Sendable
- No synchronization for concurrent access

## Potential Solutions:
1. Make them actors for proper isolation
2. Add proper synchronization (locks/queues)
3. Remove @unchecked Sendable if concurrent access isn't needed
4. Make them immutable

Found in Sources/UltraviolenceGaussianSplats/Splats/SplatCloud.swift

*Imported from #130*

- `2026-04-02T18:39:04Z`: SplatCloud/SplatIndices not in current codebase

---

## 142: OffscreenRenderer creates own command buffer without giving us a chance to intercept

+++
status: closed
priority: none
kind: none
labels: effort:l, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:31:14Z
closed: 2026-03-31T17:31:14Z
+++

Found in Tests/UltraviolenceTests/RenderTests.swift at line 60

*Imported from #134*

- `2026-04-02T18:39:04Z`: References old Ultraviolence paths that no longer exist

---

## 145: Get code coverage to 80%

+++
status: closed
priority: none
kind: none
labels: effort:xl, testing
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:16:43Z
closed: 2026-03-31T18:16:43Z
+++

*Imported from #137*

- `2026-04-02T18:39:04Z`: Closing coverage targets for now - not a priority

---

## 146: Get code coverage to 100%

+++
status: closed
priority: none
kind: none
labels: effort:xl, testing
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:16:43Z
closed: 2026-03-31T18:16:43Z
+++

*Imported from #138*

- `2026-04-02T18:39:04Z`: Closing coverage targets for now - not a priority

---

## 147: Generate docc and host on swift packages

+++
status: closed
priority: none
kind: documentation
labels: documentation, effort:xl
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:45:53Z
closed: 2026-03-31T18:45:53Z
+++

*Imported from #139*

- `2026-04-02T18:39:04Z`: Already implemented - DocC workflow exists in .github/workflows/docc.yml, deploys to GitHub Pages

---

## 148: Header docs

+++
status: open
priority: low
kind: documentation
labels: documentation, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:30Z
+++

Continue adding documentation comments (///) to public APIs.

Current state: ~37% of files have doc comments. Key public APIs (RenderPass, RenderPipeline) are well documented, but many types still need coverage.

Priority:
- All public types and methods
- Environment keys
- Modifiers

---

## 149: Tutorials

+++
status: open
priority: low
kind: documentation
labels: documentation, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:30Z
+++

Expand DocC tutorials for MetalSprockets.

## Existing tutorials (4):
1. Colorful Triangle
2. Rainbow Quad
3. Animated Rainbow Quad
4. Spinning Cube

## Ideas for more:
- Compute shaders
- Post-processing effects
- MSAA / MetalFX
- Working with textures
- Loading 3D models

---

## 150: Screencast

+++
status: open
priority: low
kind: documentation
labels: documentation, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:43Z
+++

*Imported from #142*

---

## 152: Add onWorkloadExit modifier for all Elements

+++
status: open
priority: low
kind: feature
labels: source:todo, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:17Z
+++

Currently, `onWorkloadExit` is only available on `AnyBodylessElement`, while `onWorkloadEnter` is available as a general modifier for all Elements through `WorkloadModifier`.

## Current State
- `onWorkloadEnter`: Available on all Elements via `WorkloadModifier` in `WorkloadModifier.swift`
- `onWorkloadExit`: Only available on `AnyBodylessElement`, not as a general modifier

## Expected Behavior
For consistency and completeness, `onWorkloadExit` should be available as a general modifier for all Elements, similar to how `onWorkloadEnter` is implemented.

## Implementation Suggestion
Extend `WorkloadModifier` to support both enter and exit callbacks, or create a separate modifier for `onWorkloadExit` that follows the same pattern as the existing `onWorkloadEnter` implementation.

*Imported from #144*

---

## 154: Demo: Barrel Distortion Post-Processing Effect

+++
status: closed
priority: none
kind: enhancement
labels: enhancement, demo
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:21:18Z
closed: 2026-03-31T18:21:18Z
+++

## Summary
Port the barrel distortion post-processing effect to demonstrate image distortion capabilities in MetalSprockets.

## Description
Implement a barrel/pincushion distortion effect as a post-processing shader that can be applied to rendered content. This is useful for VR lens correction and artistic effects.

## Key Features
- Configurable distortion strength and center point
- Support for both barrel and pincushion distortion
- Real-time parameter adjustment
- Chain with other post-processing effects

## Implementation Notes
- Create a PostProcessElement for the effect
- Use texture sampling with distortion mapping
- Support different distortion models (simple radial, Brown-Conrady)

## Acceptance Criteria
- [ ] Barrel and pincushion distortion working correctly
- [ ] Smooth real-time parameter updates
- [ ] No artifacts at texture boundaries
- [ ] Example usage in demo app
- [ ] Performance optimized for real-time use

*Imported from #146*

- `2026-04-02T18:39:04Z`: Examples are now in a separate repo

---

## 170: Replace custom MDLVertexDescriptor to MTLVertexDescriptor conversion with MTKMetalVertexDescriptorFromModelIO

+++
status: open
priority: low
kind: enhancement
labels: enhancement, effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:30Z
+++

Currently in MetalSupport.swift, we have a custom convenience initializer that converts MDLVertexDescriptor to MTLVertexDescriptor. MetalKit provides MTKMetalVertexDescriptorFromModelIO() for this exact purpose. We should replace our custom implementation with the official API.

File: Sources/MetalSprocketsSupport/MetalSupport.swift

The custom implementation manually iterates through attributes and layouts, converting formats and copying offsets. This should be replaced with a call to MTKMetalVertexDescriptorFromModelIO().

*Imported from #162*

---

## 171: Might as well make vertex descriptor a parameter to Render

+++
status: open
priority: low
kind: enhancement
labels: enhancement, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:30Z
+++

Make vertex descriptor a parameter on Render and RenderPipeline instead of requiring environment setup or modifiers. This would make common cases simpler.

---

## 172: Might as well make vertex descriptor a parameter to RenderPipeline

+++
status: closed
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:16:49Z
closed: 2026-03-31T18:16:49Z
+++

*Imported from #164*

- `2026-04-02T18:39:04Z`: Duplicate of #171 (vertex descriptor as parameter)

---

## 174: Parent chain in MSEnvironmentValues.Storage may be unnecessary

+++
status: open
priority: low
kind: enhancement
labels: enhancement, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:30Z
+++

## Current State
After fixing #68, we now always create fresh Storage instances for each node to prevent cycles. This raises the question of whether the parent chain is still necessary.

## Observations
1. Each node now gets its own fresh MSEnvironmentValues with its own Storage instance
2. Storage instances still maintain a parent chain for value inheritance lookups
3. We have cycle detection code in the parent setter to prevent infinite loops
4. Values are looked up by checking local storage first, then traversing the parent chain

## Key Question
Since we're creating fresh Storage instances anyway (to prevent the cycles from #68), do we still need the parent chain? Or could we simplify by copying values instead?

## Current Behavior
- Environment values are inherited via parent chain traversal at lookup time
- Only explicitly set values are stored locally in each Storage
- Parent chain requires weak references and cycle detection

## Alternative Approaches
There may be different ways to handle environment value inheritance:
- Keep parent chain but ensure it works correctly without cycles
- Copy all inherited values and eliminate parent chain
- Some hybrid approach

## Related Issues
- Original cycle issue: #68
- Fix implemented: Creating fresh Storage instances for each node

This issue is to track the architectural question of whether the parent chain is the right approach given our current implementation.

*Imported from #166*

---

## 177: Stop using generic errors

+++
status: open
priority: medium
kind: enhancement
labels: enhancement, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:30Z
+++

Replace generic error types with specific, descriptive error types. This improves debugging and error handling by making it clear what went wrong.

---

## 180: Fix swiftlint warnings (again)

+++
status: closed
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:16:37Z
closed: 2026-03-31T18:16:37Z
+++

*Imported from #172*

- `2026-04-02T18:39:04Z`: Duplicate of #73 (Fix all SwiftLint disable comments)

---

## 184: Bring back modifiers

+++
status: closed
priority: none
kind: feature
labels: feature
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:19:49Z
closed: 2026-03-31T18:19:49Z
+++

*Imported from #176*

- `2026-04-02T18:39:04Z`: Merged into #22 (Improve modifier architecture)

---

## 186: Investigate reducing closure usage in modifiers

+++
status: closed
priority: none
kind: none
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:19:49Z
closed: 2026-03-31T18:19:49Z
+++

## Problem
Many modifiers use closures which makes element comparison impossible, contributing to the performance issues in #17.

## Investigation Areas

### EnvironmentWritingModifier
Currently uses a closure to capture keyPath and value:
```swift
EnvironmentWritingModifier(content: self) { environmentValues in
    environmentValues[keyPath: keyPath] = value
}
```

Could potentially store keyPath and value directly as properties.

### Other Modifiers to Investigate
- RenderPipelineDescriptorModifier
- RenderPassDescriptorModifier  
- WorkloadModifier
- Event handler modifiers (onCommandBufferScheduled, etc.)

## Tasks
- [ ] Prototype EnvironmentWritingModifier without closures
- [ ] Evaluate type erasure complexity vs benefits
- [ ] Identify which modifiers can avoid closures
- [ ] Document trade-offs and recommendations

## Note
Some closures are fundamental to the API and can't be eliminated (like @ElementBuilder content). Focus on modifiers where closures are used just for capturing values.

## Related Issues
- #184 Bring back modifiers
- #22 ElementModifier is not a true Element
- #17 Graph.updateContent should detect if content changed

*Imported from #178*

- `2026-04-02T18:39:04Z`: Merged into #22 (Improve modifier architecture)

---

## 187: Add id modifier for explicit identity

+++
status: open
priority: medium
kind: feature
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:17Z
+++

## Overview
Add an id modifier similar to SwiftUI that allows explicit identity control for elements, supporting the structural identity system.

## Design
```swift
extension Element {
    func id<ID: Hashable>(_ id: ID) -> some Element {
        IdentifiedElement(content: self, id: id)
    }
}

struct IdentifiedElement<Content: Element, ID: Hashable>: Element {
    let content: Content
    let id: ID
    
    var body: some Element {
        content
    }
}
```

## Integration with Structural Identity
The explicit ID becomes part of the StructuralID:
```swift
StructuralID.Atom(
    type: ObjectIdentifier(type(of: element)),
    index: childIndex,
    explicit: element.id  // From id modifier if present
)
```

## Use Cases
- Stable identity for dynamic content
- Preventing unwanted re-setup when elements move
- Explicit control over element lifecycle

## Related Issues
- #185 Implement Structural Identity System
- #17 Graph.updateContent should detect if content changed

*Imported from #179*

---

## 193: Expand NeoNode basic tests

+++
status: closed
priority: none
kind: none
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T17:31:15Z
closed: 2026-03-31T17:31:15Z
+++

## Description
Currently we have minimal test coverage for NeoNode functionality. We should expand the test suite to cover more scenarios.

## Current Tests
- `testParentIdentifierIsSet` - Verifies parent-child relationships via parentIdentifier

## Suggested Additional Tests
- Test that parentIdentifier is updated when nodes move in the tree
- Test parentIdentifier with ForEach and dynamic content
- Test parentIdentifier with conditional content (if/else branches)
- Test that parentIdentifier is preserved when nodes are reused during updates
- Test parentIdentifier with deeply nested structures (10+ levels)
- Test parentIdentifier with sibling relationships
- Test that root node always has nil parentIdentifier
- Test parentIdentifier with environment modifications
- Test parentIdentifier with state changes that don't affect structure

## Implementation Notes
Tests should be added to `Tests/UltraviolenceTests/NeoNodeTests.swift`

*Imported from #185*

- `2026-04-02T18:39:04Z`: NeoNode no longer exists - renamed to Node

---

## 194: Do we need activeNodeStack or just activeNode

+++
status: closed
priority: none
kind: none
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:56:27Z
closed: 2026-03-31T18:56:27Z
+++

*Imported from #186*

- `2026-04-02T18:39:04Z`: Out of date - architecture has evolved

---

## 196: Optimize: Unused bindings cause unnecessary child rebuilds

+++
status: open
priority: medium
kind: enhancement
labels: enhancement, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:50Z
+++

## Problem

When a binding is passed to a child element but not actually used in the child's body, the child still rebuilds when the parent's state changes. This is an unnecessary performance penalty.

## Root Cause

The issue is in how `MSBinding` equality works:
- Each `MSBinding` has a UUID that's created when initialized
- When the parent rebuilds its body due to state change, it creates a new child element instance with the binding
- Even though the binding points to the same underlying `StateBox`, the `MSBinding` comparison sees them as different because of different UUIDs
- This causes the system to think the child element has changed and needs rebuilding

## Test Case

```swift
// MARK: - Unused Binding Test

struct UnusedBindingParent: Element {
    @MSState var value = 0
    
    var body: some Element {
        TestMonitor.shared.logUpdate("parent-body")
        return VStack {
            ActionElement(value: value) {
                value += 1
            }
            UnusedBindingChild(value: $value)
        }
    }
}

struct UnusedBindingChild: Element {
    @MSBinding var value: Int
    
    var body: some Element {
        TestMonitor.shared.logUpdate("child-body")
        // Binding is passed but not used in body
        return EmptyElement()
    }
}

struct VStack<Content: Element>: Element {
    let content: Content
    
    init(@ElementBuilder content: () throws -> Content) rethrows {
        self.content = try content()
    }
    
    var body: some Element {
        content
    }
}

@Test
func testUnusedBinding() async throws {
    TestMonitor.shared.reset()
    
    let root = UnusedBindingParent()
    let system = System()
    
    try system.update(root: root)
    #expect(TestMonitor.shared.updates == ["parent-body", "child-body"])
    
    TestMonitor.shared.updates.removeAll()
    
    // Trigger parent state change
    let action = system.element(at: [0, 0, 0, 0], type: ActionElement.self)!
    system.withCurrentSystem {
        action.action()
    }
    
    try system.update(root: root)
    
    // Parent rebuilds, but child should not since it doesn't use the binding
    #expect(TestMonitor.shared.updates == ["parent-body"])  // FAILS: child-body is also called
}
```

## Expected Behavior

When a binding is not used in a child's body, the child should not rebuild when the parent's state changes.

## Proposed Solution

Modify `MSBinding` equality to compare based on the underlying state source rather than a UUID:
1. Add a `sourceIdentifier` property to track the underlying StateBox
2. Update StateBox to pass its ObjectIdentifier when creating bindings  
3. Fix equality comparison to compare sourceIdentifiers instead of UUIDs

This would ensure that bindings pointing to the same state source are considered equal, preventing unnecessary rebuilds.

## Impact

This is a performance optimization - the current behavior is functionally correct but causes unnecessary work.

*Imported from #188*

- `2026-04-03T17:33:51Z`: Related: #197 (elements without parameters rebuild unnecessarily)

---

## 197: Optimize: Elements without parameters rebuild unnecessarily

+++
status: open
priority: medium
kind: enhancement
labels: enhancement, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:51Z
+++

## Problem

Elements with no parameters (or unchanging parameters) rebuild unnecessarily when their parent's state changes. This is a performance issue similar to #196.

## Root Cause

When comparing elements to determine if they need rebuilding, the `isEqual` function returns `false` for types that don't conform to `Equatable`. This means:
- Elements with no stored properties are always considered "different"
- Each new instance is treated as requiring a rebuild, even when nothing has changed

## Test Case

```swift
// MARK: - Nested State Rebuilding Test

struct RootWithRebuildTracking: Element {
    @MSState var counter = 0
    
    var body: some Element {
        TestMonitor.shared.logUpdate("root-body")
        return VStack {
            TrackedElement(name: "root-counter", value: counter) {
                counter += 1
            }
            ConstantChild()
            DynamicChild(value: counter)
            ConditionalChild(showExtra: counter > 2)
        }
    }
}

struct ConstantChild: Element {
    var body: some Element {
        TestMonitor.shared.logUpdate("constant-body")
        return EmptyElement()
    }
}

struct DynamicChild: Element {
    let value: Int
    
    var body: some Element {
        TestMonitor.shared.logUpdate("dynamic-body-\(value)")
        return EmptyElement()
    }
}

struct ConditionalChild: Element {
    let showExtra: Bool
    
    var body: some Element {
        TestMonitor.shared.logUpdate("conditional-body")
        if showExtra {
            return EmptyElement()
        } else {
            return EmptyElement()
        }
    }
}

struct VStack<Content: Element>: Element {
    let content: Content
    
    init(@ElementBuilder content: () throws -> Content) rethrows {
        self.content = try content()
    }
    
    var body: some Element {
        content
    }
}

@Test
func testSelectiveRebuilding() async throws {
    TestMonitor.shared.reset()
    
    let root = RootWithRebuildTracking()
    let system = System()
    
    // Initial build
    try system.update(root: root)
    
    #expect(TestMonitor.shared.updates == [
        "root-body",
        "constant-body",
        "dynamic-body-0",
        "conditional-body"
    ])
    
    TestMonitor.shared.updates.removeAll()
    
    // Increment counter
    system.withCurrentSystem {
        root.counter = 1
    }
    
    try system.update(root: root)
    
    // Root rebuilds, constant child should not, dynamic child rebuilds with new value
    #expect(TestMonitor.shared.updates == [
        "root-body",
        "dynamic-body-1",
        "conditional-body"
    ])  // FAILS: constant-body is also called
    
    TestMonitor.shared.updates.removeAll()
    
    // Increment past threshold for conditional
    system.withCurrentSystem {
        root.counter = 3
    }
    
    try system.update(root: root)
    
    #expect(TestMonitor.shared.updates == [
        "root-body",
        "dynamic-body-3",
        "conditional-body"
    ])  // FAILS: constant-body is also called
}
```

## Expected Behavior

- `ConstantChild` should not rebuild when parent state changes (it has no dependencies)
- `DynamicChild` should rebuild (its `value` parameter changes)
- `ConditionalChild` should rebuild (its `showExtra` parameter changes)

## Proposed Solution

Several possible approaches:
1. Auto-synthesize Equatable conformance for Elements with no stored properties
2. Special-case the equality check for types with no stored properties
3. Use a different mechanism to track whether an element needs rebuilding

## Related Issues

- #196 - Similar issue with unused bindings causing unnecessary rebuilds

## Impact

Performance optimization - the current behavior is functionally correct but causes unnecessary work, especially in complex element trees with many static child elements.

*Imported from #189*

- `2026-04-03T17:33:51Z`: Related: #196 (unused bindings cause unnecessary rebuilds)

---

## 200: Get unit test coverage to 60%

+++
status: closed
priority: none
kind: none
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:16:44Z
closed: 2026-03-31T18:16:44Z
+++

*Imported from #192*

- `2026-04-02T18:39:04Z`: Closing coverage targets for now - not a priority

---

## 202: Batteries included

+++
status: closed
priority: none
kind: feature
labels: feature
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:56:43Z
closed: 2026-03-31T18:56:43Z
+++

Create a target of standard shaders and pipelines that user can immediately use. 

Flat shaders. Basic PBR. MetalFX. Etc etc. 

*Imported from #194*

- `2026-04-02T18:39:04Z`: Out of scope - users can build their own shaders

---

## 209: Use IDs in System StructuralIdentifier for ForEach

+++
status: open
priority: low
kind: enhancement
labels: enhancement, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:31Z
+++

In ForEach.swift:24, there's a TODO noting that we're not using IDs in the System StructuralIdentifier yet. This should be implemented to properly track ForEach elements.

File: Sources/MetalSprockets/Core/ForEach.swift

*Imported from #201*

---

## 210: Handle errors in StateBox getter/setter

+++
status: open
priority: medium
kind: bug
labels: bug, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:31Z
+++

StateBox has TODO comments about error handling in the getter and setter methods. Need to determine proper error handling strategy.

File: Sources/MetalSprockets/Core/StateBox.swift

*Imported from #202*

---

## 212: Pass Node as parameter to EnvironmentReader

+++
status: open
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:17Z
+++

EnvironmentReader should ideally be passed a Node as a parameter as noted in the TODO.

File: Sources/MetalSprockets/Core/EnvironmentReader.swift

*Imported from #204*

---

## 213: Make System properties private

+++
status: open
priority: low
kind: task
labels: effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:18Z
+++

Audit System class and make properties private that shouldn't be public API. Reduce the exposed surface area.

---

## 214: Call cleanup/onDisappear for removed nodes

+++
status: open
priority: medium
kind: bug
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:18Z
+++

System could call cleanup/onDisappear when nodes are removed. Currently just notes they're gone.

File: Sources/MetalSprockets/Core/System.swift

*Imported from #206*

---

## 216: Rename Element+SystemExtensions file

+++
status: closed
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:57:32Z
closed: 2026-03-31T18:57:32Z
+++

The Element+SystemExtensions file needs to be renamed to better reflect its purpose.

File: Sources/MetalSprockets/Core/Element+SystemExtensions.swift

*Imported from #208*

- `2026-04-02T18:39:04Z`: Not important enough to track

---

## 217: Clarify purpose of AnyBodylessElement extensions

+++
status: open
priority: low
kind: task
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:18Z
+++

Document the AnyBodylessElement modifier-style extensions (onSetupEnter, onSetupExit, onWorkloadEnter, onWorkloadExit).

These are used for building elements that need custom setup/workload phase behavior without creating a full custom type. Example usage: MetalFXSpatial.swift.

Either:
- Add proper documentation comments explaining the pattern
- Or consider if there's a better API design

---

## 218: Fix dangerous tree walking in Element+Dump

+++
status: open
priority: medium
kind: bug
labels: bug, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:35Z
+++

Walking the tree in Element+Dump can modify state which is dangerous. Elements like EnvironmentReader can break things. Need to only walk the System tree instead.

File: Sources/MetalSprockets/Core/Element+Dump.swift

*Imported from #210*

---

## 219: Evaluate if AnyElement is still needed

+++
status: closed
priority: none
kind: none
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:58:38Z
closed: 2026-03-31T18:58:38Z
+++

Need to determine if AnyElement is still needed in the codebase.

File: Sources/MetalSprockets/Core/AnyElement.swift

*Imported from #211*

- `2026-04-02T18:39:04Z`: AnyElement IS needed - used by ElementBuilder.buildLimitedAvailability for #available checks in result builders

---

## 222: More labels.

+++
status: closed
priority: none
kind: none
labels: effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:16:34Z
closed: 2026-03-31T18:16:34Z
+++

We've explicit labels to computepass and friends. Add them to more places. Use them in more places.

*Imported from #214*

- `2026-04-02T18:39:04Z`: Duplicate of #48 (Add labels to everything)

---

## 223: Clean up System.update

+++
status: closed
priority: high
kind: none
labels: effort:m, priority:high
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:59:05Z
closed: 2026-03-31T18:59:05Z
+++

*Imported from #215*

- `2026-04-02T18:39:04Z`: Already cleaned up in previous work

---

## 233: Bring back DebugLabelModifier

+++
status: open
priority: low
kind: enhancement
labels: needs-info, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:18Z
+++

*Imported from #225*

---

## 235: Split BodylessElement into SetupElement and WorkloadElement protocols

+++
status: open
priority: medium
kind: enhancement
labels: enhancement, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:50Z
+++

Split BodylessElement into focused protocols:

## Problem
BodylessElement is a monolithic protocol that includes both setup and workload methods, plus requiresSetup. This leads to:
- Empty placeholder methods everywhere
- Unclear intent from the type system
- Manual requiresSetup overrides for workload-only elements

## Proposed Solution
Split into two protocols:
- SetupElement: setupEnter/setupExit
- WorkloadElement: workloadEnter/workloadExit

## Related
- AnyBodylessElement always triggers setup due to closure comparison limitations (was #237)
- This would allow automatic setup detection based on protocol conformance

- `2026-04-03T17:33:50Z`: Related: #67 (formalize element I/O), #152 (onWorkloadExit), #214 (cleanup for removed nodes)

---

## 236: Pipeline elements need proper requiresSetup implementation for shader constants

+++
status: open
priority: high
kind: bug
labels: bug, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:35Z
+++

## Problem

Currently, `RenderPipeline` and `ComputePipeline` have a temporary `requiresSetup` implementation that always returns `false`. This works for now because shaders don't change after initial setup, but it will break when shader constants are introduced.

## Current Implementation

```swift
nonisolated func requiresSetup(comparedTo old: RenderPipeline<Content>) -> Bool {
    // For now, always return false since shaders rarely change after initial setup
    // This prevents pipeline recreation on every frame
    // TODO: Implement proper comparison when shader constants are added
    return false
}
```

## What Needs to Happen

When shader constants are implemented, these elements will need to:

1. **Compare shader functions** - Check if the actual MTLFunction has changed
2. **Compare shader constants** - Check if any constant values have changed
3. **Compare other pipeline configuration** - Vertex descriptors, pixel formats, etc.

## Why This Matters

Shader constants allow specializing shaders at pipeline creation time for better performance. When a constant value changes, the pipeline MUST be recreated. The current `return false` will prevent this, causing incorrect rendering or crashes.

## Acceptance Criteria

- [ ] Implement proper equality/comparison for shader types that includes constants
- [ ] Update `RenderPipeline.requiresSetup` to compare all relevant properties
- [ ] Update `ComputePipeline.requiresSetup` to compare all relevant properties
- [ ] Add tests to verify pipelines are recreated when constants change
- [ ] Add tests to verify pipelines are NOT recreated when nothing changes

## Related Issues

- #231 - The original needsSetup propagation issue
- #235 - The proposed protocol separation for SetupElement/WorkloadElement
- This is a consequence of the temporary fix applied in #231

*Imported from #228*

---

## 237: AnyBodylessElement always triggers setup due to closure comparison limitations

+++
status: closed
priority: medium
kind: enhancement
labels: enhancement, priority:medium
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:20:11Z
closed: 2026-03-31T18:20:11Z
+++

## Problem

`AnyBodylessElement` currently always returns `true` from `requiresSetup` because it wraps closures that cannot be compared for equality. This causes unnecessary setup phases to run, leading to performance issues like:
- LateMTLFXSpatialScaler creation warnings
- Unnecessary pipeline recreation

## Examples of affected code

### MetalFXSpatial
```swift
public var body: some Element {
    AnyBodylessElement()
        .onSetupEnter {
            scaler = try makeScaler()
        }
        .onWorkloadEnter {
            // ...
        }
}
```

Since `AnyBodylessElement` always returns `true` for `requiresSetup`, the MTLFXSpatialScaler gets recreated every frame even when not needed.

## Proposed Solution

As discussed in #235, implement separate protocols for setup-phase and workload-phase elements:
- `SetupElement` - for elements that need setup phase
- `WorkloadElement` - for elements that only need workload phase

This would allow:
1. More precise control over when setup is needed
2. Better performance by avoiding unnecessary setup phases
3. Clearer API design showing element capabilities

## Alternative Solutions

1. Make `AnyBodylessElement` track whether its closures affect setup vs workload
2. Create specialized wrapper types like `WorkloadOnlyElement` that never require setup
3. Allow `AnyBodylessElement` to accept a `requiresSetup` parameter/closure

## Related Issues
- #235 - Separate protocols for setup and workload elements
- #231 - Late pipeline state creation due to parameter changes

*Imported from #229*

- `2026-04-02T18:39:04Z`: Merged into #235 (Split BodylessElement into SetupElement and WorkloadElement protocols)

---

## 239: value vs values is very subtle.

+++
status: open
priority: low
kind: enhancement
labels: enhancement, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:35Z
+++

func parameter(_ name: String, functionType: MTLFunctionType? = nil, values: [some Any])func parameter(_ name: String, functionType: MTLFunctionType? = nil, value: some Any)

At the very least we should improve the asserts.

*Imported from #231*

---

## 240: Get rid of MetalSprocketsSupport

+++
status: open
priority: low
kind: enhancement
labels: enhancement, needs-info, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:35Z
+++

Not really needed now that we broke out geometrylite3d.

Can be turned into batteries included (#202)

*Imported from #232*

---

## 243: Cleanup MTLCreateSystemDefaultDevice() again.

+++
status: closed
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:16:40Z
closed: 2026-03-31T18:16:40Z
+++

*Imported from #235*

- `2026-04-02T18:39:04Z`: Duplicate of #55 (Handle MTLCreateSystemDefaultDevice() everywhere)

---

## 245: Make sure all argument buffers are using useResources() correct.

+++
status: open
priority: high
kind: bug
labels: bug, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T19:19:48Z
+++

Audit argument buffer usage to ensure `useResources()` is called correctly. Metal requires marking resources used by argument buffers so the GPU can track them. Missing calls can cause undefined behavior or crashes.

---

## 246: Assert when same shader compiled multiple times

+++
status: open
priority: high
kind: enhancement
labels: enhancement, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:35Z
+++

Add an assertion or warning when the same shader source is compiled multiple times. This is a performance issue - shaders should be compiled once and cached. Detecting duplicate compilation helps users optimize their code.

---

## 247: Solve shader compilation issue

+++
status: closed
priority: none
kind: bug
labels: bug
created: 2026-02-19T00:00:00Z
updated: 2026-03-31T18:16:46Z
closed: 2026-03-31T18:16:46Z
+++

We still haven't solved the shader compilation problem.

Maybe we just need a best practice.

Maybe we need to make shaders elements

*Imported from #239*

- `2026-04-02T18:39:04Z`: Duplicate of #246 (Assert when same shader compiled multiple times)

---

## 248: Framework should detect or warn when Element body returns 'any Element' instead of 'some Element'

+++
status: open
priority: medium
kind: bug
labels: bug, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:35Z
+++

## Problem

When an Element's body property returns `any Element` instead of `some Element`, the framework silently fails to traverse the element tree properly. This results in render pipelines not being executed and no draw commands being submitted to the GPU, with only "empty render encoder" errors visible in the Metal debugger.

## Example

```swift
// This compiles but doesn't work - RenderPipeline never executes
public var body: any Element {
    get throws {
        return RenderPipeline(...) { ... }
    }
}

// This works correctly
public var body: some Element {
    get throws {
        return RenderPipeline(...) { ... }
    }
}
```

## Impact

- Silent failure with no clear error message
- Very difficult to debug - only symptom is "empty render encoder" in Metal debugger
- The code compiles successfully, making it seem like it should work

## Proposed Solutions

1. **Compile-time detection**: Add a protocol requirement or compiler diagnostic that prevents using `any Element` as the return type for body
2. **Runtime warning**: Detect when an element's body returns an existential type and log a warning
3. **Documentation**: Clearly document that body must return `some Element`, not `any Element`, with explanation of why

## Reproduction

Found in `DebugRenderPipeline` where changing the body return type from `any Element` to `some Element` fixed the issue where no GPU work was being submitted.

*Imported from #240*

---

## 255: Make a FunctionTypes OptionSet

+++
status: open
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:18Z
+++

Create an OptionSet for Metal function types (vertex, fragment, compute, etc.) to replace individual `MTLFunctionType` parameters. Would allow targeting multiple function types at once, e.g., `.parameter("value", functionTypes: [.vertex, .fragment], ...)`.

---

## 256: Metal 4

+++
status: open
priority: low
kind: feature
labels: effort:xl
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:18Z
+++

Adopt Metal 4 APIs where beneficial:
- Evaluate new Metal 4 features
- Update framework to use improved APIs
- Take advantage of performance improvements
- Consider requiring Metal 4 as minimum or providing fallbacks

---

## 259: Look at unifying transform/amplification/uniforms

+++
status: open
priority: low
kind: enhancement
labels: enhancement, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:35Z
+++

Investigate unifying the APIs for transform data, amplification data, and uniforms. These are all ways of passing data to shaders - there may be an opportunity to simplify or consolidate the API.

---

## 260: Rename renderPipelineDescriptorModifier -> renderPipelineDescriptorTransfomer

+++
status: open
priority: low
kind: enhancement
labels: enhancement, effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:35Z
+++

*Imported from #251*

---

## 268: device.supportsFunctionPointers

+++
status: open
priority: medium
kind: enhancement
labels: effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:24Z
+++

Check `device.supportsFunctionPointers` before using function pointers / visible function tables. Add graceful fallback or clear error message when not supported.

---

## 269: Merge RenderView with environment (ProcessInfo) logic

+++
status: open
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:24Z
+++

File: Sources/MetalSprocketsUI/RenderView.swift

The RenderView currently has separate logic for environment and ProcessInfo that should be merged into a unified approach.

*Imported from #261*

---

## 274: Make sampleCount and colorPixelFormat parameters on RenderView

+++
status: open
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:24Z
+++

File: Sources/MetalSprocketsUI/MTKView+Environment.swift

These settings are so important they should be parameters on RenderView instead of environment values.

*Imported from #266*

---

## 280: Make sure all .environment values have helper functions (if appropriate)

+++
status: open
priority: low
kind: task
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:25Z
+++

Audit environment values and add convenience modifiers where appropriate. For example, instead of `.environment(\.device, device)`, provide `.device(device)` where it makes sense.

---

## 282: Implement .transformEnvironment()

+++
status: open
priority: medium
kind: feature
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:25Z
+++

Implement `.transformEnvironment()` modifier similar to SwiftUI's. This allows modifying an environment value based on its current value, rather than just replacing it:
```swift
.transformEnvironment(\.someValue) { value in
    value += 1
}
```

---

## 287: Add @Observation support

+++
status: open
priority: medium
kind: feature
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-03T17:33:25Z
+++

Implement Swift Observation framework support based on the approach from [objcio/S01E268-state-and-bindings PR #1](https://github.com/objcio/S01E268-state-and-bindings/pull/1).

## Key Changes Required

1. **Add Observation import** and integrate with view building:
   - Wrap `body` evaluation in `withObservationTracking`
   - Set `node.needsRebuild = true` in the `onChange` handler
   - Skip `Observable` properties in view equality checks (similar to how `StateProperty` is skipped)

2. **Simplify `isEqual` implementation** using Swift 5.7+ features:
   - Replace the `Wrapped<T>` protocol-based approach with a simpler implementation using `any Equatable` and `_openExistential`-style pattern

3. **Add tests** for:
   - Simple observation with `@Observable` models
   - Bindings passing observable models to child views  
   - Unused binding scenarios (verify only affected views rebuild)

## Reference Implementation

```swift
// Simplified isEqual
func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    guard let lhs = lhs as? any Equatable else { return false }
    func f<LHS: Equatable>(_ lhs: LHS) -> Bool {
        guard let rhs = rhs as? LHS else { return false }
        return lhs == rhs
    }
    return f(lhs)
}

// In buildNodeTree - wrap body evaluation
withObservationTracking {
    let b = body
    // ... build children
} onChange: {
    node.needsRebuild = true
}

// Skip Observable in equality check
if p1 is Observable { continue }
```

## Notes

- Requires Swift 5.10+ and macOS 14+
- Does not include `Bindable` property wrapper implementation (future enhancement)
- See also: [Swift forums discussion on isEqual simplification](https://forums.swift.org/t/comparing-two-any-values-for-equality-is-this-the-simplest-implementation/73816)

---

## 288: Investigate background thread rendering for RenderView

+++
status: closed
priority: low
kind: feature
created: 2026-03-03T00:00:00Z
updated: 2026-03-31T18:27:21Z
closed: 2026-03-31T18:27:21Z
+++

## Context

MTKView's draw(in:) callback fires on the main thread via a dispatch source on the main queue. When SwiftUI layout work is heavy (e.g., inspector forms being re-evaluated during camera rotation), it can starve the display link and drop frame rate.

## Investigation Done

- Confirmed via backtrace that draw(in:) comes through CVDisplayLink → dispatch source → main queue drain
- MTKView has no API to control which thread the delegate callback fires on
- MTKView supports explicit drawing mode (isPaused=true, enableSetNeedsDisplay=false) where you call draw() yourself
- However, MTKView.draw() asserts it's on the main queue — cannot be called from a background thread
- Attempted a CAMetalLayer-based approach (bypass MTKView's draw path, use nextDrawable() directly on a background dispatch timer) but it requires reimplementing too much of MTKView's infrastructure (depth/stencil texture management, resize handling, clear colors, etc.)
- Approach abandoned as too fragile for the benefit

## Options Still Open

1. Fix the SwiftUI side — prevent unnecessary layout during rapid state changes (see MetalSprocketsGaussianSplats#6)
2. Throttle state propagation to SwiftUI (e.g., update inspector at 10fps, not 60fps)
3. Build a dedicated non-MTKView render host that owns its own CAMetalLayer and render thread from the ground up (larger effort, cleaner result)

## Related

- MetalSprocketsGaussianSplats#6: Multi-splat mode FPS drops during camera rotation

- `2026-04-02T18:39:04Z`: Merged into #291 (Audit and improve Swift concurrency)

---

## 289: Make MSState Sendable when Value is Sendable

+++
status: closed
priority: low
kind: enhancement
created: 2026-03-05T00:00:00Z
updated: 2026-03-31T18:27:21Z
closed: 2026-03-31T18:27:21Z
+++

Add `extension MSState: @unchecked Sendable where Value: Sendable {}`. MSState is backed by a reference type (Box<StateBox<Value>>) so it's safe to send across concurrency boundaries. Currently requires `nonisolated(unsafe)` workarounds when capturing @MSState in Tasks.

- `2026-04-02T18:39:04Z`: Unsafe to implement as described. StateBox has no synchronization — _value, dependencies, and hasBeenConnected are all mutated without locking. Box is similarly unprotected. Concurrent access from multiple isolation domains would cause data races. Would need to add a lock to StateBox (or make access actor-isolated) before this conformance is safe.
- `2026-04-02T18:39:04Z`: Merged into #291 (Audit and improve Swift concurrency)

---

## 290: onCommandBufferCompleted and onCommandBufferScheduled modifiers are unreliable and underdocumented

+++
status: closed
priority: high
kind: bug
labels: api, documentation
created: 2026-03-31T16:45:51Z
updated: 2026-03-31T17:21:12Z
closed: 2026-03-31T17:21:12Z
+++

## Problem

The `onCommandBufferCompleted` and `onCommandBufferScheduled` Element modifiers do not fire reliably. When used on a `RenderPass` inside a `RenderView`, the completion handler is never called.

## Reproduction

```swift
RenderView { _, drawableSize in
    try RenderPass {
        // ... render content
    }
    .onCommandBufferCompleted { _ in
        print("This never prints")
    }
}
```

## Expected Behavior

The completion handler should fire after the command buffer completes GPU execution.

## Root Cause (Suspected)

Looking at the implementation in `CommandBufferElement.swift`, the modifier uses `EnvironmentReader` to get the command buffer and `onWorkloadEnter` to register the handler. The command buffer may not be in the environment at the point where the modifier is evaluated, or `onWorkloadEnter` may not be called for all elements in the tree.

## Requirements

1. **Make it work reliably** — The handlers must fire when the command buffer completes/is scheduled
2. **Document clearly** — Add documentation explaining:
   - Where in the element tree these modifiers can be used
   - When the handlers are registered vs when they fire
   - Any ordering/timing considerations
   - Example usage patterns

## Impact

This blocks buffer pooling in MetalSprocketsGaussianSplats (issue #22) where we need to release index buffers back to a pool after GPU completion.

### Tree Structure Analysis

Traced the element tree when using `.onCommandBufferCompleted` on a `RenderPass`:

```
EnvironmentWritingModifiers...
└── CommandBufferElement (sets commandBuffer in workloadEnter)
    └── WorkloadModifier (RenderView's handler)
        └── Group
            └── WorkloadModifier (User's handler)
                └── RenderPass
```

### Environment Propagation

Analyzed how environment values flow:
- Parent's `workloadEnter` runs before children are entered
- Children merge environment from parent before their own `workloadEnter` runs
- The `commandBuffer` set by `CommandBufferElement` should be visible to all descendants

### Tests Written

Added `CommandBufferCompletionTests.swift` with tests that all pass:
- Single frame environment propagation ✓
- Multi-frame environment propagation ✓
- Multiple nested handlers ✓
- Deeply nested structures ✓
- Actual `CommandBufferElement` with real Metal command queue ✓

### Key Finding: Silent Failure

The current implementation silently does nothing if `commandBuffer` is nil:

```swift
if let commandBuffer = environmentValues.commandBuffer {
    // register handler
}
// No else clause - silent failure!
```

### Open Questions

Tests prove the mechanism *should* work, yet the issue reports it doesn't. Possible causes:
1. Something specific to how RenderView rebuilds the tree each frame
2. A timing issue with command buffer commit vs handler registration
3. An edge case in environment propagation in the real RenderView flow

### Recommended Fixes

1. Add warning/error when `commandBuffer` is nil in handlers
2. Add documentation about where these modifiers can/should be used
3. Consider adding a test that more closely mimics the actual `RenderView.draw()` flow

After extensive investigation, we cannot reproduce this bug.

### Testing Performed

1. **Unit tests** (13 tests in `CommandBufferCompletionTests.swift`):
   - Environment propagation from parent `workloadEnter`
   - Multiple frames with tree rebuilding
   - Multiple handlers all firing (no "last wins" behavior)
   - Deeply nested element structures
   - Actual `CommandBufferElement` and `RenderPass` usage
   - Handler registration verification

2. **Live app testing** with real `MTKView`:
   - Single handler: 181+ frames, 100% success
   - Multiple handlers (3): 238+ frames, all handlers fired every frame

3. **Code analysis**: `RenderView` already uses `onCommandBufferCompleted` internally for GPU timing (line 280-281), proving the mechanism works in production.

### Improvements Made

- Added documentation explaining modifiers must be inside `CommandBufferElement` or `RenderView`
- Added documentation that multiple handlers all fire
- Added warning logs when `commandBuffer` is nil (helps debug misuse)
- Added code examples in doc comments

### Possible Original Cause

The modifier may have been used outside of a `CommandBufferElement` context, which would silently fail (now warns).

- `2026-04-02T18:39:04Z`: ## Investigation Findings
- `2026-04-02T18:39:04Z`: ## Cannot Reproduce

---

## 291: Audit and improve Swift concurrency throughout the framework

+++
status: new
priority: medium
kind: none
labels: concurrency, effort:xl
created: 2026-03-31T18:27:17Z
updated: 2026-03-31T18:27:21Z
+++

Consolidate all concurrency-related work:

## Areas to address

- Audit @MainActor usage - determine what truly needs main actor isolation
- Async shader compilation (#79)
- MSState Sendable conformance (#289 notes it's unsafe without synchronization)
- Consider background thread rendering possibilities (#288)
- Address any Swift 6 concurrency warnings

## Goals

- Clear, intentional isolation boundaries
- No data races
- Better performance where possible by moving work off main thread
- Swift 6 ready

## Related closed issues
- #32 Re-visit MainActor usage

---

## 292: Refactor: System is a god object with a split three-phase personality

+++
status: new
priority: medium
kind: enhancement
created: 2026-03-31T19:33:03Z
+++

## Problem

`System` owns the node dictionary, the traversal event list, the active node stack, the dirty identifier set, and the snapshot/debug machinery. Its `update(root:)` method is a 100+ line nested-function behemoth with mutable captures. The `update` / `processSetup` / `processWorkload` lifecycle is a 3-phase sequence callers must invoke in the correct order — there is no single boundary to test. The `activeNodeStack` is an implicit global side-channel that `@MSEnvironment` and `@MSState` both reach into via `System.current` (a `@TaskLocal`). The real bugs hide in the interaction between these phases, but tests mostly verify the shallow 'did the node get created' outcome.

**Modules involved:** System, System+Process, System+Snapshot, System+Dump, System+Support, Node

**Why they're coupled:** Node stores system: weak System? as a back-reference; BodylessElement protocol methods receive Node directly, giving them full access to mutate arbitrary node state; environment propagation, state restoration, and dirty-marking all happen inside a single traversal context with shared mutable state.

**Dependency category:** In-process — no I/O, pure computation and in-memory state.

## Opportunity

Deep-module the System by separating concerns:

1. A TreeReconciler responsible solely for diffing element trees and producing an ordered list of reconciled nodes (the traversal event list). No environment, no state, no phases.
2. A PhaseRunner that takes a frozen traversal event list and drives setup/workload phases across it, managing the active node stack internally without exposing it.
3. A thin System facade that composes these two and owns the node dictionary.

The three-phase call sequence (update -> processSetup -> processWorkload) could be wrapped in a single render(root:) entry point that enforces correct ordering, making it impossible to call phases out of sequence.

The activeNodeStack should become private to PhaseRunner and never accessible to @MSEnvironment via a global side-channel. Environment access during traversal should be passed explicitly.

## Test Impact

Existing tests in SystemTests, NeedsSetupTests, SystemProcessTests, and NodeTests largely test interior mechanics (node identity, needsSetup flags, call order). A deepened module would replace most of these with boundary tests that assert observable rendering outcomes rather than internal node state.

---

## 293: Refactor: MSEnvironmentValues storage parent-chain is an invisible runtime contract

+++
status: new
priority: medium
kind: enhancement
created: 2026-03-31T19:33:38Z
+++

## Problem

Environment values are propagated through a reference-type parent chain (Storage.parent). The configureNode path in Element+SystemExtensions builds a fresh environment and merges the parent storage, while System+Process has a separate 'rebuild environment parent chain' TODO block that patches broken parent links mid-traversal. The cycle-detection in Storage.didSet is an assertion, not a type-level guarantee. The parent-chain design leaks through the abstraction — callers who set environment values must reason about copy-on-write semantics of Storage, and the snapshot/debug layer reaches into storage internals via Mirror. Understanding how a value propagates requires bouncing through EnvironmentValues, Storage, configureNode, applyInheritedEnvironment, and processSetup.

**Modules involved:** MSEnvironmentValues, EnvironmentValues.Storage (parent-chain), Element+SystemExtensions (configureNode), System+Process

**Why they're coupled:** Storage is a class that holds a weak var parent, so reference identity matters; MSEnvironmentValues is a struct wrapping the class, creating COW friction; the parent chain is rebuilt in two separate code paths (update phase and process phase) that can get out of sync. The process-phase patch is a TODO comment noting it may no longer be needed — meaning the two paths may already be inconsistent.

**Dependency category:** In-process — no I/O, pure in-memory value propagation.

## Opportunity

Replace the mutable reference-type parent chain with a value-type snapshot of the resolved environment at each node, computed once during the update phase and frozen before the setup and workload phases begin. This eliminates the need for the mid-process-phase patch and makes the parent-chain cycle check unnecessary.

Concretely: during tree reconciliation, resolve each node's full effective environment as a flat [Key: Any] dictionary (inheriting from parent) and store it as a value type. The Storage class and its parent pointer disappear. MSEnvironmentValues becomes a simple value type with no hidden reference semantics.

This would also fix the Mirror-based snapshot extraction, which currently has to navigate Storage internals to reconstruct values.

## Test Impact

EnvironmentTests and UVEnvironmentValuesTests test shallow behavior (values are readable). No existing tests exercise parent-chain correctness under structural changes or the process-phase patch path. A deepened environment module would have clear boundary tests: set a value on a parent element, assert it is visible to a child element after reconciliation, regardless of how many times the tree is re-evaluated.

---

## 294: Refactor: Reflection/RenderPipeline/ParameterElementModifier inter-phase contract is invisible and untested

+++
status: new
priority: medium
kind: enhancement
created: 2026-03-31T19:33:58Z
+++

## Problem

RenderPipeline.setupEnter creates a Reflection (binding name -> index map) and stores it in node.environmentValues.reflection. ParameterElementModifier.workloadEnter reads the reflection from the environment to resolve named shader bindings. This is a temporal contract across two separate System phases: setup must have run before workload reads reflection. If setup is skipped because needsSetup == false, the reflection is stale or absent. The interface between them — MSEnvironmentValues.reflection — is a plain Optional<Reflection>, not a typed proof that setup ran. The error message in ParameterElementModifier even contains a user-visible workaround hint ('parameter() modifiers must be placed inside a RenderPipeline or ComputePipeline content block, not as a modifier on the pipeline itself'), which is a signal that the contract is invisible in the type system.

**Modules involved:** Reflection, RenderPipeline.setupEnter, ParameterElementModifier.workloadEnter, Parameters

**Why they're coupled:** Reflection is co-owned across a phase boundary using environment slots as an inter-phase mailbox. ParameterElementModifier cannot function without RenderPipeline's setup output. The two elements are structurally required to be parent/child in the tree, but nothing enforces this at compile time. The stale-reflection case (setup skipped, workload runs with old reflection) is entirely untested.

**Dependency category:** In-process — no I/O, pure in-memory.

## Opportunity

Make the Reflection dependency explicit rather than implicit. Options include:

1. Have RenderPipeline expose its Reflection as a typed output that ParameterElementModifier receives as a constructor argument rather than reading from the environment. The environment slot for reflection would be removed.
2. Alternatively, define a typed RenderPipelineContext that RenderPipeline produces during setup and that is passed to its content closure, making it impossible to use ParameterElementModifier outside that context.
3. At minimum, add a non-optional typed wrapper around the reflection environment slot — e.g. a PipelineContext value type — so that accessing reflection outside of a configured pipeline produces a compile-time or clear runtime error, not a confusing 'must be placed inside' hint.

The deeper fix is option 2: RenderPipeline's content closure receives a context carrying the live reflection, and parameter bindings are expressed as closures over that context rather than modifiers that fish the reflection out of a global environment bag.

## Test Impact

ParametersTests and FunctionConstantsTests currently exercise the happy path only. The stale-reflection case (call processWorkload without processSetup, or with needsSetup=false on an element that changed shaders) is unverified. A deepened interface would make the stale-reflection case structurally impossible and the tests would verify that named bindings resolve correctly given a live reflection context.

---

## 295: Refactor: ShaderLibrary / LibraryRegistry / ShaderCache are three interlocked process-global singletons

+++
status: new
priority: low
kind: enhancement
created: 2026-03-31T19:34:21Z
+++

## Problem

ShaderLibrary, LibraryRegistry, and ShaderCache form a layered caching stack where each layer is individually shallow and tightly coupled to the others. LibraryRegistry is a process-global singleton (OSAllocatedUnfairLock-protected dictionary keyed by ShaderLibrary.ID). ShaderCache is per-ShaderLibrary.State, but State is interned by LibraryRegistry, so the cache is effectively process-global too. ShaderLibrary provides the public face. To understand how a shader gets loaded, you must trace: ShaderLibrary.function -> ShaderCache.get -> LibraryRegistry.getOrCreate -> MTLLibrary. FunctionConstants adds a fourth step: create unspecialized function -> introspect constantsDictionary -> create specialized function -> cache.

**Modules involved:** ShaderLibrary, LibraryRegistry, ShaderCache, ShaderNamespace, Shaders

**Why they're coupled:** The global registry means all tests share state unless a real MTLDevice is created per-test. ShaderCache has no injectable interface — it is accessed only via ShaderLibrary.State, never injected. FunctionConstants.buildMTLConstants takes an MTLLibrary directly, coupling constant resolution to the live library. The namespace resolution logic (searching for constants ending with ::name) lives inside FunctionConstants but requires introspecting the real library's functionConstantsDictionary, making it untestable without a GPU.

**Dependency category:** True external — MTLDevice and MTLLibrary are Apple-framework objects that require real GPU hardware.

## Opportunity

Define a ShaderLoader port (protocol) that owns the responsibilities currently scattered across these three types:

    protocol ShaderLoader {
        func function(named: String, type: MTLFunctionType, constants: FunctionConstants) throws -> MTLFunction
    }

The real implementation wraps LibraryRegistry + ShaderCache + MTLLibrary. A test implementation returns pre-built MTLFunction stubs or records calls without requiring a GPU device. ShaderLibrary becomes a value type that holds a ShaderLoader rather than a ShaderLibrary.State. LibraryRegistry becomes an internal implementation detail of the real ShaderLoader, not a globally-visible type.

FunctionConstants.buildMTLConstants should be moved onto the ShaderLoader port so constant resolution can be tested with a mock library that returns a fixed functionConstantsDictionary.

The process-global singleton (LibraryRegistry.shared) should become an optional default — callers who need isolation (tests, or multi-device rendering) can inject their own loader.

## Test Impact

FunctionConstantsTests currently creates a real MTLDevice and compiles real shader source. Cache hit/miss behavior, namespace resolution, and the error paths in function(type:named:) are entirely untested. A ShaderLoader port would allow unit tests for all of these without a GPU: verify cache hits return the same MTLFunction; verify ambiguous namespace constants throw the right error; verify missing constants produce the correct diagnostic.

---

## 296: Refactor: RenderViewViewModel duplicates frame-orchestration logic that OffscreenRenderer also contains

+++
status: new
priority: medium
kind: enhancement
created: 2026-03-31T19:34:45Z
+++

## Problem

RenderViewViewModel is simultaneously a SwiftUI @Observable state object, an MTKViewDelegate, a System lifecycle driver, a frame timing accumulator, and an error handler. Its draw(in:) method is approximately 80 lines with nested do/try and inline timing instrumentation. It owns the three-phase render sequence (system.update -> system.processSetup -> system.processWorkload), tracks frame timing via FrameTimingTracker, accumulates GPU time from an async completion handler via a nonisolated(unsafe) var lastGPUTime, detects MSAA sample count changes, and handles drawable-size changes.

Separately, OffscreenRenderer.render duplicates the same three-phase sequence with identical calls to system.update / processSetup / processWorkload. There is no shared abstraction that captures 'given a System and a root element, run one frame.' Element+Run.swift presumably provides a similar capability, adding a third copy of this pattern.

**Modules involved:** RenderView, RenderViewHelper, RenderViewViewModel, OffscreenRenderer, Element+Run

**Why they're coupled:** The three-phase orchestration is repeated verbatim in multiple unrelated types. FrameTimingTracker, error handling, MSAA change detection, and phase ordering all live inside draw(in:) with no seam to test them independently. The nonisolated(unsafe) var for GPU time is a data race waiting to happen and exists only because the frame orchestration and the async GPU completion handler share no typed boundary.

**Dependency category:** In-process for the orchestration logic; True external (MTKView, GPU) for the rendering driver.

## Opportunity

Extract a FrameRenderer (or RenderSession) value/class that owns the three-phase sequence and is the single place that calls update/processSetup/processWorkload. It accepts a root element, a pre-configured environment (device, commandQueue, renderPassDescriptor, drawableSize), and a System instance, and returns a result (timing info, errors). Both RenderViewViewModel and OffscreenRenderer become thin callers of FrameRenderer.

FrameTimingTracker and GPU time accumulation belong on FrameRenderer, not on the MTKView delegate. The nonisolated(unsafe) GPU time property disappears — FrameRenderer owns the completion handler and stores the result in its own typed state.

Error handling policy (log vs. fatalError based on RenderViewDebugging flags) stays in the view layer.

The three-phase ordering contract ('you must call these in this sequence') becomes an implementation detail of FrameRenderer, not a caller responsibility. This also fixes the OffscreenRenderer design: rather than creating a one-shot System per render call, OffscreenRenderer would own a FrameRenderer that persists across renders.

## Test Impact

CommandBufferCompletionTests, MSAATests, and OffscreenVideoRendererTests all test end-to-end by going through OffscreenRenderer or the full render view stack. No tests verify the frame-orchestration logic in isolation: that MSAA changes trigger markAllNodesNeedingSetup, that a drawable-size change propagates to the system, or that a thrown error inside the frame does not corrupt system state for subsequent frames. A FrameRenderer with a clear interface would make all of these testable without MTKView or a display.

---

## 297: RenderView leaks closures - resources not released on view removal

+++
status: closed
priority: high
kind: bug
created: 2026-04-01T21:40:11Z
updated: 2026-04-01T22:16:34Z
closed: 2026-04-01T22:16:34Z
+++

When a `RenderView` is removed from the SwiftUI view hierarchy (e.g. switching tabs in a TabView), the closures and Metal resources captured by the render closure are not released.

**Reproduction:** In MetalSprocketsSlug (https://github.com/schwa/MetalSprocketsSlug or ~/Shared/Scratch Projects/MetalSprocketsSlug), switch between the 'Spinning Sphere' and 'Text Panel' tabs. Metal resources (textures, buffers, pipelines) from the deactivated tab are never freed.

**Expected:** When a `RenderView` is removed from the hierarchy, all captured closures and their retained resources should be released.

**Workaround:** The demo app manually nils out state in `.onDisappear`, but this doesn't fully solve it since the RenderView's own closure captures are retained.

See also: MetalSprocketsSlug issue #16.

- `2026-04-02T18:39:04Z`: Fix implemented: RenderViewHelper now uses optional @State viewModel, created in .onAppear and nil'd in .onDisappear. This releases the view model (and all Metal resources held by System/nodes/content closure) when the view leaves the hierarchy. Per-frame allocation churn also fixed (#298) by not creating the view model in the struct init. Needs confirmation with MetalSprocketsSlug before closing.
- `2026-04-02T18:39:04Z`: Confirmed fixed. SlugBufferStorage deinit fires correctly when switching tabs in MetalSprocketsSlug demo. Resources released on onDisappear.

---

## 298: RenderViewHelper allocates RenderViewViewModel on every SwiftUI body evaluation

+++
status: closed
priority: high
kind: bug
created: 2026-04-01T21:52:49Z
updated: 2026-04-01T22:16:58Z
closed: 2026-04-01T22:16:58Z
+++

RenderViewHelper creates a new RenderViewViewModel in its struct init as the default value for @State. SwiftUI only uses this value once (the first time), but the init expression runs every time the struct is recreated — which happens every frame when parent state changes (e.g. frame timing callback updating @State). This means a class instance + System() is heap-allocated and immediately discarded ~60 times per second for nothing.

- `2026-04-02T18:39:04Z`: Fixed: viewModel is now @State optional, created lazily in .onAppear instead of in the struct init. No more per-frame allocation churn.
- `2026-04-02T18:39:04Z`: Fixed alongside #297. viewModel no longer created in struct init.

---

## 299: Add regression test or assertion to detect per-frame RenderViewViewModel allocation

+++
status: new
priority: critical
kind: task
created: 2026-04-01T21:53:08Z
updated: 2026-04-03T04:07:21Z
+++

After fixing #298 (RenderViewHelper allocating a new RenderViewViewModel every frame), we need a way to detect if this regresses. Options: a unit test that counts allocations, a debug-mode assertion that fires if RenderViewViewModel.init is called more than once per RenderView identity, or Instruments signpost tracking. Without this, it's easy to accidentally reintroduce the per-frame churn.

---

## 300: Example app: MTKView depth texture uses Private storage mode instead of Memoryless

+++
status: new
priority: low
kind: bug
created: 2026-04-01T22:03:32Z
+++

Metal validation warning: Texture 0xb6628b200 "MTKView Depth" has storage mode Private but was a transient render target accessed exclusively by the GPU. Should use .storageModeMemoryless for the depth attachment to avoid wasting VRAM on a texture that does not need to persist between render passes. Seen in the spinning cube demo.

---

## 301: Add dismantleNSView/dismantleUIView to ViewAdaptor

+++
status: new
priority: low
kind: enhancement
created: 2026-04-01T22:07:25Z
+++

ViewAdaptor wraps NSViewRepresentable/UIViewRepresentable but doesn't implement the static dismantle methods. Adding dismantleNSView and dismantleUIView would let us pause the MTKView and clear its delegate when SwiftUI tears down the representable — preventing stray draw callbacks after the view model is released. Belt-and-suspenders for the .onDisappear fix in #297.

---

## 302: .parameter() uses MemoryLayout.size instead of .stride, causing Metal validation errors

+++
status: new
priority: critical
kind: bug
created: 2026-04-02T00:38:43Z
updated: 2026-04-02T00:38:49Z
+++

When passing a struct via `.parameter(name, value:)`, MetalSprockets uses `MemoryLayout<T>.size` to determine the buffer length. Metal expects `MemoryLayout<T>.stride` which includes trailing padding for alignment.

**Example:** A struct with `float4x4` (64 bytes) + `float2` (8 bytes) has:
- `.size` = 72 bytes
- `.stride` = 80 bytes (padded to 16-byte alignment)

Metal's shader reflection reports the argument needs 80 bytes, but `.parameter()` only provides 72, causing:

```
Vertex Function(slug_vertex): argument view[0] from Buffer(1) with offset(0) and length(72) has space for 72 bytes, but argument has a length(80).
```

**Workaround:** Add explicit padding to the Swift struct to make `.size` == `.stride`.

**Fix:** `.parameter()` should use `MemoryLayout<T>.stride` when calling `setVertexBytes` / `setFragmentBytes`.

---

## 303: Redirect docs.metalsprockets.com

+++
status: new
priority: medium
kind: none
created: 2026-04-02T13:55:05Z
+++

Option 2: Configure DocC to publish to root

---

## 304: Make MetalSprocketsShaders more opinionated.

+++
status: new
priority: medium
kind: none
created: 2026-04-02T16:16:32Z
+++

Some of MetalSprokcetsAddsOns can come in - specifically the macros we have for textures etc

---

## 305: Add cross-environment Metal/Swift macros to MetalSprocketsShaders

+++
status: closed
priority: medium
kind: feature
created: 2026-04-02T18:29:46Z
updated: 2026-04-02T18:39:04Z
closed: 2026-04-02T18:39:04Z
+++

Move the cross-environment preprocessor macros from MetalSprocketsAddOns into MetalSprockets(Shaders), since they are fundamentally useful for any MetalSprockets-based project.

The macros live in `MetalSprocketsAddOns/Sources/MetalSprocketsAddOnsShaders/include/Support.h` under the "Cross-environment macros" section. They allow shared struct definitions between Metal shaders and Swift/ObjC by expanding differently depending on `__METAL_VERSION__`:

```c
TEXTURE2D(TYPE, ACCESS)    // metal::texture2d<T,A> on GPU, MTLResourceID on CPU
DEPTH2D(TYPE, ACCESS)      // metal::depth2d<T,A> on GPU, MTLResourceID on CPU
TEXTURECUBE(TYPE, ACCESS)  // metal::texturecube<T,A> on GPU, MTLResourceID on CPU
SAMPLER                    // metal::sampler on GPU, MTLResourceID on CPU
BUFFER(ADDRESS_SPACE, TYPE) // ADDRESS_SPACE TYPE on GPU, TYPE on CPU
ATTRIBUTE(INDEX)           // [[attribute(INDEX)]] on GPU, empty on CPU
```

Also includes `MS_ENUM(...)` for cross-environment enum declarations (modeled after `CF_ENUM`).

After moving, MetalSprocketsAddOns should import these from MetalSprockets instead of defining them locally.

---

## 306: BlitPass EnvironmentReader cannot access renderPassDescriptor since viewModel became optional

+++
status: closed
priority: high
kind: bug
created: 2026-04-03T04:04:18Z
updated: 2026-04-03T04:07:55Z
closed: 2026-04-03T04:07:55Z
+++

Commit d7f64a82 ('Fix RenderView per-frame allocation churn and resource leak on view removal') changed RenderViewHelper's viewModel from a non-optional @State to an optional one, created lazily in .onAppear. This means .environment(viewModel) can pass nil into the element environment.

This breaks any BlitPass that uses EnvironmentReader to access \.renderPassDescriptor — for example, to blit a texture into the stencil attachment before a render pass. When the environment value is nil, the blit silently doesn't execute. The stencil buffer stays all zeros, so a stencil test with compareFunction .equal (reference 0) passes everywhere and no clipping occurs.

Repro: MetalSprocketsExamples StencilDemoView — the checkerboard stencil clipping no longer works. The triangle renders fully unclipped. Reverting MetalSprockets to 96197d4 (the commit before this change) restores correct behavior.

The core issue is that the viewModel (and any environment values it provides) must be available by the time the first frame's element tree is evaluated, not deferred to .onAppear.

- `2026-04-03T04:07:55Z`: Fixed by creating viewModel eagerly in init while keeping .onDisappear cleanup.

---

## 307: Crash in System.shouldUpdateNode: Set.contains called on NSCFNumber

+++
status: new
priority: high
kind: bug
created: 2026-04-03T23:14:30Z
updated: 2026-04-03T23:14:59Z
+++

App crashes with `NSInvalidArgumentException: -[__NSCFNumber member:]: unrecognized selector sent to instance 0x8000000000000000` during `System.shouldUpdateNode`.

The crash occurs in `System.update(root:)` → `processNode` → `reuseNode` → `shouldUpdateNode` at System.swift:237, where `Set.contains` is called on what appears to be a corrupted or mistyped value — an `NSCFNumber` is being treated as a `Set` member.

The stack shows deeply nested `_ConditionalContent` and `ParameterElementModifier<Draw>` types being traversed. The crash happened while cycling through demos via URL scheme (`metalsprockets-examples://next`). Unknown which specific demo triggered it.

Key frames:
```
frame #14: System.shouldUpdateNode(...) at System.swift:237:29
frame #15: System.reuseNode(...) at System.swift:197:12
frame #16: System.processNode(...) at System.swift:183:20
```

Instance `0x8000000000000000` suggests a tagged pointer or sentinel value being misinterpreted as an object.

- `2026-04-03T23:14:59Z`: Second occurrence: same crash, same stack trace. Appears to happen intermittently while navigating between demos. Both times the GameOfLife element tree is visible in the stack. Likely triggered by demo switching while the render loop is mid-update.

---

## 308: Demo app looks broken on iPad Simulator

+++
status: new
priority: medium
kind: bug
created: 2026-04-09T18:33:18Z
+++

Running the demo app on iPad Pro 11-inch (M5) simulator (iOS 26.4), the UI is essentially blank/empty. Shows a white card with faint horizontal separator lines and a green '60' FPS counter in the top-right, but no actual rendered content is visible. The entire lower portion of the screen is just empty grey. Appears the Metal rendering surface isn't displaying anything.

---

## 309: Verify MSAA is actually working — demo cube still looks aliased

+++
status: new
priority: low
kind: bug
created: 2026-04-09T19:09:14Z
+++

The demo app claims MSAA 4x is enabled (overlay says so) but the cube edges still look aliased. Need to verify the MSAA pipeline is actually functioning correctly.

---

## 310: fpsColor should be based on target framerate, not hardcoded thresholds

+++
status: new
priority: low
kind: enhancement
created: 2026-04-09T19:09:28Z
+++

FrameTimingView.fpsColor(for:) uses hardcoded thresholds (55 = green, 30 = yellow, else red). These should be relative to the target framerate (e.g. 120Hz displays would show yellow at 55fps which is wrong).

---

## 311: RenderView renders blank when used with .toolbar on macOS

+++
status: new
priority: medium
kind: bug
created: 2026-04-09T20:03:35Z
+++

MTKView-backed RenderView renders nothing when a .toolbar modifier is applied (with or without NavigationStack). Resizing the window triggers rendering. Likely the MTKView gets zero initial size from the toolbar layout pass and never redraws when it gets a real size. Overlay-based UI works fine as a workaround.

---

## 312: Metal GPU performance HUD disappears during drag/pan gestures

+++
status: new
priority: low
kind: bug
created: 2026-04-09T20:12:59Z
+++

The Metal GPU performance overlay (enabled via Xcode scheme) disappears while dragging/panning in RenderView. It reappears when the gesture ends. Likely a SwiftUI overlay/z-ordering issue during gesture handling.

---

## 313: Expose frame timing statistics from ImmersiveRuntime

+++
status: closed
priority: medium
kind: feature
created: 2026-04-09T21:58:25Z
updated: 2026-04-09T22:25:45Z
closed: 2026-04-09T22:25:45Z
+++

ImmersiveRuntime runs its own render loop but doesn't expose frame timing statistics like RenderView does via .onFrameTimingChange. Consumers have no way to get FPS or frame duration for immersive rendering without tracking timestamps manually. Add FrameTimingStatistics support to ImmersiveRenderContent or ImmersiveContext.

---

## 314: Depth stencil state not invalidated when depthCompare function changes

+++
status: new
priority: critical
kind: bug
created: 2026-04-13T21:37:45Z
updated: 2026-04-13T21:38:52Z
+++

When using .depthCompare() with different compare functions across frames (e.g. switching between .lessEqual and .greaterEqual), the depth stencil state is cached from the first configuration and not recreated. The Metal debugger confirmed the stencil state remained .lessEqual even after requesting .greaterEqual. Discovered while implementing switchable inverse-Z shadow mapping in MetalSprocketsAddOns.

---

## 315: @MSState does not update when element is reconstructed with different init values

+++
status: new
priority: critical
kind: bug
created: 2026-04-13T22:01:50Z
+++

@MSState persists its initial value across frames and never updates, even when the element is reconstructed with a new value. This means function constants or other pipeline configuration stored in @MSState cannot be changed at runtime without destroying and recreating the entire RenderView (e.g. via .id()).

Example: an element with `@MSState var fragmentShader: FragmentShader` initialized with different function constants each frame will keep the first frame's shader forever.

This is the same root cause as #314 (cached depth stencil state). Both are cases where MetalSprockets caches state that should be invalidated when the element's configuration changes.

---

## 316: Add .depthBias() Element modifier

+++
status: new
priority: low
kind: feature
created: 2026-04-15T23:43:17Z
+++

Expose Metal's setDepthBias(_:slopeScale:clamp:) as a declarative Element modifier, similar to .depthCompare(). Usage:

```swift
FlatShader(...) { ... }
    .depthBias(-0.1, slopeScale: -1.0, clamp: -0.01)
```

Currently consumers have to call encoder.setDepthBias() inside a Draw closure, which bypasses the declarative pipeline and can conflict with other state.

---
