# ISSUES.md

---

## 11: Address Type Safety

+++
status: open
priority: medium
kind: enhancement
labels: effort:l, api, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:34:35Z
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
labels: effort:l, api, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
+++

It would be nice if `ParameterValues` had better constructors so that we know 2nd parameter of `.buffer(…, …)` is an offset in the buffer and to get rid of the `T` generic parameter.

Make make this a struct… that takes closures that will call `MTLXXXCommandEncoder.setXXXX` appropriately.

*Imported from #5*

- `2026-04-03T17:33:50Z`: Related: #54 (consolidate parameter nodes)

---

## 19: Refactor OffscreenRenderer architecture

+++
status: closed
priority: medium
kind: enhancement
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T19:47:39Z
closed: 2026-08-08T19:47:39Z
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
labels: effort:l, api, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
+++

Consolidate modifier architecture improvements:

- ElementModifier is not a true Element (was #22)
- Bring back modifiers (was #184)
- Investigate reducing closure usage in modifiers (was #186)

Related issues:

- `2026-02-19T00:00:00Z`: #186 notes closures make element comparison impossible
- `2026-02-19T00:00:00Z`: Need to decide if modifiers should be true Elements or a separate concept
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
labels: effort:l, api, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
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
status: closed
priority: high
kind: bug
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T02:54:49Z
closed: 2026-04-21T02:54:49Z
+++

*Imported from #26*

- `2026-04-09T20:13:12Z`: This is the same issue as #312 — the Metal GPU performance HUD disappears/flickers during drag gestures. Also note: flickering is reduced when shader validation is enabled (slower frame rate masks the issue).
- `2026-04-21T02:54:49Z`: No longer reproducing — FPS counter flicker appears resolved, likely by the viewModel/frame-timing work (#298, #337).

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
status: closed
priority: low
kind: enhancement
labels: effort:l, needs-info
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T15:45:16Z
closed: 2026-08-08T15:45:16Z
+++

```
// TODO: SwiftUI.Environment adopts DynamicProperty.
```

File: Sources/MetalSprockets/Core/EnvironmentValues.swift

*Imported from #34*

\- `2026-08-08T15:45:16Z`: Implemented as a public protocol, no macro needed.

Added MSDynamicProperty (public) with two optional requirements — update(in:) before the element's body is evaluated and persist(in:) after — plus MSDynamicPropertyContext, a public per-property context exposing label, environmentValues, persistedValue(forKey:)/setPersistedValue(_:forKey:) and invalidate(). Node stays internal; the context is the public surface.

MSState and MSObservedObject now conform instead of the internal StateProperty / AnyObservedObject protocols, which are deleted. Element.configureNode does two uniform Mirror passes instead of three ad-hoc ones.

Also fixes a real bug found on the way: the old observeObjects loop used 'return' instead of 'continue', so an @MSObservedObject declared after any other stored property never registered a dependency and never triggered rebuilds. Regression test added in ObservableObjectTests.

Not done: MSEnvironment still resolves lazily from System.current at wrappedValue access rather than caching a value during update(in:). That is #212's territory and would change when the value is snapshotted.

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
status: closed
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T03:11:06Z
closed: 2026-04-21T03:11:06Z
+++

Ensure all Metal resources have descriptive labels set:
- MTLBuffer
- MTLTexture
- MTLRenderPipelineState
- MTLComputePipelineState
- Debug groups (pushDebugGroup/popDebugGroup)

This makes GPU debugging much easier in Xcode and Instruments.

- `2026-04-21T03:11:06Z`: Largely done. Pipelines (Render/Compute/Mesh), encoders, and framework-owned textures (MSAA, offscreen) all set descriptive labels. The remaining piece — pushDebugGroup/popDebugGroup — is tracked separately as #340.

---

## 49: Revisit MTLCaptureManager

+++
status: closed
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T03:11:06Z
closed: 2026-04-21T03:11:06Z
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

- `2026-04-21T03:11:06Z`: Addressed by the existing .capture(_:target:destination:) RenderView modifier (see RenderView.swift). Toggles MTLCaptureManager frame scopes declaratively, wired to a Bool, destination configurable. Exactly the 'higher-level API for RenderView' this issue asked for.

---

## 50: Provide a hook for GPU counters

+++
status: closed
priority: low
kind: feature
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:48:52Z
closed: 2026-08-08T20:48:52Z
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
status: closed
priority: low
kind: feature
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T03:17:54Z
closed: 2026-04-21T03:17:54Z
+++

Add a `.disabled(_ isDisabled: Bool)` modifier that skips an element's rendering when true. Similar to SwiftUI's `.hidden()`. Useful for:

- `2026-02-19T00:00:00Z`: Toggling effects on/off for debugging
- `2026-02-19T00:00:00Z`: A/B comparisons
- `2026-02-19T00:00:00Z`: Conditional rendering without restructuring the element tree
- `2026-04-21T03:17:54Z`: Added .workloadEnabled(_ enabled: Bool = true) element modifier. When false, the element and its entire subtree skip the workload phase (no draws/dispatches/blits) while setup still runs, so pipeline state stays warm and toggling is cheap. Backed by a new BodylessElement.skipsWorkload(_:) protocol method and subtree-skipping logic in System.processWorkloadWithSkipping. Covered by WorkloadEnabledTests (7 cases). Structural removal is still expressible with plain if/ConditionalContent.

---

## 54: Put parameters into one RenderPass object instead of having a bunch of nested ParameterRenderPasss

+++
status: closed
priority: medium
kind: enhancement
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T15:55:16Z
closed: 2026-08-08T15:55:16Z
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
- `2026-08-08T15:55:16Z`: Consecutive .parameter() modifiers now collapse into a single ParameterElementModifier node (parameters merged, nearest-to-content binding wins).

---

## 55: Handle MTLCreateSystemDefaultDevice() everywhere

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T18:26:32Z
closed: 2026-08-08T18:26:32Z
+++

Audit usage of `MTLCreateSystemDefaultDevice()` throughout the codebase.

## Current situation
- On Apple Silicon (iPhones, ARM Macs) this never returns nil
- On Intel Macs it can return nil (no Metal support)
- Code smell: if Apple adds multi-GPU hardware in the future, using the 'default' device everywhere may be wrong

## Not urgent
This isn't a problem today, but could become one. Consider:

- `2026-02-19T00:00:00Z`: Passing device explicitly through the API where possible
- `2026-02-19T00:00:00Z`: Having a single validated device instance
- `2026-02-19T00:00:00Z`: Being prepared for multi-GPU scenarios
- `2026-08-08T06:55:17Z`: Punting: this needs a design decision rather than a mechanical change. Today all 11 call sites already funnel through MetalSupport._MTLCreateSystemDefaultDevice() (fatalErrors when nil), and the remaining sites (ShaderLibrary/Shaders compilation, MetalFX spatial/temporal, ComputeDispatch's apple4 capability check, OffscreenRenderer, RenderView fallback) are all places where no device is available from the caller or environment yet. Options: (a) require an explicit device on the public initializers of those types, (b) resolve the device from the element environment at setup time instead of construction time, or (c) leave as-is and document the single-default-device assumption. Which do you want?
- `2026-08-08T18:26:32Z`: Resolution: keep eager shader compilation and the default-device fallback, but make the device expressible and the mismatch loud. ShaderLibrary.init(bundle:device:)/init(source:options:device:) and ShaderProtocol.init(source:logging:device:)/init(library:name:device:) now take an optional device; RenderPipeline, ComputePipeline and MeshRenderPipeline check at setup that every shader stage was built on the pipeline's device and throw a hinted error otherwise; the ShaderLibrary docs spell out the single-default-device assumption. Runner/OffscreenRenderer/RenderView already accepted a device; ARKitSessionModifier builds its texture cache before any element tree exists and keeps the default.

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
labels: effort:m, api, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
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
labels: effort:l, api, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
+++

Formalize which environment keys each element reads (inputs) and writes (outputs).

## Problem
It's confusing what parts of the Metal stack each element is responsible for. Elements implicitly depend on certain environment values being set.

## Proposed solution
Use an extension on Node (possibly with parameter packs) to explicitly declare input/output environment keys. This would:

- `2026-02-19T00:00:00Z`: Make data flow explicit
- `2026-02-19T00:00:00Z`: Catch missing dependencies at compile time or with clear runtime errors
- `2026-02-19T00:00:00Z`: Document what each element needs and provides
- `2026-04-03T17:33:50Z`: Related: #235 (split BodylessElement protocols)

---

## 70: Improve Attachment flow

+++
status: open
priority: medium
kind: enhancement
labels: effort:l, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
+++

We need a nice clean way to allow the user to customise attachments incl (but not limited to) color, depth, stencil etc.

*Imported from #62*

- `2026-04-02T18:39:04Z`: Needs concrete examples of what's painful today before addressing this.

---

## 73: Fix all SwiftLint disable comments

+++
status: closed
priority: low
kind: task
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T16:32:10Z
closed: 2026-08-08T16:32:10Z
+++

*Imported from #65*

- `2026-08-08T16:32:10Z`: Audited all 19 disable comments. Fixed the code for 9 of them (ElementBuilder and RenderViewDebugging are now caseless enums, convenience_type enabled; ID added to type_name excluded; two force_try sites replaced with do/catch + fatalError or a rethrow; three self_binding guards use pattern matching; two orphaned_doc_comment cases fixed by moving stray comments; MTKView.configure(from:) split into three helpers). The 10 that remain are genuine and now carry a one-line reason each (indentation_width in embedded Metal source, identical_operands in equality tests, discouraged_optional_boolean/-collection three-state APIs, accessibility_label_for_image on SharePreview, function_parameter_count, MTLCreateSystemDefaultDevice in ARKit setup). cyclomatic_complexity stays off pending #353.

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
status: closed
priority: low
kind: task
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T04:28:44Z
closed: 2026-04-21T04:28:44Z
+++

Audit Metal type extensions in MetalSprocketsSupport (especially buffer-related code):

- `2026-02-19T00:00:00Z`: Remove unused extensions
- `2026-02-19T00:00:00Z`: Fix any inefficient implementations
- `2026-02-19T00:00:00Z`: Ensure consistency and good practices
- `2026-02-19T00:00:00Z`: Check for duplication with MetalKit built-in functionality
- `2026-04-21T04:28:44Z`: Scope stale — referenced MetalSupport.swift and buffer extensions no longer exist in MetalSprocketsSupport.

---

## 82: Emit OS logging POIs for each frame

+++
status: closed
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T04:29:47Z
closed: 2026-04-21T04:29:47Z
+++

Add OSSignposter points of interest (POIs) for frame timing. This makes frames visible in Instruments' timeline, helping with profiling.

```swift
var poi = OSSignposter(subsystem: "...", category: .pointsOfInterest)
let id = poi.makeSignpostID()
let state = poi.beginInterval(#function, id: id, "\(value)")
// ... frame work ...
poi.endInterval(#function, state)
```

- `2026-04-21T04:29:47Z`: Already implemented — signposter uses .pointsOfInterest category (Sources/MetalSprocketsUI/Logging.swift, also in MetalSprockets/Support/Logging.swift), and RenderViewViewModel.draw() wraps each frame in withIntervalSignpost.

---

## 86: Clean up shader function lookup in ShaderLibrary

+++
status: closed
priority: low
kind: task
labels: effort:m, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:19:22Z
closed: 2026-08-08T20:19:22Z
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
labels: effort:l, source:todo, has-subtasks, deferred
depends: 358, 359, 360, 361
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
+++

Consolidate issues about environment and descriptor access:

- Users cannot modify the environment in CommandBufferElement (was #89)
- No opportunity to modify the descriptor in CommandBufferElement (was #90)
- RenderPipeline copies from render pass descriptor instead of getting from environment (was #95)

The goal is a consistent pattern for environment-based configuration throughout the Metal element stack.

\- `2026-08-08T20:07:28Z`: Split into subtasks:

- #358 — Make the command buffer descriptor configurable via the environment (effort:s)
- #359 — Make Metal logging a per-subtree environment value (effort:s)
- #360 — Publish render attachment formats into the environment (effort:m)
- #361 — Make RenderPipeline read attachment formats from the environment (effort:m, depends on #360)

#358 and #359 are independent; #360 must land before #361.

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
status: closed
priority: low
kind: task
labels: effort:m, source:todo, needs-info
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T04:30:29Z
closed: 2026-04-21T04:30:29Z
+++

File: Sources/MetalSprockets/Metal/RenderPipelineDescriptorModifier.swift (if it exists)

*Imported from #83*

- `2026-04-21T04:30:29Z`: Subsumed by #89 (env/descriptor modification improvements) and #22 (modifier architecture). The 'is it necessary' question is really a design question covered by those.

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
status: closed
priority: low
kind: enhancement
labels: effort:m, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T06:05:30Z
closed: 2026-08-08T06:05:30Z
+++

Improve the `.parameter(_:color:)` modifier:

- `2026-02-19T00:00:00Z`: Consider reading colors from SwiftUI's environment (e.g., accent color, tint)
- `2026-02-19T00:00:00Z`: Handle SRGB color space correctly (currently uses deviceRGB)
- `2026-02-19T00:00:00Z`: File: Sources/MetalSprocketsUI/Parameter+SwiftUI.swift
- `2026-08-08T06:05:30Z`: Closing: no longer valid — vague scraped TODO with no remaining actionable context.

---

## 104: ViewAdaptor should be internal but is currently used externally

+++
status: closed
priority: medium
kind: task
labels: source:todo, effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T03:20:48Z
closed: 2026-04-21T03:20:48Z
+++

Make `ViewAdaptor` internal instead of public. It's only used by RenderView internally.

- `2026-04-21T03:20:48Z`: ViewAdaptor is now internal. Only used by RenderView within MetalSprocketsUI.

---

## 106: This is messy and needs organisation and possibly deprecation of unused elements.

+++
status: closed
priority: low
kind: task
labels: effort:m, source:todo
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T06:05:30Z
closed: 2026-08-08T06:05:30Z
+++

Clean up UVEnvironmentValues+Implementation.swift (should probably be renamed to MSEnvironmentValues+Implementation.swift):

- `2026-02-19T00:00:00Z`: Organize environment value definitions
- `2026-02-19T00:00:00Z`: Remove/deprecate unused values
- `2026-02-19T00:00:00Z`: Group related values together
- `2026-02-19T00:00:00Z`: Rename file to match MS naming convention
- `2026-08-08T06:05:30Z`: Closing: no longer valid — vague scraped TODO with no remaining actionable context.

---

## 112: Reduce MTLTexture descriptor usage flags to only necessary ones

+++
status: closed
priority: low
kind: enhancement
labels: source:todo, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:21:32Z
closed: 2026-08-08T20:21:32Z
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
status: closed
priority: low
kind: task
labels: source:todo, testing, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:03:57Z
closed: 2026-08-08T20:03:57Z
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
status: closed
priority: low
kind: documentation
labels: documentation, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T04:32:36Z
closed: 2026-04-21T04:32:36Z
+++

Continue adding documentation comments (///) to public APIs.

Current state: ~37% of files have doc comments. Key public APIs (RenderPass, RenderPipeline) are well documented, but many types still need coverage.

Priority:

- `2026-02-19T00:00:00Z`: All public types and methods
- `2026-02-19T00:00:00Z`: Environment keys
- `2026-02-19T00:00:00Z`: Modifiers
- `2026-04-21T04:32:36Z`: Closing — not actively tracking these as discrete issues.

---

## 149: Tutorials

+++
status: closed
priority: low
kind: documentation
labels: documentation, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T04:32:36Z
closed: 2026-04-21T04:32:36Z
+++

Expand DocC tutorials for MetalSprockets.

## Existing tutorials (4):
1. Colorful Triangle
2. Rainbow Quad
3. Animated Rainbow Quad
4. Spinning Cube

## Ideas for more:

- `2026-02-19T00:00:00Z`: Compute shaders
- `2026-02-19T00:00:00Z`: Post-processing effects
- `2026-02-19T00:00:00Z`: MSAA / MetalFX
- `2026-02-19T00:00:00Z`: Working with textures
- `2026-02-19T00:00:00Z`: Loading 3D models
- `2026-04-21T04:32:36Z`: Closing — not actively tracking these as discrete issues.

---

## 150: Screencast

+++
status: closed
priority: low
kind: documentation
labels: documentation, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T16:11:15Z
closed: 2026-08-08T16:11:15Z
+++

*Imported from #142*

- `2026-08-08T16:11:15Z`: Won't fix: a screencast is not a code change and isn't tracked usefully here.

---

## 152: Add onWorkloadExit modifier for all Elements

+++
status: open
priority: low
kind: feature
labels: source:todo, effort:m, api, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
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
status: closed
priority: low
kind: enhancement
labels: enhancement, effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T04:28:44Z
closed: 2026-04-21T04:28:44Z
+++

Currently in MetalSupport.swift, we have a custom convenience initializer that converts MDLVertexDescriptor to MTLVertexDescriptor. MetalKit provides MTKMetalVertexDescriptorFromModelIO() for this exact purpose. We should replace our custom implementation with the official API.

File: Sources/MetalSprocketsSupport/MetalSupport.swift

The custom implementation manually iterates through attributes and layouts, converting formats and copying offsets. This should be replaced with a call to MTKMetalVertexDescriptorFromModelIO().

*Imported from #162*

- `2026-04-21T04:28:45Z`: Stale — referenced MetalSupport.swift no longer exists; MDLVertexDescriptor use is minimal and not worth tracking.

---

## 171: Might as well make vertex descriptor a parameter to Render

+++
status: open
priority: low
kind: enhancement
labels: enhancement, effort:m, api, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
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
status: closed
priority: low
kind: enhancement
labels: enhancement, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:07:10Z
closed: 2026-08-08T20:07:10Z
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
status: closed
priority: medium
kind: enhancement
labels: enhancement, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T06:46:12Z
closed: 2026-08-08T06:46:12Z
+++

Replace generic error types with specific, descriptive error types. This improves debugging and error handling by making it clear what went wrong.

- `2026-08-08T06:46:12Z`: Replaced all seven MetalSprocketsError.generic throw sites (all in OffscreenVideoRenderer) with specific cases — configurationError for asset-writer setup, resourceCreationFailure for pixel buffer allocation, validationError for append/finish failures — each now carrying frame/URL/underlying-error context. The .generic case itself remains for external callers.

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
status: closed
priority: medium
kind: feature
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T06:54:05Z
closed: 2026-08-08T06:54:05Z
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

- `2026-08-08T06:54:05Z`: Added Element.id(_:) backed by IdentifiedElement plus an explicitID field on StructuralIdentifier.Atom; when present it replaces sibling index in the atom, so identity follows the value rather than position. Tests added in StructuralIdentifierTests.

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
status: closed
priority: medium
kind: enhancement
labels: enhancement, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:29:04Z
closed: 2026-08-08T20:29:04Z
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

\- `2026-04-03T17:33:51Z`: Related: #197 (elements without parameters rebuild unnecessarily)
\- `2026-08-08T07:02:45Z`: Root cause as written is stale: MSState.projectedValue returns the single MSBinding instance stored on StateBox, so bindings to the same state already compare equal across rebuilds (same UUID) — no sourceIdentifier change needed.

The remaining symptom is the same one as #197: System's update traversal re-evaluates every body regardless of element equality, so the child rebuilds anyway. Fixing it means subtree skipping in System.update; see my comment on #197 for the blast radius and the question I need answered. Scenario added as a withKnownIssue test in Tests/MetalSprocketsTests/SelectiveRebuildTests.swift.

- `2026-08-08T15:47:46Z`: Decision: push-based dirty propagation. StateBox will mark the dependent node and its ancestor chain dirty, and System.update will skip any subtree containing no dirty node, splicing the previous nodes and traversal events instead of re-evaluating bodies.
- `2026-08-08T20:29:04Z`: Duplicate of #197. Both are blocked on the same work (push-based dirty propagation + subtree skipping in System.update); tracking it there. The unused-binding scenario stays covered by unusedBindingDoesNotRebuildChild in SelectiveRebuildTests.swift.

---

## 197: Optimize: Elements without parameters rebuild unnecessarily

+++
status: closed
priority: medium
kind: enhancement
labels: enhancement, effort:l
depends: 367, 369, 370, 371
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T21:13:12Z
closed: 2026-08-08T21:13:12Z
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

\- `2026-04-03T17:33:51Z`: Related: #196 (unused bindings cause unnecessary rebuilds)
\- `2026-08-08T07:02:45Z`: Partial progress + punt on the rest.

Done: isEqual(Any, Any) now treats two non-Equatable *value* types of the same type with no stored properties as equal (proposal 2 in this issue). Reference types are excluded since distinct instances are meaningfully distinct.

Why that isn't enough: element equality only gates node.element replacement and needsSetup in System.processNode. The update traversal itself (Element.visitChildren -> visit(body)) unconditionally evaluates every element's body every update, so ConstantChild's body still runs. Making this issue's test pass requires the traversal to skip re-evaluating an unchanged subtree — splicing the previous subtree's nodes and traversal events instead of rebuilding them, and propagating dirtiness from descendants upward. That's a change to the core update algorithm with a wide blast radius (interacts with structural identity alignment via previousIterator, dirty tracking, and setup/workload ordering), so I'm not attempting it blind.

Added Tests/MetalSprocketsTests/SelectiveRebuildTests.swift with this issue's scenario as a withKnownIssue test, so it flips green automatically when subtree skipping lands.

Unblocker: confirm you want subtree skipping in System.update, and whether dirty propagation should be push-based (StateBox marks ancestors) or pull-based (compare subtree during traversal).

- `2026-08-08T15:47:46Z`: Decision: push-based dirty propagation. StateBox will mark the dependent node and its ancestor chain dirty, and System.update will skip any subtree containing no dirty node, splicing the previous nodes and traversal events instead of re-evaluating bodies.
- `2026-08-08T20:29:04Z`: Folding #196 into this issue: both need the same feature (push-based dirty propagation + subtree skipping in System.update). #196's stated root cause (MSBinding UUID equality) was already stale — bindings to the same state compare equal. The unused-binding scenario is covered by unusedBindingDoesNotRebuildChild in Tests/MetalSprocketsTests/SelectiveRebuildTests.swift, alongside this issue's statelessChildDoesNotRebuild.
- `2026-08-08T20:39:47Z`: Split into subtasks: #367 -> #369 -> #370 -> #371.
- `2026-08-08T21:13:25Z`: Completed via subtasks #367, #369, #370, #371 (push-based dirty propagation + subtree splicing in System.update). Covered by statelessChildDoesNotRebuild and unusedBindingDoesNotRebuildChild in Tests/MetalSprocketsTests/SelectiveRebuildTests.swift.

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
status: closed
priority: low
kind: enhancement
labels: enhancement, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T21:15:10Z
closed: 2026-08-08T21:15:10Z
+++

In ForEach.swift:24, there's a TODO noting that we're not using IDs in the System StructuralIdentifier yet. This should be implemented to properly track ForEach elements.

File: Sources/MetalSprockets/Core/ForEach.swift

*Imported from #201*

---

## 210: Handle errors in StateBox getter/setter

+++
status: closed
priority: medium
kind: bug
labels: bug, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T02:42:14Z
closed: 2026-04-21T02:42:14Z
+++

StateBox has TODO comments about error handling in the getter and setter methods. Need to determine proper error handling strategy.

File: Sources/MetalSprockets/Core/StateBox.swift

*Imported from #202*

- `2026-04-21T02:42:14Z`: Both TODOs were in valueDidChange(). Neither is actually an error: (1) nil system means teardown (harmless) and the 'never attached' case is already caught by assertionFailure in the  getter; (2) a deallocated dependency just needs pruning. Replaced forEach with compactMap so dead entries are cleaned up opportunistically on write, and removed the TODOs with clarifying comments.

---

## 212: Pass Node as parameter to EnvironmentReader

+++
status: open
priority: low
kind: enhancement
labels: effort:m, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
+++

EnvironmentReader should ideally be passed a Node as a parameter as noted in the TODO.

File: Sources/MetalSprockets/Core/EnvironmentReader.swift

*Imported from #204*

---

## 213: Make System properties private

+++
status: closed
priority: high
kind: task
labels: effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T02:56:37Z
closed: 2026-04-21T02:56:37Z
+++

Audit System class and make properties private that shouldn't be public API. Reduce the exposed surface area.

- `2026-04-21T02:56:37Z`: Audit complete. All stored properties are already private(set) var or private let. The one public API (markAllNodesNeedingSetup) must stay public — called from RenderViewViewModel in MetalSprocketsUI. External readers (SystemSnapshot, various modifiers) require read access to activeNodeStack/nodes/traversalEvents, so further tightening would need a broader refactor (tracked in #292). Removed the outdated TODO comment.

---

## 214: Call cleanup/onDisappear for removed nodes

+++
status: closed
priority: medium
kind: bug
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T03:09:00Z
closed: 2026-04-21T03:09:00Z
+++

System could call cleanup/onDisappear when nodes are removed. Currently just notes they're gone.

File: Sources/MetalSprockets/Core/System.swift

*Imported from #206*

- `2026-04-21T03:09:00Z`: Added BodylessElement.teardown(_:) protocol hook with empty default; System.update now calls it for nodes removed from the tree (errors are logged, not propagated, so a misbehaving teardown can't break update). Exposed as a public .onDisappear { ... } element modifier on Element. Covered by OnDisappearTests (8 cases: basic fire/no-fire, reorder, multiple removals, nested modifiers, full replacement, throwing teardown is swallowed).

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
status: closed
priority: low
kind: task
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:20:14Z
closed: 2026-08-08T20:20:14Z
+++

Document the AnyBodylessElement modifier-style extensions (onSetupEnter, onSetupExit, onWorkloadEnter, onWorkloadExit).

These are used for building elements that need custom setup/workload phase behavior without creating a full custom type. Example usage: MetalFXSpatial.swift.

Either:
- Add proper documentation comments explaining the pattern
- Or consider if there's a better API design

---

## 218: Fix dangerous tree walking in Element+Dump

+++
status: closed
priority: low
kind: bug
labels: bug, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T15:53:24Z
closed: 2026-08-08T15:53:24Z
+++

Walking the tree in Element+Dump can modify state which is dangerous. Elements like EnvironmentReader can break things. Need to only walk the System tree instead.

File: Sources/MetalSprockets/Core/Element+Dump.swift

*Imported from #210*

- `2026-08-08T15:53:24Z`: Element.dump()/dumpVerbose() now expand the tree into a throwaway System and walk its traversal events instead of re-walking the element tree.

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
status: closed
priority: low
kind: enhancement
labels: needs-info, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T04:28:53Z
closed: 2026-04-21T04:28:53Z
+++

*Imported from #225*

- `2026-04-21T04:28:53Z`: Removed commented-out DebugLabelModifier.swift. If we want this back, it'd be simpler to rewrite from scratch.

---

## 235: Split BodylessElement into SetupElement and WorkloadElement protocols

+++
status: closed
priority: medium
kind: enhancement
labels: enhancement, effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T16:03:07Z
closed: 2026-08-08T16:03:07Z
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

- `2026-02-19T00:00:00Z`: AnyBodylessElement always triggers setup due to closure comparison limitations (was #237)
- `2026-02-19T00:00:00Z`: This would allow automatic setup detection based on protocol conformance
- `2026-04-03T17:33:50Z`: Related: #67 (formalize element I/O), #152 (onWorkloadExit), #214 (cleanup for removed nodes)
- `2026-08-08T16:03:07Z`: BodylessElement split into SetupElement (setupEnter/setupExit) and WorkloadElement (workloadEnter/workloadExit). Each phase now dispatches only to elements that conform, and nodes whose element is not a SetupElement never report needsSetup.

---

## 236: Pipeline elements need proper requiresSetup implementation for shader constants

+++
status: closed
priority: high
kind: bug
labels: bug, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T02:44:25Z
closed: 2026-04-21T02:44:25Z
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

- `2026-04-21T02:44:25Z`: Resolved by the cache-key rework in #327/#333. RenderPipeline, ComputePipeline, and MeshRenderPipeline all now return true from requiresSetup and delegate reuse decisions to a per-node cache keyed on the actual inputs (function ObjectIdentifier, linked functions, vertex descriptor, pixel formats, sample count, depth/stencil, label). Shader constants produce a different specialized MTLFunction, which has a different ObjectIdentifier, so the cache key changes and the PSO rebuilds automatically.

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
status: closed
priority: low
kind: enhancement
labels: enhancement, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T04:28:45Z
closed: 2026-04-21T04:28:45Z
+++

func parameter(_ name: String, functionType: MTLFunctionType? = nil, values: [some Any])func parameter(_ name: String, functionType: MTLFunctionType? = nil, value: some Any)

At the very least we should improve the asserts.

*Imported from #231*

- `2026-04-21T04:28:45Z`: Too vague to action.

---

## 240: Get rid of MetalSprocketsSupport

+++
status: closed
priority: low
kind: enhancement
labels: enhancement, needs-info, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T15:39:21Z
closed: 2026-08-08T15:39:21Z
+++

Not really needed now that we broke out geometrylite3d.

Can be turned into batteries included (#202)

*Imported from #232*

- `2026-08-08T15:39:21Z`: Closing as won't-do: the MetalSprocketsSupport split still earns its keep. Revisit under #202 if the batteries-included work needs a home.

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
status: closed
priority: high
kind: bug
labels: bug, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T02:41:30Z
closed: 2026-04-21T02:41:30Z
+++

Audit argument buffer usage to ensure `useResources()` is called correctly. Metal requires marking resources used by argument buffers so the GPU can track them. Missing calls can cause undefined behavior or crashes.

- `2026-04-21T02:41:30Z`: Closing. MetalSprockets itself doesn't construct argument buffers internally — the useResource/useResources element modifiers are the API surface for users to call from their own code. No in-tree audit target.

---

## 246: Assert when same shader compiled multiple times

+++
status: closed
priority: high
kind: enhancement
labels: enhancement, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T02:37:11Z
closed: 2026-04-21T02:37:11Z
+++

Add an assertion or warning when the same shader source is compiled multiple times. This is a performance issue - shaders should be compiled once and cached. Detecting duplicate compilation helps users optimize their code.

- `2026-04-21T02:37:11Z`: Obsolete. Shader compilation is now de-duped structurally: LibraryRegistry caches MTLLibrary by source/bundle identity, ShaderCache caches MTLFunction per library, and RenderPipelineCache/MeshRenderPipelineCache/ComputePipelineCache cache pipeline states per node. Same source compiled multiple times is prevented by construction rather than detected by assertion. See #339 for the related cache-lifetime concern.

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
status: closed
priority: high
kind: bug
labels: bug, effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-04-21T02:51:18Z
closed: 2026-04-21T02:51:18Z
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

- `2026-04-21T02:51:18Z`: Added a debug-build assertion in Element.visitChildren that fires when an element's Body associatedtype is inferred as any Element (the existential). Writing 'var body: any Element' compiles but silently breaks traversal; the assert now makes that immediate and obvious in debug. No runtime cost in release builds.
- `2026-04-21T02:51:46Z`: Related: #312 (Metal GPU HUD disappears during drag/pan gestures) may be a symptom of similar traversal/rebuild issues worth checking against the new assert.

---

## 255: Make a FunctionTypes OptionSet

+++
status: closed
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T16:21:33Z
closed: 2026-08-08T16:21:33Z
+++

Create an OptionSet for Metal function types (vertex, fragment, compute, etc.) to replace individual `MTLFunctionType` parameters. Would allow targeting multiple function types at once, e.g., `.parameter("value", functionTypes: [.vertex, .fragment], ...)`.

- `2026-08-08T16:21:33Z`: Added FunctionTypes OptionSet (with .render / .meshRender conveniences) and .parameter(_:functionTypes:...) overloads; Parameter now stores a FunctionTypes set where empty means infer from reflection. The single functionType: overloads remain as conveniences.

---

## 256: Metal 4

+++
status: open
priority: low
kind: feature
labels: effort:xl, api, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:37:59Z
+++

Adopt Metal 4 APIs where beneficial:

- `2026-02-19T00:00:00Z`: Evaluate new Metal 4 features
- `2026-02-19T00:00:00Z`: Update framework to use improved APIs
- `2026-02-19T00:00:00Z`: Take advantage of performance improvements
- `2026-02-19T00:00:00Z`: Consider requiring Metal 4 as minimum or providing fallbacks
- `2026-04-18T17:21:58Z`: Draft RFC: [RFCs/0002-metal-4.md](RFCs/0002-metal-4.md) — proposes a phased rollout (backend abstraction → Metal 4 backend → argument tables → pipeline caching → residency sets → ML dispatch element).

---

## 259: Look at unifying transform/amplification/uniforms

+++
status: open
priority: low
kind: enhancement
labels: enhancement, effort:l, api, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:35:23Z
+++

We currently pass data to shaders through three different mechanisms, each with a distinct API:

1. **Per-shader uniforms** — transforms and other constants bound once per draw (e.g. model/view/projection matrices).
2. **Per-amplification-index data** — values that vary per rendered view in amplified rendering (stereo / visionOS), indexed by amplification ID.
3. **Per-vertex data** — vertex buffers / attributes.

Conceptually these are all just 'data bound to shaders', differing only in granularity (per-draw, per-amplification, per-vertex). The current APIs evolved independently and don't share a common vocabulary.

Investigate whether these can be unified (or at least aligned) behind a more consistent API — making it easier to reason about what's varying at what rate, and to move data between granularities without rewriting call sites.

---

## 260: Rename renderPipelineDescriptorModifier -> renderPipelineDescriptorTransfomer

+++
status: closed
priority: low
kind: enhancement
labels: enhancement, effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:45:20Z
closed: 2026-08-08T20:45:20Z
+++

*Imported from #251*

---

## 268: device.supportsFunctionPointers

+++
status: closed
priority: medium
kind: enhancement
labels: effort:s
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T06:45:33Z
closed: 2026-08-08T06:45:33Z
+++

Check `device.supportsFunctionPointers` before using function pointers / visible function tables. Add graceful fallback or clear error message when not supported.

- `2026-08-08T06:45:33Z`: Added a device.supportsFunctionPointers check in VisibleFunctionTableModifier's table-creation paths (render + compute), throwing deviceCababilityFailure with a clear message instead of failing later on nil function handles. No test added: the unsupported path can't be exercised on available devices.

---

## 269: Merge RenderView with environment (ProcessInfo) logic

+++
status: closed
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:20:36Z
closed: 2026-08-08T20:20:36Z
+++

File: Sources/MetalSprocketsUI/RenderView.swift

The RenderView currently has separate logic for environment and ProcessInfo that should be merged into a unified approach.

*Imported from #261*

---

## 274: Make sampleCount and colorPixelFormat parameters on RenderView

+++
status: closed
priority: low
kind: enhancement
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T20:19:23Z
closed: 2026-08-08T20:19:23Z
+++

File: Sources/MetalSprocketsUI/MTKView+Environment.swift

These settings are so important they should be parameters on RenderView instead of environment values.

*Imported from #266*

---

## 280: Make sure all .environment values have helper functions (if appropriate)

+++
status: closed
priority: low
kind: task
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T16:27:52Z
closed: 2026-08-08T16:27:52Z
+++

Audit environment values and add convenience modifiers where appropriate. For example, instead of `.environment(\.device, device)`, provide `.device(device)` where it makes sense.

- `2026-08-08T16:27:52Z`: Audited MSEnvironmentValues: added device/commandQueue/commandBuffer/renderPassDescriptor/renderPipelineDescriptor/currentDrawable/drawableSize modifiers and switched the in-repo drivers to them. Encoders, reflection and the pipeline/depth-stencil state objects deliberately get no modifier — they are outputs published during traversal, and that is now written down in the source.

---

## 282: Implement .transformEnvironment()

+++
status: closed
priority: medium
kind: feature
labels: effort:m
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T06:47:08Z
closed: 2026-08-08T06:47:08Z
+++

Implement `.transformEnvironment()` modifier similar to SwiftUI's. This allows modifying an environment value based on its current value, rather than just replacing it:
```swift
.transformEnvironment(\.someValue) { value in
    value += 1
}
```

- `2026-08-08T06:47:08Z`: Implemented .transformEnvironment(_:transform:) on Element, built on EnvironmentWritingModifier. Test added in EnvironmentTests.

---

## 287: Add @Observation support

+++
status: closed
priority: medium
kind: feature
labels: effort:l
created: 2026-02-19T00:00:00Z
updated: 2026-08-08T16:09:20Z
closed: 2026-08-08T16:09:20Z
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

- `2026-02-19T00:00:00Z`: Requires Swift 5.10+ and macOS 14+
- `2026-02-19T00:00:00Z`: Does not include `Bindable` property wrapper implementation (future enhancement)
- `2026-02-19T00:00:00Z`: See also: [Swift forums discussion on isEqual simplification](https://forums.swift.org/t/comparing-two-any-values-for-equality-is-this-the-simplest-implementation/73816)
- `2026-08-08T16:09:20Z`: Element bodies are now evaluated inside withObservationTracking; mutating an @Observable property the body read marks the node dirty, so the subtree rebuilds. Properties the body never read do not trigger rebuilds. The isEqual simplification listed in this issue already landed earlier; the remaining equality concern (elements holding an @Observable model compare unequal every frame) is filed as #352.

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

- `2026-03-03T00:00:00Z`: MetalSprocketsGaussianSplats#6: Multi-splat mode FPS drops during camera rotation
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
status: closed
priority: medium
kind: task
labels: concurrency, effort:xl
created: 2026-03-31T18:27:17Z
updated: 2026-08-08T20:31:39Z
closed: 2026-08-08T20:31:39Z
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

\- `2026-08-08T20:31:38Z`: Closing this umbrella. A concurrency review of Sources found three concrete problems, filed as #364 (StateBox unsynchronized while written from GPU completion handlers), #365 (ShaderLibrary.ID @unchecked Sendable over a mutable MTLCompileOptions), and #366 (KVO observation leak in OffscreenVideoRenderer.defaultWaitUntilReady).

Everything else checked out: System and FrameRenderer's @unchecked Sendable is backed by documented single-isolation confinement with the genuinely cross-thread state (dirtyIdentifiers, lastGPUTime) behind OSAllocatedUnfairLock; ShaderCache and RenderViewViewModelAllocationTracker are lock-backed; no Task.detached, no DispatchQueue hops, no AsyncStream misuse.

---

## 292: Refactor: System is a god object with a split three-phase personality

+++
status: closed
priority: medium
kind: enhancement
labels: effort:xl, has-subtasks
depends: 372, 373, 374, 375
created: 2026-03-31T19:33:03Z
updated: 2026-08-08T23:14:05Z
closed: 2026-08-08T23:14:05Z
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

- `2026-08-08T20:40:04Z`: Split into subtasks: #372 -> #373 -> #374 -> #375.
- `2026-08-08T23:14:12Z`: Subtasks #372-#375 all landed: TreeReconciler extracted, TraversalContext encapsulates the active node stack, render(root:) enforces phase order, and tests moved to that boundary. Closed; the two parts not covered are now #389 (System.current global side-channel) and #390 (System still owns nodes, phases, dirty set and snapshotting).

---

## 293: Refactor: MSEnvironmentValues storage parent-chain is an invisible runtime contract

+++
status: closed
priority: medium
kind: enhancement
labels: effort:xl
created: 2026-03-31T19:33:38Z
updated: 2026-08-08T20:07:10Z
closed: 2026-08-08T20:07:10Z
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
status: closed
priority: medium
kind: enhancement
labels: effort:l
created: 2026-03-31T19:33:58Z
updated: 2026-08-08T19:50:36Z
closed: 2026-08-08T19:50:36Z
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

\- `2026-08-08T19:50:36Z`: Resolved by rescoping to option 3.

The stale-reflection premise was already out of date: RenderPipeline, MeshRenderPipeline and ComputePipeline all return true from requiresSetup, so setup runs every frame and republishes the reflection (cache-hit path included). Options 1/2 (typed pipeline context threaded through the content closure) would be a DSL-wide redesign that fights the environment-based flow used by every other pipeline output, so they were not pursued.

Done: added MSEnvironmentValues.requireReflection(for:), a single documented accessor stating that reflection is a setup-phase output slot and that consumers must be descendants of a pipeline. Parameters.swift and VisibleFunctionTableModifier.swift now use it instead of duplicating the guard and hint. Tests added in ParameterBindingTests covering the out-of-scope failure (hinted error, correct underlying case) and the in-scope success.

---

## 295: Refactor: ShaderLibrary / LibraryRegistry / ShaderCache are three interlocked process-global singletons

+++
status: closed
priority: low
kind: enhancement
labels: effort:xl, has-subtasks
depends: 376, 377, 378, 379
created: 2026-03-31T19:34:21Z
updated: 2026-08-08T23:14:06Z
closed: 2026-08-08T23:14:06Z
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

- `2026-04-21T02:48:26Z`: Related: #339 is a narrower task specifically about the LibraryRegistry leak (global singleton retains MTLLibrary forever). A fix there could be one concrete step toward this broader refactor.
- `2026-08-08T20:40:08Z`: Split into subtasks: #376 -> #377 -> #378 -> #379.

---

## 296: Refactor: RenderViewViewModel duplicates frame-orchestration logic that OffscreenRenderer also contains

+++
status: closed
priority: medium
kind: enhancement
labels: effort:l
created: 2026-03-31T19:34:45Z
updated: 2026-08-08T16:06:58Z
closed: 2026-08-08T16:06:58Z
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

- `2026-08-08T16:06:58Z`: Added FrameRenderer (owns the System, the update/setup/workload sequence, phase timings, and the GPU-time slot). Runner, RenderViewViewModel and ImmersiveRuntime now delegate to it; the nonisolated(unsafe) lastGPUTime vars are gone. Writing the isolation test exposed a real bug: a throw mid-phase left activeNodeStack dirty and tripped the empty-stack assertions on the next frame — the phase traversals now clear it on exit.

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
status: closed
priority: critical
kind: task
created: 2026-04-01T21:53:08Z
updated: 2026-04-21T02:12:40Z
closed: 2026-04-21T02:12:40Z
+++

After fixing #298 (RenderViewHelper allocating a new RenderViewViewModel every frame), we need a way to detect if this regresses. Options: a unit test that counts allocations, a debug-mode assertion that fires if RenderViewViewModel.init is called more than once per RenderView identity, or Instruments signpost tracking. Without this, it's easy to accidentally reintroduce the per-frame churn.

- `2026-04-21T02:12:40Z`: Added RenderViewViewModelAllocationTracker that counts allocations per Content type and logs a warning at 3 allocations, then every 10 thereafter. Always-on (one atomic increment + dict lookup per allocation). Follow-up #337 filed for the structural fix to make init cheap enough that churn doesn't matter.

---

## 300: Example app: MTKView depth texture uses Private storage mode instead of Memoryless

+++
status: closed
priority: low
kind: bug
labels: effort:xs
created: 2026-04-01T22:03:32Z
updated: 2026-08-08T15:51:41Z
closed: 2026-08-08T15:51:41Z
+++

Metal validation warning: Texture 0xb6628b200 "MTKView Depth" has storage mode Private but was a transient render target accessed exclusively by the GPU. Should use .storageModeMemoryless for the depth attachment to avoid wasting VRAM on a texture that does not need to persist between render passes. Seen in the spinning cube demo.

- `2026-08-08T15:51:41Z`: MTKView.configure(from:) now defaults depthStencilStorageMode to .memoryless when the depth attachment is a pure render target on an Apple-family GPU.

---

## 301: Add dismantleNSView/dismantleUIView to ViewAdaptor

+++
status: closed
priority: low
kind: enhancement
labels: effort:s
created: 2026-04-01T22:07:25Z
updated: 2026-08-08T16:15:31Z
closed: 2026-08-08T16:15:31Z
+++

ViewAdaptor wraps NSViewRepresentable/UIViewRepresentable but doesn't implement the static dismantle methods. Adding dismantleNSView and dismantleUIView would let us pause the MTKView and clear its delegate when SwiftUI tears down the representable — preventing stray draw callbacks after the view model is released. Belt-and-suspenders for the .onDisappear fix in #297.

- `2026-08-08T16:15:31Z`: ViewAdaptor now takes an optional dismantle closure, delivered to dismantleNSView/dismantleUIView via a coordinator. RenderView uses it to pause the MTKView and clear its delegate on teardown.

---

## 302: .parameter() uses MemoryLayout.size instead of .stride, causing Metal validation errors

+++
status: closed
priority: critical
kind: bug
created: 2026-04-02T00:38:43Z
updated: 2026-04-21T01:55:02Z
closed: 2026-04-21T01:55:02Z
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

\- `2026-04-21T01:55:02Z`: Root cause is in MetalSupport, not MetalSprockets. The four `setUnsafeBytes` helpers in `MetalSupport/Sources/MetalSupport/UnsafeBytes.swift` pass `buffer.count` (which is `MemoryLayout<T>.size`) as the byte length to `setBytes`/`setVertexBytes`/etc; Metal expects `MemoryLayout<T>.stride`.

Tracked upstream: MetalSupport#9. Once that lands, bump the MetalSupport dependency here.

Reproduction confirmed:
- struct { simd_float4x4; SIMD2<Float> }: size=72, stride=80, withUnsafeBytes.count=72.
- Metal validation error length(72) vs length(80) matches exactly.

Closing here as a duplicate redirected to the right repo.

---

## 303: Redirect docs.metalsprockets.com

+++
status: closed
priority: medium
kind: task
labels: effort:s
created: 2026-04-02T13:55:05Z
updated: 2026-08-08T15:46:08Z
closed: 2026-08-08T15:46:08Z
+++

Option 2: Configure DocC to publish to root

\- `2026-08-08T06:54:18Z`: Punting: this is a DNS/hosting change for docs.metalsprockets.com (plus DocC base-path config), which needs access to the domain and Pages settings that I don't have. Unblocker: confirm where docs are hosted (GitHub Pages?) and whether you want DocC published at the site root with a redirect, then I can do the DocC/workflow side.
\- `2026-08-08T15:46:08Z`: Code side done (Option 2 — DocC published at the site root):

- .github/workflows/docc.yml: dropped --hosting-base-path MetalSprockets so generated links are root-relative, and the workflow now writes ./docs/CNAME containing docs.metalsprockets.com into the Pages artifact.
- README.md: the six documentation links now point at https://docs.metalsprockets.com.

Still needs you (ops, one time):
1. DNS: CNAME docs.metalsprockets.com -> schwa.github.io.
2. GitHub repo Settings > Pages > Custom domain: docs.metalsprockets.com, then enable Enforce HTTPS once the cert issues.

Note: after this lands, https://schwa.github.io/MetalSprockets will no longer work correctly, since the assets are now root-relative. That is inherent to serving at a domain root.

---

## 304: Make MetalSprocketsShaders more opinionated.

+++
status: new
priority: medium
kind: task
labels: needs-info, effort:m, api, deferred
created: 2026-04-02T16:16:32Z
updated: 2026-08-08T20:35:23Z
+++

Some of MetalSprokcetsAddsOns can come in - specifically the macros we have for textures etc

- `2026-08-08T15:39:25Z`: Deferred for now (see 'deferred' label): decide later which parts of MetalSprocketsAddOns (texture macros etc.) should move in.

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
status: closed
priority: high
kind: bug
created: 2026-04-03T23:14:30Z
updated: 2026-04-21T00:44:23Z
closed: 2026-04-21T00:44:23Z
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

\- `2026-04-03T23:14:59Z`: Second occurrence: same crash, same stack trace. Appears to happen intermittently while navigating between demos. Both times the GameOfLife element tree is visible in the stack. Likely triggered by demo switching while the render loop is mid-update.
\- `2026-04-21T00:44:23Z`: Duplicate of #329. Same crash site (System.swift:237 shouldUpdateNode → Set.contains), same 0x8000000000000000 tagged-pointer signature, same bridge to -[... member:].

Root cause identified in #329: data race on System.dirtyIdentifiers from off-main markDirty calls (e.g. @MSState writes inside onCommandBufferCompleted). Tracked and being fixed in #330.

---

## 308: Demo app looks broken on iPad Simulator

+++
status: closed
priority: medium
kind: bug
labels: effort:m
created: 2026-04-09T18:33:18Z
updated: 2026-08-08T15:47:46Z
closed: 2026-08-08T15:47:46Z
+++

Running the demo app on iPad Pro 11-inch (M5) simulator (iOS 26.4), the UI is essentially blank/empty. Shows a white card with faint horizontal separator lines and a green '60' FPS counter in the top-right, but no actual rendered content is visible. The entire lower portion of the screen is just empty grey. Appears the Metal rendering surface isn't displaying anything.

- `2026-08-08T06:41:29Z`: Punting for now: verification needs an iPad Simulator run, which I couldn't complete (xcb --destination sim failed to match the booted iPad mini, and the sim build was too slow to iterate on). Note that #311's drawable-size resync fix may also address this — the symptom (blank Metal surface until a resize) is the same. Please re-check on iPad Sim after #311.
- `2026-08-08T15:47:46Z`: Confirmed fixed by the user: the demo app renders correctly on the iPad Simulator now. Cause was almost certainly the same zero-size drawable bug fixed in #311 (MTKView only reports drawableSizeWillChange on change, so a view sized before the delegate was attached rendered at .zero).

---

## 309: Verify MSAA is actually working — demo cube still looks aliased

+++
status: closed
priority: low
kind: bug
labels: effort:s
created: 2026-04-09T19:09:14Z
updated: 2026-08-08T06:05:23Z
closed: 2026-08-08T06:05:23Z
+++

The demo app claims MSAA 4x is enabled (overlay says so) but the cube edges still look aliased. Need to verify the MSAA pipeline is actually functioning correctly.

- `2026-08-08T06:05:24Z`: Closing as moot: no observed problem under the current SDK/CI. Reopen if it resurfaces.

---

## 310: fpsColor should be based on target framerate, not hardcoded thresholds

+++
status: closed
priority: low
kind: enhancement
labels: effort:xs
created: 2026-04-09T19:09:28Z
updated: 2026-08-08T16:13:31Z
closed: 2026-08-08T16:13:31Z
+++

FrameTimingView.fpsColor(for:) uses hardcoded thresholds (55 = green, 30 = yellow, else red). These should be relative to the target framerate (e.g. 120Hz displays would show yellow at 55fps which is wrong).

- `2026-08-08T16:13:31Z`: FrameTimingView now colour-codes FPS against a target frame rate (defaults to the display's maximum refresh rate): green from 90%, yellow from 50%, red below.

---

## 311: RenderView renders blank when used with .toolbar on macOS

+++
status: closed
priority: medium
kind: bug
labels: effort:m
created: 2026-04-09T20:03:35Z
updated: 2026-08-08T06:35:16Z
closed: 2026-08-08T06:35:16Z
+++

MTKView-backed RenderView renders nothing when a .toolbar modifier is applied (with or without NavigationStack). Resizing the window triggers rendering. Likely the MTKView gets zero initial size from the toolbar layout pass and never redraws when it gets a real size. Overlay-based UI works fine as a workaround.

- `2026-08-08T06:35:16Z`: Added a defensive drawable-size resync in RenderViewViewModel.draw(in:): MTKView only calls drawableSizeWillChange on change, so a view sized before the delegate was attached rendered at .zero until the next resize. Verified the macOS demo (which uses .toolbar) renders correctly on launch. Note: I could not confirm the original repro predated this change, so reopen if it recurs.

---

## 312: Metal GPU performance HUD disappears during drag/pan gestures

+++
status: closed
priority: low
kind: bug
labels: effort:m
created: 2026-04-09T20:12:59Z
updated: 2026-04-21T02:53:28Z
closed: 2026-04-21T02:53:28Z
+++

The Metal GPU performance overlay (enabled via Xcode scheme) disappears while dragging/panning in RenderView. It reappears when the gesture ends. Likely a SwiftUI overlay/z-ordering issue during gesture handling.

- `2026-04-21T02:51:46Z`: Related to #248 (closed): the any-Element traversal bug. If the HUD-during-gesture issue turns out to be a traversal/rebuild problem rather than a SwiftUI z-order one, the assertion from #248 might help surface it.
- `2026-04-21T02:53:28Z`: No longer reproducing — appears to have been fixed alongside the recent traversal/rendering changes (see #248 and related work). Close for now; reopen if it comes back.
- `2026-04-21T02:53:46Z`: Correction on the previous close comment: this was likely fixed by the RenderView viewModel work (#298, #337), not #248. The per-body RenderViewViewModel churn could cause transient teardown during gesture-triggered re-evaluations, which would take the HUD overlay with it.

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
status: closed
priority: critical
kind: bug
created: 2026-04-13T21:37:45Z
updated: 2026-04-21T02:04:10Z
closed: 2026-04-21T02:04:10Z
+++

When using .depthCompare() with different compare functions across frames (e.g. switching between .lessEqual and .greaterEqual), the depth stencil state is cached from the first configuration and not recreated. The Metal debugger confirmed the stencil state remained .lessEqual even after requesting .greaterEqual. Discovered while implementing switchable inverse-Z shadow mapping in MetalSprocketsAddOns.

\- `2026-04-21T02:04:10Z`: Fixed by switching the render/mesh pipeline cache keys to compare MTLDepthStencilDescriptor contents (via a new internal DepthStencilKey helper) instead of object identity.

Prior state after #333: every .depthCompare(function:enabled:) call allocated a fresh MTLDepthStencilDescriptor, so the identity-based key missed the cache every frame. That masked the #314 symptom (stale state could never persist, because we rebuilt every frame) but defeated the cache — any pipeline under .depthCompare rebuilt its PSO every frame, silently costing the perf #327/#333 set out to recover.

Now:
- DepthStencilKey captures (depthCompareFunction, isDepthWriteEnabled).
- RenderPipelineCache.Key and MeshRenderPipelineCache.Key carry DepthStencilKey? instead of ObjectIdentifier?.
- Two descriptors with identical contents hit the same cache entry regardless of identity; a change to function or isDepthWriteEnabled correctly invalidates.

Tests added in DepthStencilKeyTests (4) cover identical-contents equality, each field's independent invalidation, and the .depthCompare fresh-descriptor stability case.

---

## 315: @MSState does not update when element is reconstructed with different init values

+++
status: closed
priority: critical
kind: bug
created: 2026-04-13T22:01:50Z
updated: 2026-04-21T02:07:25Z
closed: 2026-04-21T02:07:25Z
+++

@MSState persists its initial value across frames and never updates, even when the element is reconstructed with a new value. This means function constants or other pipeline configuration stored in @MSState cannot be changed at runtime without destroying and recreating the entire RenderView (e.g. via .id()).

Example: an element with `@MSState var fragmentShader: FragmentShader` initialized with different function constants each frame will keep the first frame's shader forever.

This is the same root cause as #314 (cached depth stencil state). Both are cases where MetalSprockets caches state that should be invalidated when the element's configuration changes.

\- `2026-04-21T02:07:25Z`: Closing: @MSState intentionally ignores subsequent init values, matching SwiftUI's @State semantics. The initial value only applies on first construction; on every subsequent element-tree rebuild the stored value persists. That's the whole point — otherwise @MSState would reset every frame and be useless for element-owned state.

The reporter's example (@MSState var fragmentShader, expecting it to update when init args change) is a misuse of @MSState. For values derived from init arguments that need to rebuild on change, use a plain stored property plus a NodeElementCache inside setupEnter — the pattern established by #327 (ComputePipeline) and #333 (RenderPipeline / MeshRenderPipeline). The cache keys on the init args and rebuilds when they change.

Not related to #314 after all; that was a framework-level identity-vs-contents bug in the shared pipeline cache, independent of @MSState.

---

## 316: Add .depthBias() Element modifier

+++
status: closed
priority: low
kind: feature
labels: effort:s
created: 2026-04-15T23:43:17Z
updated: 2026-08-08T16:16:39Z
closed: 2026-08-08T16:16:39Z
+++

Expose Metal's setDepthBias(_:slopeScale:clamp:) as a declarative Element modifier, similar to .depthCompare(). Usage:

```swift
FlatShader(...) { ... }
    .depthBias(-0.1, slopeScale: -1.0, clamp: -0.01)
```

Currently consumers have to call encoder.setDepthBias() inside a Draw closure, which bypasses the declarative pipeline and can conflict with other state.

- `2026-08-08T16:16:39Z`: Added .depthBias(_:slopeScale:clamp:) as a WorkloadElement modifier; it sets the encoder bias on enter and clears it on exit so it does not leak to siblings.

---

## 317: Add .capture() Element modifier for MTLCaptureManager

+++
status: closed
priority: low
kind: feature
created: 2026-04-16T14:38:58Z
updated: 2026-04-16T14:39:04Z
closed: 2026-04-16T14:39:04Z
+++

Add a .capture(_ enabled: Bool = true, target: CaptureTarget = .device, destination: MTLCaptureDestination = .developerTools) modifier that wraps an Element's workload phase in an MTLCaptureManager scope. Supports targeting either the environment device or the current command queue. No-op when enabled is false. Warns and skips when destination is unsupported or a capture is already in progress.

- `2026-04-16T14:39:04Z`: Implemented in Sources/MetalSprockets/Metal/CaptureModifier.swift

---

## 318: Add .capture() View modifier to RenderView

+++
status: closed
priority: low
kind: feature
created: 2026-04-16T14:48:40Z
updated: 2026-04-16T14:48:45Z
closed: 2026-04-16T14:48:45Z
+++

Mirror the Element .capture(_:target:destination:) API as a SwiftUI View modifier on RenderView, applying an MTLCaptureManager scope to each rendered frame's element tree. Plumbed via an internal environment value and the RenderView view model.

- `2026-04-16T14:48:45Z`: Implemented in Sources/MetalSprocketsUI/RenderView.swift

---

## 319: MetalFX scalers recreated every frame due to AnyBodylessElement.requiresSetup = true

+++
status: closed
priority: high
kind: bug
labels: area:metalfx, area:core, effort:m
created: 2026-04-18T17:22:08Z
updated: 2026-04-21T01:50:13Z
closed: 2026-04-21T01:50:13Z
+++

`AnyBodylessElement.requiresSetup(comparedTo:)` always returns `true`. This means any element whose body is `AnyBodylessElement().onSetupEnter { ... }` has its setup closure re-run every frame.

For `MetalFXSpatial` this is wasteful: it reallocates an `MTLFXSpatialScaler` every frame.

For `MetalFXTemporal` (new) this is a correctness bug: it destroys the scaler's accumulated history every frame, defeating the entire purpose of temporal upscaling. Expected ~50 ms frame times for trivial scenes (3 SDF shapes) dropped to ~6 ms once scaler creation was moved out of `onSetupEnter` and guarded in `onWorkloadEnter` on dimension change.

### Scope

Anywhere `AnyBodylessElement().onSetupEnter { ... }` is used for one-time resource creation. Current call sites I know of:

- `Sources/MetalSprockets/Metal/MetalFXSpatial.swift`
- `Sources/MetalSprockets/Metal/MetalFXTemporal.swift` (new; worked around by moving init to workload)
- Probably others (search for `onSetupEnter`).

### Possible fixes

1. Make `AnyBodylessElement` compare the identities of its stored closures (they're reference types under the hood) so `requiresSetup` returns `false` when closures haven't been rebound. Cheapest fix.
2. Document that `onSetupEnter` runs every frame and audit all current callers. Probably most callers assume it's one-time.
3. Add an explicit `@MSState` "is initialized" flag pattern to the MetalFX elements so they lazy-init inside `onWorkloadEnter` \u2014 which is what the `MetalFXTemporal` fix does. Works but every caller has to know to do this.

Option 1 is the right general fix. If it's not feasible, at minimum the existing `MetalFXSpatial` should be audited (and its docstring updated) to confirm setup is supposed to be per-frame.

\- `2026-04-21T01:50:13Z`: Fixed: MetalFXSpatial is now a BodylessElement that uses the per-node cache pattern established in #333. The MTLFXSpatialScaler is keyed on (inputFormat, outputFormat, inputWidth, inputHeight, outputWidth, outputHeight) and only rebuilt when one of those changes — so steady-state rendering reuses the same scaler every frame, and the size-change branch still does the right thing.

requiresSetup returns true (AnyBodylessElement's conservative behaviour no longer applies since MetalFXSpatial is now its own BodylessElement), but setupEnter is a cache lookup. No more wasted allocations per frame.

Existing MetalFXSpatialTests (encode path, size-change recreation) still pass.

MetalFXTemporal isn't in the tree yet; when it lands it should follow the same pattern.

---

## 320: Add .vertexBuffer(_:layoutIndex:) modifier for stage_in vertex buffers

+++
status: closed
priority: medium
kind: feature
labels: metal4, api-design
created: 2026-04-18T23:50:57Z
updated: 2026-04-18T23:52:48Z
closed: 2026-04-18T23:52:48Z
+++

## Problem

Metal 4 vertex shaders that take input via `[[stage_in]]` + `MTLVertexDescriptor` bind their vertex buffers to the vertex argument table at the layout's `bufferIndex` slot. Those slots are not exposed as named arguments in Metal reflection, so `.parameter(_:buffer:)` — which resolves by name — cannot reach them.

See `Metal4Inventory.md` § "Open problem: stage_in vertex-buffer binding" for the long-form writeup.

## Finding

A reflection probe (`/tmp/reflection-probe/main.swift` during design, now gone) showed that Apple's Metal compiler **does** emit synthetic reflection entries for stage_in layout buffers, under hard-coded names of the form:

    vertexBuffer.0
    vertexBuffer.1
    ...

where the integer is the layout's `bufferIndex`. These bindings have `isArgument: false`, distinguishing them from user-declared `[[buffer(n)]]` arguments. The behavior is the same on Metal 3, so this could be used in the pre-Metal-4 codebase too.

The naming convention appears undocumented (no mention in Apple docs or headers), which is a small risk.

## Proposed API

```swift
RenderPass {
    RenderPipeline(vertexShader: vs, fragmentShader: fs) {
        Draw { encoder in
            encoder.drawPrimitives(primitiveType: .triangle,
                                   vertexStart: 0,
                                   vertexCount: vertices.count)
        }
        .vertexBuffer(positionsBuffer, layoutIndex: 0)
        .vertexBuffer(colorsBuffer, layoutIndex: 1)
    }
    .vertexDescriptor(myVertexDescriptor)
}
```

- Dedicated modifier, not a `.parameter(...)` overload. Reads naturally: "this is a vertex buffer, it goes at layout N." Signals at the call site that this is structurally different from a named argument.
- Offset parameter for byte offsets: `.vertexBuffer(buf, layoutIndex: 0, offset: 128)`.
- Auto-register buffer with the lifecycle's root residency set (same as `.parameter(_:buffer:)`).

## Implementation sketch

```swift
public extension Element {
    func vertexBuffer(_ buffer: any MTLBuffer, layoutIndex: Int, offset: Int = 0) -> some Element {
        self.parameter("vertexBuffer.\\(layoutIndex)", buffer: buffer, offset: offset)
    }
}
```

That's it, roughly. It delegates to `.parameter(_:buffer:)` so it gets residency registration, stage/kind validation, and reflection-driven slot lookup for free. The synthetic-name convention is absorbed in one place; if Apple ever renames it, we update one string literal.

## Risks / open questions

- **Undocumented reflection naming.** If Apple's convention changes across Xcode versions, `.vertexBuffer(...)` breaks. Consider a runtime check that accepts either `vertexBuffer.N` or a future name.
- **Pipelines with only stage_in inputs.** Reflection surfaces the synthetic entries, so the vertex argument table will be sized correctly automatically — no PipelineBindings changes needed. Verify with a test.
- **Sparse layout indices** (e.g. layout 0 and 2, no 1). `PipelineBindings` already sizes tables to max(index)+1; should work transparently.

## Acceptance

- Depth-compare golden test using stage_in vertex buffers renders correctly (the test that motivated this investigation).
- Example target's `DemoCubeRenderPipeline.swift` compiles against the new API (minus other unrelated missing APIs).
- Documentation in `Metal4Inventory.md` updated to close out the "Open problem" section.

## Related

- `Metal4Inventory.md` § Open problem: stage_in vertex-buffer binding.
- Previous abandoned attempts at the same fix: reverted 2026-04-18.
- RFC 0002 § Binding.

---

## 321: Replace Thread.sleep polling in OffscreenVideoRenderer.appendFrame with proper back-pressure

+++
status: closed
priority: low
kind: bug
labels: metal4, cleanup
created: 2026-04-18T23:55:21Z
updated: 2026-04-21T01:47:30Z
closed: 2026-04-21T01:47:30Z
+++

## Problem

`OffscreenVideoRenderer.appendFrame()` currently busy-polls
`assetWriterInput.isReadyForMoreMediaData` with a 10ms `Thread.sleep`:

```swift
while !assetWriterInput.isReadyForMoreMediaData {
    Thread.sleep(forTimeInterval: 0.01)
}
```

This was carried over verbatim from the Metal 3 port. It violates the
agent's "no timing hacks" rule and is a sign of a race-condition
workaround in the original code.

## Fix

Use AVFoundation's back-pressure API — `requestMediaDataWhenReady(on:using:)`
or `expectsMediaDataInRealTime = false` + the built-in readiness
callbacks — to block the caller properly instead of spinning.

Alternatively, wrap `appendFrame` in an `async` function that uses
`withCheckedContinuation` keyed off a KVO observation of
`isReadyForMoreMediaData`.

## Acceptance

- `2026-04-18T23:55:21Z`: `Thread.sleep` removed from `OffscreenVideoRenderer`.
- `2026-04-18T23:55:21Z`: Existing `videoRenderer` test still passes.
- `2026-04-18T23:55:21Z`: No new timing hacks introduced.
- `2026-04-21T01:47:30Z`: Done: removed the Thread.sleep(forTimeInterval: 0.01) polling loop in appendFrame. Replaced with an async KVO-based waitUntilReady on AVAssetWriterInput.isReadyForMoreMediaData (see OffscreenVideoRenderer.defaultWaitUntilReady). appendFrame and render are now async throws. Back-pressure path is exercised by testVideoRendererBackPressureSeam (via #336's injection seam).

---

## 322: Move MTKMesh+Extensions.swift to MetalSupport

+++
status: closed
priority: medium
kind: task
created: 2026-04-19T15:52:28Z
updated: 2026-04-19T17:52:49Z
closed: 2026-04-19T17:52:49Z
+++

Move `Sources/MetalSprocketsSupport/MTKMesh+Extensions.swift` out of MetalSprocketsSupport and into the MetalSupport package/module.

- `2026-04-19T17:52:49Z`: Moved to MetalSupport.

---

## 323: Add public Element.linkedFunctions(_:) modifier

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-19T16:22:08Z
updated: 2026-04-19T16:24:40Z
closed: 2026-04-19T16:24:40Z
+++

The env key `\.linkedFunctions` (MTLLinkedFunctions?) is already part of MetalSprockets and consumed by RenderPipeline / MeshRenderPipeline / ComputePass. However there is no public `Element.linkedFunctions(_:)` convenience modifier, so users have to write `.environment(\.linkedFunctions, ...)` by hand — or redefine the one-liner in every project. MetalSprocketsExamples currently has a local copy in the ShaderGraphDemo. Promote the helper into public MS API and remove the duplicate.

- `2026-04-19T16:24:40Z`: Added public Element.linkedFunctions(_:) modifier. Removed duplicate from MetalSprocketsExamples ShaderGraphDemo.

---

## 324: visibleFunctionTable modifier doesn't work inside ComputePipeline

+++
status: closed
priority: medium
kind: bug
created: 2026-04-19T17:25:50Z
updated: 2026-04-19T17:52:59Z
closed: 2026-04-19T17:52:59Z
+++

The `.visibleFunctionTable(_:function:)` / `.visibleFunctionTable(_:functions:)` modifier in `Sources/MetalSprockets/Metal/VisibleFunctionTableModifier.swift` only resolves `renderPipelineState` from the environment. `ComputePipeline` sets `computePipelineState` instead, so using the modifier inside a `ComputePipeline { ComputeDispatch { ... }.visibleFunctionTable("table", function: fn) }` throws:

```
Missing environment value: renderPipelineState
Hint: visibleFunctionTable('table') must be placed inside a RenderPipeline content block, not as a modifier on RenderPipeline itself.
```

The `workloadEnter` already has a `computeCommandEncoder` branch for binding, but it never runs because the guard on `renderPipelineState` fails first.

Fix: in `setupEnter`/`workloadEnter`/`createFunctionTable`, also consult `environmentValues.computePipelineState` and call `MTLComputePipelineState.makeVisibleFunctionTable(descriptor:)` / `functionHandle(function:)` when it's present. Update the error hint to mention compute as well.

Discovered while porting Phosphor (a shadertoy-style app) to MetalSprockets: the kernel declares a `visible_function_table<SnippetFunction>` in `[[buffer(1)]]` for a runtime-compiled user snippet. Current workaround is to bypass the modifier and bind the VFT manually via `encoder.setVisibleFunctionTable(_:bufferIndex:)` inside a `ComputeDispatch` closure.

---

## 325: Investigate Metal log state failure on CI runners

+++
status: closed
priority: low
kind: bug
labels: effort:m
created: 2026-04-19T18:10:04Z
updated: 2026-08-08T06:05:23Z
closed: 2026-08-08T06:05:23Z
+++

The CommandBufferLoggingTests.testAddMetalSprocketsLogging test was failing on GitHub Actions with:

    Error Domain=MTLLogStateErrorDomain Code=2 "Cannot create residency set for MTLLogState ..."

This indicates that on the CI macOS runner/GPU configuration, Metal cannot create an MTLLogState (or its underlying residency set). The test has been temporarily disabled when the CI environment variable is set (see Tests/MetalSprocketsTests/EasyWinsTests.swift).

Investigate:

- `2026-04-19T18:10:04Z`: Why MTLLogState creation fails on CI (likely software/virtualized GPU lacks support)
- `2026-04-19T18:10:04Z`: Whether addMetalSprocketsLogging() should fail more gracefully or be feature-detected
- `2026-04-19T18:10:04Z`: Whether we can detect log-state availability at runtime and skip rather than gating on the CI env var
- `2026-04-19T18:10:04Z`: Re-enable the test once a proper fix or detection mechanism is in place
- `2026-08-08T06:05:23Z`: Closing as moot: no observed problem under the current SDK/CI. Reopen if it resurfaces.

---

## 326: Introduce SystemEnvironment type for test-overridable process env

+++
status: closed
priority: medium
kind: enhancement
labels: testing, architecture, effort:l
created: 2026-04-19T18:36:16Z
updated: 2026-08-08T15:58:30Z
closed: 2026-08-08T15:58:30Z
+++

Several places in MetalSprockets read process environment variables directly via `ProcessInfo.processInfo.environment` (through `ProcessInfo+Extensions`):

- `MS_DUMP_SNAPSHOTS` (Snapshotter)
- `MS_RENDERVIEW_LOG_FRAME` (RenderView)
- `MTL_CAPTURE_ENABLED` (CaptureModifier, indirectly via MTLCaptureManager)
- Logging gates
- etc.

Because these are captured at init/type-resolution time, they are impossible to flip from inside a test without spawning subprocesses. The result is uncoverable branches (see coverage notes: Snapshotter dump path, CaptureModifier capture path, logging paths).

## Proposal

Introduce a `SystemEnvironment` (or `MSEnvironment`/`EnvironmentSource`) value type that:

1. Defaults to a shared instance backed by `ProcessInfo.processInfo.environment`.
2. Exposes typed accessors for each flag (e.g. `dumpSnapshotsEnabled: Bool`, `renderViewLogFrameEnabled: Bool`).
3. Can be overridden for tests by injecting a custom instance (either via initializer parameter, task-local, or a static-override hook scoped with `defer`).

Call sites (Snapshotter, logging, any future env-gated code) take an optional `SystemEnvironment` parameter that falls back to the default.

## Benefits

- Coverage: tests can exercise the enabled paths without subprocesses or env-var juggling.
- Testability: removes hidden global state from call sites.
- Single point of truth for which env vars MetalSprockets responds to.

## Notes

- `2026-04-19T18:36:16Z`: Current Snapshotter already has a test-only injection (`init(shouldDumpSnapshots:fileURL:)`) added during the coverage push. This issue generalizes that pattern.
- `2026-04-19T18:36:16Z`: Not a `@MSEnvironment` style thing — this is about *process* environment, not element-tree environment. Pick a name that doesn't collide (e.g. `SystemEnvironment`, `ProcessEnvironment`, or `RuntimeFlags`).
- `2026-08-08T15:58:30Z`: Added SystemEnvironment (MetalSprocketsSupport) with typed flag accessors and a task-local 'current' override. Per-call gates (fatalErrorOnThrow, Logger.verbose, metalLoggingEnabled, dumpSnapshotsEnabled, RenderViewDebugging) now read it. The lazily-initialised 'logger' globals still latch ProcessInfo at first use — overriding those would mean building a Logger per call.

---

## 327: ComputePipeline ignores changes to linkedFunctions (requiresSetup hardcoded false)

+++
status: closed
priority: high
kind: bug
created: 2026-04-20T22:26:48Z
updated: 2026-04-21T01:05:12Z
closed: 2026-04-21T01:05:12Z
+++

`ComputePipeline.requiresSetup(comparedTo:)` in `Sources/MetalSprockets/Metal/ComputePass.swift` currently returns `false` unconditionally with a TODO comment. This means the underlying `MTLComputePipelineState` is built once (during the initial `setupEnter`) and never rebuilt, even if the `ComputeKernel` or `linkedFunctions` environment value changes across frames.

This breaks any use case that swaps a visible-function-table entry at runtime. Repro: the Phosphor demo in MetalSprocketsExamples — switching between shader snippets updates `@State` and the editor contents, but the rendered output never changes because the PSO is still linked against the original snippet function.

Suggested fix: add an opt-in invalidation key to `ComputePipeline` (e.g. `invalidationKey: AnyHashable?` at init) and compare it in `requiresSetup`. That avoids rebuilding the PSO every frame for existing demos while letting consumers that depend on environment values (like `linkedFunctions`) opt in. Alternative: compare `computeKernel.function` identity and stash a hash of `linkedFunctions` on the struct.

File: Sources/MetalSprockets/Metal/ComputePass.swift (the `requiresSetup(comparedTo:)` implementation and the surrounding TODO).

\- `2026-04-21T01:05:12Z`: Fixed: ComputePipeline.requiresSetup now compares computeKernel identity and an optional caller-supplied invalidationKey. Callers that depend on environment-driven inputs (linkedFunctions, etc.) opt in by passing a hashable key derived from whatever they know changed.

This is the exemplar implementation for #333. The same pattern should be applied to RenderPipeline and MeshRenderPipeline next.

Phosphor demo can now rebuild its PSO on snippet switch by passing the selected snippet identifier as invalidationKey.

---

## 328: ComputeDispatch has no way to auto-pick threadsPerThreadgroup

+++
status: closed
priority: medium
kind: feature
labels: effort:m
created: 2026-04-20T23:20:56Z
updated: 2026-08-08T06:50:37Z
closed: 2026-08-08T06:50:37Z
+++

`ComputeDispatch` requires callers to pass `threadsPerThreadgroup` up front. There is no way to let the framework pick an appropriate threadgroup size based on the actual compute pipeline state's `maxTotalThreadsPerThreadgroup` and `threadExecutionWidth`.

Picking correctly requires the PSO, which isn't available to the caller when constructing `ComputeDispatch` (it's only in the environment at workload-enter time). The PSO's `maxTotalThreadsPerThreadgroup` can also vary with linked functions (e.g. visible_function_table snippets), so a fixed constant isn't always safe.

Repro: Phosphor demo in MetalSprocketsExamples hardcodes `MTLSize(16,16,1)` because there's no alternative; we have no way to ask the pipeline what it supports.

- `2026-08-08T06:50:38Z`: ComputeDispatch's threadsPerThreadgroup is now optional across all three inits; when omitted it is derived at dispatch time from the pipeline state (threadExecutionWidth x maxTotalThreadsPerThreadgroup/threadExecutionWidth, 1D grids get a 1D threadgroup). Tests added.

---

## 329: Crash in System.shouldUpdateNode: Set.contains on corrupted storage (tagged-pointer 0x8000000000000000)

+++
status: closed
priority: high
kind: bug
created: 2026-04-20T23:28:12Z
updated: 2026-04-21T00:58:45Z
closed: 2026-04-21T00:58:45Z
+++

While running the Phosphor demo in MetalSprocketsExamples (just steady-state rendering; no snippet switching, no view teardown), the app intermittently crashes with:

    *** Terminating app due to uncaught exception 'NSInvalidArgumentException',
        reason: '-[__NSTaggedDate member:]: unrecognized selector sent to
                 instance 0x8000000000000000'

The class that's impersonated varies across runs (`__NSTaggedDate`, `NSIndexPath`, …), but the instance pointer is always `0x8000000000000000` — the poison/zero bit pattern for a ObjC tagged pointer. `member:` is what `Swift.Set.contains` calls on its storage when bridged to NSSet internally; getting there with a bogus tagged pointer means the Set's `__RawSetStorage` has been freed or its storage slot overwritten.

The crash always reproduces on the same call site:

    libswiftCore  Set.contains
    MetalSprockets  System.shouldUpdateNode(_:with:)
    MetalSprockets  System.reuseNode(currentId:element:newNodes:)
    MetalSprockets  System.processNode(currentId:previousNode:element:newNodes:)
    MetalSprockets  System.update(root:)  [closure process]
    MetalSprocketsUI  RenderViewViewModel.draw(in:)
    MetalKit  -[MTKView draw]

So it's inside the normal element-tree diff path, triggered from `MTKView.draw`. No snippet switching / `.id()` teardown is needed — just let the view render for a while.

The repro app uses visible_function_table inside a ComputePass, a ping-pong texture pair, and `.onCommandBufferCompleted { currentTextureIsA.toggle() }`. The toggle closure runs on Metal's completion queue, not main — so it could be mutating `@MSState` (and thus invalidating the element tree / mutating `System`'s identifier set) concurrently with the main-thread `System.update`.

Suspect: `System`'s internal Set<StructuralIdentifier> (the one consulted by `shouldUpdateNode`) is being mutated from a non-main thread, or freed while a `Set.contains` is in flight.

Repro path: MetalSprocketsExamples Phosphor demo on main. Let it run for ~30s–2min.

Related issues: MetalSprockets#327 (ComputePipeline caches `MTLComputePipelineState` — may be unrelated but shares the general `System` re-entry area).

\- `2026-04-20T23:31:29Z`: Additional finding while trying to work around this:

Attempted to hop the completion handler's `@MSState` mutation back to main via

    .onCommandBufferCompleted { _ in
        nonisolated(unsafe) let binding = $currentTextureIsA
        DispatchQueue.main.async {
            binding.wrappedValue.toggle()
        }
    }

This immediately crashes (even more reliably) with:

    Fatal error: Attempted to read an unowned reference but object 0x… was
    already destroyed

    swift_abortRetainUnowned
    closure #1 in StateBox.init() at StateBox.swift:47:13
    MSBinding.wrappedValue.getter at Binding.swift:69:15

So `MSBinding` captures its enclosing `StateBox` via `unowned`, and the `StateBox` is deallocated between the GPU completion callback and the next main-queue tick. This means `MSBinding`s can't outlive a single synchronous body evaluation — any deferred capture (Task, DispatchQueue.main.async, continuation) can dangle.

Both the original `Set.contains` crash and this `MSBinding` unowned-read crash point at the same general issue: `System`/`StateBox` lifetime assumes all reads and writes happen inline during body evaluation on main, but nothing in the API prevents (or even discourages) off-main or deferred access. `onCommandBufferCompleted` documents that it 'Called on an unspecified queue after GPU execution finishes', yet any realistic use case (ping-pong toggle, frame counter, perf stats) wants to feed that back into `@MSState`, which isn't safe.

\- `2026-04-20T23:31:39Z`: Correction to previous comment: the hop-to-main variant did not crash immediately — it took a while to hit, same as the original crash. The rest of the analysis stands (MSBinding captured unowned, dies if deferred past body evaluation).
\- `2026-04-20T23:34:08Z`: Split into follow-ups:
- #330: data race on System.dirtyIdentifiers (the Set.contains crash).
- #331: MSBinding [unowned] dangles past body evaluation (the swift_abortRetainUnowned crash).

#329 remains open as the umbrella / API-level isolation contract discussion.

\- `2026-04-21T00:58:45Z`: Fixed by:
- #330 (System.dirtyIdentifiers lock) — closed in commit b64244f4
- #331 (MSBinding weak capture) — closed in commit 18180917

Phosphor demo stable in testing. Phase 2 isolation contract work (per RFC on desktop) will be filed as a separate issue if pursued.

---

## 330: Data race on System.dirtyIdentifiers causes Set.contains crash in shouldUpdateNode

+++
status: closed
priority: high
kind: bug
created: 2026-04-20T23:33:42Z
updated: 2026-04-21T00:47:02Z
closed: 2026-04-21T00:47:02Z
+++

Parent: #329.

`System.dirtyIdentifiers: Set<StructuralIdentifier>` is mutated (`markDirty` →
`dirtyIdentifiers.insert(id)`) and read (`shouldUpdateNode` →
`dirtyIdentifiers.contains(id)`) without any synchronization.

`StateBox.valueDidChange` calls `system.markDirty(node.id)` on whatever thread
wrote the `@MSState` value. In the Phosphor demo, that write happens from
`onCommandBufferCompleted` on Metal's completion queue, concurrently with
`MTKView.draw` running `System.update` on main. Swift `Set` is copy-on-write and
not thread-safe — a concurrent `insert` that triggers storage reallocation while
another thread is mid-`contains` bridges to `-[NSSet member:]` on freed/poisoned
storage, producing the `0x8000000000000000` tagged-pointer crash reported in
#329.

Repro: same as #329 (Phosphor demo, ~30s–2min).

Proposed fix:
- Wrap `dirtyIdentifiers` reads/writes in an `OSAllocatedUnfairLock`, or
- Formalize an isolation contract for `System` and make off-isolation `markDirty`
  a precondition failure (preferred long term; see #329 for API-level
  discussion).

Files:
- Sources/MetalSprockets/Core/System.swift (markDirty, shouldUpdateNode)
- Sources/MetalSprockets/Core/StateBox.swift (valueDidChange → markDirty)
- Sources/MetalSprockets/Core/ObservedObject.swift (also calls markDirty)

\- `2026-04-21T00:47:02Z`: Fixed by lockng System.dirtyIdentifiers with OSAllocatedUnfairLock<Set<StructuralIdentifier>>. Phosphor demo stable in testing.

Follow-ups remain:
- #329 (umbrella / Phase 2 isolation contract per RFC)
- #331 (MSBinding unowned dangle)
- #332 (remove unused AnyHashable in StructuralIdentifier)

---

## 331: MSBinding holds StateBox unowned, dangles past body evaluation

+++
status: closed
priority: high
kind: bug
created: 2026-04-20T23:33:59Z
updated: 2026-04-21T00:57:19Z
closed: 2026-04-21T00:57:19Z
+++

Parent: #329.

`StateBox.init` constructs its `MSBinding` capturing `[unowned self]`
(Sources/MetalSprockets/Core/StateBox.swift:47, 50). `MSBinding` therefore
cannot outlive a single synchronous body evaluation: any deferred capture
(`Task`, `DispatchQueue.main.async`, GPU completion handler, continuation,
`@escaping` closure stashed in another element) will, after the next element
tree rebuild releases the owning `StateBox`, crash with:

  Fatal error: Attempted to read an unowned reference but object 0x… was
  already destroyed
  → swift_abortRetainUnowned
  → closure #1 in StateBox.init() at StateBox.swift:47
  → MSBinding.wrappedValue.getter at Binding.swift:69

Reproduced in #329 by hopping the `onCommandBufferCompleted` `@MSState` write
back to main via `DispatchQueue.main.async { binding.wrappedValue.toggle() }`.

The API gives no hint that `MSBinding`s are body-evaluation-scoped. Realistic
use cases (ping-pong toggles, frame counters, perf stats from GPU completion,
async load → state) all want to capture a binding past the current body call.

Proposed fix (pick one):
- Capture `[weak self]` in the binding closures and make get/set a no-op (or
  precondition failure with a clear message) when `StateBox` is gone, OR
- Capture `self` strongly so `MSBinding` keeps the `StateBox` alive (note:
  this changes ownership semantics — bindings would extend state lifetime
  beyond the element tree), OR
- Document binding lifetime as body-scoped and provide a sanctioned escape
  hatch for deferred writes (e.g. an explicit `@MainActor` write API on
  `System`).

Related: #329 (the original `Set.contains` crash has the same underlying
cause: nothing prevents off-main / deferred state mutation).

- `2026-04-21T00:57:19Z`: Fixed: StateBox.init now captures [weak self] in its MSBinding closures. Late reads precondition-fail with a clear message; late writes silently drop (matching SwiftUI.Binding). Test added in BindingTests.testBindingSurvivesStateBoxDeallocation.

---

## 332: Remove unused StructuralIdentifier.Atom.Component.explicit(AnyHashable) case

+++
status: closed
priority: low
kind: enhancement
created: 2026-04-20T23:40:41Z
updated: 2026-04-21T01:00:24Z
closed: 2026-04-21T01:00:24Z
+++

While fixing #330, `StructuralIdentifier` had to be marked `@unchecked
Sendable` because `Atom.Component.explicit` wraps an `AnyHashable`, which is
explicitly non-Sendable in Swift 6.

Survey of call sites shows `.explicit` is **not used anywhere in Sources/** —
only in tests. The two `explicit:` convenience initializers on `Atom`
(`init(typeIdentifier:explicit:)` and `init(element:explicit:)`) exist but no
production code constructs them; the element tree only ever uses
`.index(Int)` via `nextIndex(for:)` in `System.update`.

Proposal:
- Delete `Component.explicit(AnyHashable)`.
- Delete the two `explicit:` initializers on `Atom`.
- Collapse `Component` into a plain `Int` stored on `Atom` (or keep the enum
  for future extensibility, but with only a `Sendable` payload).
- Drop `@unchecked Sendable` on `StructuralIdentifier` / `Atom` / `Component`
  in favour of plain `Sendable`.
- Remove the now-dead test coverage in
  `Tests/MetalSprocketsTests/StructuralIdentifierTests.swift` (the
  `explicit:`-based cases) and `Tests/MetalSprocketsTests/Support/Support.swift`
  (the `var explicit: AnyHashable?` helper).

If a future `Element.id(_:)` modifier wants per-instance identity, it should
be designed deliberately at that point — likely with a generic `ID: Hashable
& Sendable` constraint rather than `AnyHashable`.

Related: #330 (introduced the `@unchecked Sendable` workaround).

Files:

- `2026-04-20T23:40:41Z`: Sources/MetalSprockets/Core/StructuralIdentifier.swift
- `2026-04-20T23:40:41Z`: Tests/MetalSprocketsTests/StructuralIdentifierTests.swift
- `2026-04-20T23:40:41Z`: Tests/MetalSprocketsTests/Support/Support.swift
- `2026-04-21T01:00:24Z`: Done:
- `2026-04-21T01:00:24Z`: Removed Component.explicit(AnyHashable) and the enum entirely.
- `2026-04-21T01:00:24Z`: Atom is now { typeIdentifier: ElementTypeIdentifier, index: Int }.
- `2026-04-21T01:00:24Z`: Removed the two explicit: initializers.
- `2026-04-21T01:00:24Z`: Dropped @unchecked Sendable in favour of plain Sendable on StructuralIdentifier, Atom, and ElementTypeIdentifier.
- `2026-04-21T01:00:24Z`: Removed dead test helpers and 3 obsolete test cases.

---

## 333: Add invalidationKey escape hatch for setup-phase elements that read environment values

+++
status: closed
priority: high
kind: enhancement
created: 2026-04-21T01:03:35Z
updated: 2026-04-21T01:35:21Z
closed: 2026-04-21T01:35:21Z
+++

Several elements build Metal state during `setupEnter` from a mix of struct
fields *and* environment values, but `requiresSetup(comparedTo:)` can only
compare struct fields. This means environment-driven changes (e.g. a new
`linkedFunctions`, a new MSAA sample count, a new color attachment format)
silently fail to invalidate cached state.

Affected elements:
- `ComputePipeline` (#327) — returns `false` unconditionally.
- `MeshRenderPipeline` — returns `false` unconditionally.
- `RenderPipeline` — compares vertex/fragment shaders only; ignores environment
  (MSAA, depth format, color attachment formats, linkedFunctions, etc.).
- MetalFX scalers (#319) — related symptom, different root cause (always
  rebuilds), but benefits from the same escape hatch.

Proposal: add a standard `invalidationKey: AnyHashable?` parameter to each
affected elements init (or hoist onto a common protocol). `requiresSetup`
compares the key in addition to any struct-field comparison it already does.

Callers that depend on environment-driven inputs opt in by passing a hash of
whatever they know changed (e.g. the selected shader snippet name, the current
MSAA count, a monotonic counter). Callers who dont pass a key keep todays
behaviour.

This is an escape hatch, not a real fix. The right long-term solution is for
`requiresSetup` to have access to the previous nodes environment snapshot,
so it can diff environment values itself. Thats a bigger architectural
change; `invalidationKey` unblocks users today without prejudicing that design.

Sub-issues / related:
- #327 (ComputePipeline) — use this approach.
- #319 (MetalFX scalers) — related.
- #236 (Pipeline elements need proper requiresSetup for shader constants) —
  overlap; shader constants are another env-adjacent input.

Files (at minimum):
- Sources/MetalSprockets/Metal/ComputePass.swift
- Sources/MetalSprockets/Metal/RenderPipeline.swift
- Sources/MetalSprockets/Metal/MeshRenderPipeline.swift
- Sources/MetalSprockets/Core/BodylessElement.swift (if hoisted to a protocol)

\- `2026-04-21T01:35:21Z`: Applied the ComputePipeline cache pattern to RenderPipeline and MeshRenderPipeline.

Each pipeline now:
- Returns true from requiresSetup (stops lying).
- Keys a per-node NodeElementCache on its actual inputs: function identities, env-provided linkedFunctions identity, vertexDescriptor identity, renderPipelineDescriptor identity, attachment pixel formats and sample count, depthStencilDescriptor identity, and label.
- Returns the cached PSO / reflection / depth-stencil-state on a hit.

This closes the same class of bug as #327 for render and mesh pipelines (e.g. linkedFunctions changes no longer silently fail to invalidate the PSO).

MetalFX scalers (#319) can use the same pattern when addressed; tracking there remains open.

---

## 334: RenderPipeline mutates env-supplied MTLRenderPipelineDescriptor in place

+++
status: closed
priority: low
kind: bug
created: 2026-04-21T01:40:07Z
updated: 2026-04-21T02:39:11Z
closed: 2026-04-21T02:39:11Z
+++

`RenderPipeline.setupEnter` pulls `renderPipelineDescriptor` out of the
environment and writes into it directly:

```swift
let renderPipelineDescriptor = try environment.renderPipelineDescriptor.orThrow(...)
renderPipelineDescriptor.vertexFunction = vertexShader.function
renderPipelineDescriptor.fragmentFunction = fragmentShader.function
renderPipelineDescriptor.vertexLinkedFunctions = linkedFunctions
renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
renderPipelineDescriptor.rasterSampleCount = ...
renderPipelineDescriptor.colorAttachments[0].pixelFormat = ...
// etc
```

`MTLRenderPipelineDescriptor` is a mutable Obj-C class, and environment
values flow down by reference. Two `RenderPipeline` elements sharing an
ancestor `.environment(\.renderPipelineDescriptor, ...)` would scribble
into the same object and race on its fields.

No one is hitting this in practice today, but nothing prevents it. The
#333 cache work reduced the blast radius (no mutation on steady-state
cache hits) but didnt fix the underlying design.

`MeshRenderPipeline` gets this right — it constructs a fresh
`MTLMeshRenderPipelineDescriptor` inside `setupEnter` each cache miss.

Proposed fix:
- On cache miss, treat the env descriptor as a *template*. Copy it
  (`envDesc.copy() as! MTLRenderPipelineDescriptor`) or construct a
  fresh one and seed the fields we care about from the env one.
- Mutate the local copy only; never the shared env object.

File:
- Sources/MetalSprockets/Metal/RenderPipeline.swift (setupEnter)

Related: #333 (cache work that surfaced this).

- `2026-04-21T02:39:11Z`: Fixed: RenderPipeline.setupEnter now copies the env-supplied MTLRenderPipelineDescriptor via copyWithType(_:) before mutating it, so sibling RenderPipelines sharing the same env descriptor can no longer race on its fields.

---

## 335: OffscreenVideoRendererTests only asserts file existence — no content verification

+++
status: closed
priority: low
kind: enhancement
created: 2026-04-21T01:42:44Z
updated: 2026-04-21T01:47:30Z
closed: 2026-04-21T01:47:30Z
+++

The sole test for `OffscreenVideoRenderer` renders 30 frames to
`/tmp/RedTriangleVideo.mov` and checks only that the file exists:

```swift
try renderer.render(triangle)
...
try await renderer.finalize()
#expect(FileManager.default.fileExists(atPath: outputURL.path))
```

Gaps:
- No verification of video duration, frame count, dimensions, or codec.
- No pixel-content check — a silently-broken encoder that writes an empty
  container would still pass.
- Output URL is hard-coded `/tmp/...`, not a temp directory that gets
  cleaned up. Shared across runs; would race if tests ran concurrently.
- Only one test case. No coverage for: alternate codecs, alternate pixel
  formats, zero-frame edge case, `finalize` without frames, reuse across
  multiple renders.

Proposed improvements:
- Load the produced `.mov` with `AVAsset`; assert:
  - `duration` approximately frameCount / frameRate.
  - track count == 1, media type == `.video`.
  - natural size matches configured size.
- Use `FileManager.default.temporaryDirectory` / `NSTemporaryDirectory()`
  and clean up on teardown.
- Add at least one test that rendering twice in a row produces distinct,
  valid files.

Related: #321 (the Thread.sleep fix cannot be meaningfully verified by the
current test).

- `2026-04-21T01:47:30Z`: Done: OffscreenVideoRendererTests now verifies content (AVAsset duration within 0.2s tolerance, video track count, media type, natural size). Uses per-test temporary URLs under FileManager.default.temporaryDirectory with cleanup in defer. Added second test covering sequential runs producing two distinct valid files. Third test (from #336) exercises the back-pressure seam.

---

## 336: OffscreenVideoRenderer back-pressure path is not covered by any test

+++
status: closed
priority: low
kind: enhancement
created: 2026-04-21T01:43:08Z
updated: 2026-04-21T01:47:30Z
closed: 2026-04-21T01:47:30Z
+++

The polling loop in `OffscreenVideoRenderer.appendFrame` (to be replaced
as part of #321) only runs when `AVAssetWriterInput.isReadyForMoreMediaData`
is false. At 30 frames of 640x480 into an H.264 encoder that effectively
never happens, so whether the fix works cannot be meaningfully verified by
the existing test.

The underlying blocker is that `OffscreenVideoRenderer` takes a hard
dependency on a concrete `AVAssetWriterInput` constructed internally. We
cannot inject a fake / stub that reports `isReadyForMoreMediaData = false`
to exercise the wait path.

Options to consider (design only; no action required until someone wants
to fix this):

1. Factor the writer-input out behind a small protocol
   (`VideoSinkInput` or similar) with two methods:
   `append(_:presentationTime:) -> Bool` and `waitUntilReady() async`.
   Production implementation wraps `AVAssetWriterInput`; tests inject a
   controllable fake.
2. Expose a way to throttle encoding (e.g. artificially small pixel buffer
   pool) so the real encoder back-pressures on a reasonable workload.
3. Accept that the wait path is not unit-testable and rely on manual /
   integration testing for regressions.

Until this is addressed, changes to the wait logic (like #321) have to be
verified by inspection, not tests.

Related: #321, #335.

- `2026-04-21T01:47:30Z`: Done: OffscreenVideoRenderer now takes an optional `waitUntilReady: (() async -> Void)?` closure via an internal designated init. Production passes nil and gets a KVO-based implementation; tests inject a controllable closure and assert invocation count. Verified by testVideoRendererBackPressureSeam.

---

## 337: Make RenderViewViewModel init cheap so per-body churn doesn't matter

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-21T02:12:26Z
updated: 2026-04-21T02:25:32Z
closed: 2026-04-21T02:25:32Z
+++

Follow-up to #299. Currently RenderViewHelper creates a RenderViewViewModel eagerly in its struct init (needed since #306 for environment propagation on first frame). SwiftUI discards all but the first, but each allocation still pays for System() and associated setup.

Structural fix: make RenderViewViewModel.init() allocation cheap — defer System() and signpost ID creation to first draw(in:) (or first access). That way the per-body churn becomes a tiny object shell, and the allocation tracker (added for #299) becomes a dev-only diagnostic rather than a real problem.

Keeps both #298 (no expensive per-frame work) and #306 (environment available on first frame) happy.

- `2026-04-21T02:25:32Z`: Made RenderViewViewModel allocation lazy via a cheap ViewModelBox<Content> holder class. Box is allocated per body eval but contains just an optional; the real RenderViewViewModel is created exactly once on first update closure. System() and signpostID are also lazy. Verified StencilDemoView still works (first-frame environment path from #306 is preserved because update runs before draw).

---

## 338: Revisit RenderViewDebugViewModifier: finish or delete

+++
status: closed
priority: low
kind: task
labels: effort:s
created: 2026-04-21T02:34:25Z
updated: 2026-08-08T18:30:54Z
closed: 2026-08-08T18:30:54Z
+++

RenderViewDebugViewModifier is currently dead code: it's not applied anywhere (the .modifier call in RenderViewHelper.body is commented out), and its inspector panel body is entirely commented out too. It was a scaffold for a SwiftUI inspector that would browse the render graph (node tree + node details) via @Environment(RenderViewViewModel<Root>.self).

Revisit: either finish it (wire up a proper node browser using a SystemSnapshot API) or delete it. Related: now that RenderViewHelper no longer does .environment(viewModel), this modifier wouldn't even work as-is — it would need viewModel re-plumbed back into the SwiftUI environment if we keep it.

- `2026-08-08T18:30:54Z`: Deleted. The modifier was never applied, its inspector body was fully commented out, and it read a view model that RenderViewHelper no longer publishes. Rebuilding it would mean re-plumbing the view model into the SwiftUI environment (undoing #298/#299/#337) and writing the browser against SystemSnapshot — a fresh feature, not a revival of this scaffold.

---

## 339: Replace global LibraryRegistry with a non-leaking cache

+++
status: closed
priority: medium
kind: task
labels: effort:m
created: 2026-04-21T02:36:22Z
updated: 2026-08-08T06:51:13Z
closed: 2026-08-08T06:51:13Z
+++

LibraryRegistry.shared holds MTLLibrary instances via strong references for the lifetime of the process. Every compiled shader library (from bundle, source, or wrapped MTLLibrary) stays resident forever even after no ShaderLibrary value still references it.

For long-running apps, apps that compile shaders on the fly (procedural/generated sources), or test suites that compile many variants, this is a leak.

Options:
- Weak-reference the cached ShaderLibrary.State so it's freed when the last ShaderLibrary value goes away (the registry becomes a dedupe-while-alive cache, not a retain-forever cache).
- Scope the cache to a device or a user-owned context instead of a global singleton.
- Expose an explicit purge API.

Same concern applies to the per-library ShaderCache of MTLFunctions, though those die with their library automatically — so fixing LibraryRegistry should cover it.

- `2026-04-21T02:36:47Z`: Design idea: a .shaderScope() element modifier that establishes a scoped ShaderLibrary cache via the element environment. Libraries/functions compiled inside the scope live in the scope's cache and die with it. No global singleton. Apps get explicit lifetime control — e.g. per-RenderView, per-scene, or per-experimental-area. Default behavior (no explicit scope) could still use a process-wide cache for convenience, but it would be opt-in or overridable.
- `2026-04-21T02:48:26Z`: Related: #295 is a broader refactor of the whole ShaderLibrary/LibraryRegistry/ShaderCache stack. This issue is the narrower leak subset.
- `2026-08-08T06:51:13Z`: Already resolved: there is no LibraryRegistry singleton any more. ShaderLibrary.State is now owned by a per-scope ShaderStore (adopted lazily via the element environment, with a private fallback store per RenderView), so libraries die with their store rather than living for the process lifetime.

---

## 340: Add .debugGroup() element modifier for pushDebugGroup/popDebugGroup

+++
status: closed
priority: low
kind: feature
labels: effort:s
created: 2026-04-21T03:10:58Z
updated: 2026-08-08T16:17:59Z
closed: 2026-08-08T16:17:59Z
+++

Expose Metal's pushDebugGroup/popDebugGroup as an element modifier, e.g. .debugGroup("Scene") { ... }. Makes GPU captures and Instruments traces much easier to read. Follow-up from #48 — the label coverage for buffers/textures/pipelines/encoders is already in place; debug groups are the remaining piece.

- `2026-08-08T16:17:59Z`: Added .debugGroup(_:), which pushes on the innermost active encoder (render/compute/blit) or the command buffer when wrapping whole passes, and pops on workload exit.

---

## 341: RenderPipeline PSO cache never hits — ObjectIdentifier of copied descriptor

+++
status: closed
priority: critical
kind: bug
created: 2026-05-04T21:33:59Z
updated: 2026-05-04T21:58:17Z
closed: 2026-05-04T21:58:17Z
+++

RenderPipelineCache.Key includes ObjectIdentifier(renderPipelineDescriptor) but the descriptor is a fresh copy every frame (copyWithType on line ~110 of RenderPipeline.swift). Fresh copy = new ObjectIdentifier = cache miss every time = makeRenderPipelineState called every frame for every RenderPipeline element. With 60+ surfaces × 2 passes this causes 120+ PSO compilations per frame, dropping from 60fps to ~37fps. The other key fields (vertex/fragment function, vertex descriptor, pixel formats, depth/stencil) already capture what matters — the descriptor ObjectIdentifier should be removed from the key.

---

## 342: RenderPipelineDescriptorModifier forces PSO rebuild every frame

+++
status: closed
priority: critical
kind: bug
created: 2026-05-05T21:08:57Z
updated: 2026-05-05T21:25:39Z
closed: 2026-05-05T21:25:39Z
+++

RenderPipelineDescriptorModifier.requiresSetup always returns true (can't compare closures). This causes setupEnter to run every frame, which calls copyWithType on the descriptor. The copy creates new object identities for vertexDescriptor (and potentially other sub-objects), causing RenderPipeline's PSO cache key to change every frame — defeating the #341 fix. Result: makeRenderPipelineState called every frame for every RenderPipeline that has a renderPipelineDescriptorModifier ancestor.

\- `2026-05-05T21:12:14Z`: ## Analysis

The problem has two parts:

1. `RenderPipelineDescriptorModifier.requiresSetup(comparedTo:)` always returns `true` because closures aren't comparable. This means `setupEnter` runs every frame.

2. `setupEnter` calls `copyWithType` on the `MTLRenderPipelineDescriptor`, creating a new object identity each frame. Downstream, `RenderPipeline`'s PSO cache key may be affected by the fresh descriptor identity (e.g. if the modifier sets a new `vertexDescriptor` on the copy, that sub-object gets a new identity each frame).

Even if child `needsSetup` flags aren't directly propagated, the modifier writing a fresh-identity descriptor into the environment every frame means any child `RenderPipeline` that *does* run setup (for any reason) will always cache-miss.

## Proposed Fix

Follow the same pattern as `RenderPassDescriptorModifier`:

- Move the modification logic from `setupEnter` to `configureNodeBodyless`, which runs every frame during the update/tree-walk phase (before setup). Environment values set here are inherited by children via `applyInheritedEnvironment`.
- Return `false` from `requiresSetup(comparedTo:)` since the modifier no longer has setup-phase work.
- Read the descriptor from the parent node's environment (like `RenderPassDescriptorModifier` does) to get the fresh value for the current frame.

This way the descriptor is always correctly modified for children, but no unnecessary `needsSetup` flags are set, and `RenderPipeline`'s cache can work properly.

\- `2026-05-05T21:15:24Z`: ## Fix applied

Two changes:

1. **RenderPass**: Moved `MTLRenderPipelineDescriptor()` creation from `setupEnter` to `configureNodeBodyless`. This creates a fresh (lightweight) descriptor each frame during the update phase, making it available before setup runs.

2. **RenderPipelineDescriptorModifier**: Moved descriptor modification from `setupEnter` to `configureNodeBodyless` (mirroring `RenderPassDescriptorModifier`'s pattern). Reads from parent environment to get the fresh descriptor. Returns `false` from `requiresSetup`.

Together, these ensure the modifier applies every frame without triggering `needsSetup` on itself or downstream nodes. `RenderPipeline`'s PSO cache now works correctly — cache keys stay stable across frames.

Updated test in EasyWins3Tests to expect `requiresSetup == false`.

All 347 tests pass.

\- `2026-05-05T21:23:36Z`: ## Correction: Root cause is different

The configureNodeBodyless fix was a valid improvement (avoids unnecessary `needsSetup` flags), but it doesn't solve the PSO rebuild problem.

**Actual root cause:** The PSO cache key uses `ObjectIdentifier(environment.vertexDescriptor)`. When the element tree is rebuilt each frame (as RenderView does), `.vertexDescriptor(shader.inferredVertexDescriptor())` creates a **new** `MTLVertexDescriptor` instance each frame. The `ObjectIdentifier` changes → cache miss → PSO rebuilt every frame.

This happens with or without `RenderPipelineDescriptorModifier`. The modifier is a red herring — the real issue is that the cache key relies on object identity for values that are recreated each frame.

**Fix needed:** Replace `ObjectIdentifier`-based cache key fields with value-based comparisons. The `vertexDescriptor` (and potentially `linkedFunctions`) fields in `RenderPipelineCache.Key` need to compare by content, not by identity.

\- `2026-05-05T21:25:36Z`: ## Actual fix

Replaced `ObjectIdentifier`-based cache key for `vertexDescriptor` with value-based comparison using `NSObjectValueKey<MTLVertexDescriptor>`. This wrapper uses `MTLVertexDescriptor`'s `isEqual(_:)` and `hash` (which compare by content) instead of object identity.

`MTLVertexDescriptor` instances are frequently recreated each frame when the element tree is rebuilt (e.g. `.vertexDescriptor(shader.inferredVertexDescriptor())`), so using `ObjectIdentifier` caused the cache key to change every frame even though the descriptor contents were identical.

Added regression test `testPSOCacheStableWithDescriptorModifier` that verifies PSO cache hits on frames 2+ with a `renderPipelineDescriptorModifier` present. All 348 tests pass.

---

## 343: Investigate conservative requiresSetup patterns that always return true due to closure comparison

+++
status: closed
priority: medium
kind: task
labels: effort:m
created: 2026-05-05T21:12:22Z
updated: 2026-08-08T06:58:29Z
closed: 2026-08-08T06:58:29Z
+++

Find all code similar to:\n\n```swift\nnonisolated func requiresSetup(comparedTo old: RenderPipelineDescriptorModifier<Content>) -> Bool {\n    // Since we can't compare closures, be conservative\n    true\n}\n```\n\nThese always return `true` because closures can't be compared, causing unnecessary pipeline rebuilds. Investigate alternative approaches (e.g., identity tokens, dirty flags, or value-based descriptors) to avoid redundant setup work.

- `2026-08-08T06:04:04Z`: Related: #346 is a concrete instance of this pattern (EnvironmentWritingModifier).
- `2026-08-08T06:58:29Z`: Audited every conservative requiresSetup. Fixed three that hold no setup state of their own: _ConditionalContent now compares which branch is active, EnvironmentReader compares its key path, AnyElement compares the wrapped element's type. The remaining conservative sites are correct as-is: SetupModifier, AnyBodylessElement, RenderPipeline/MeshRenderPipeline/ComputePass/MetalFXSpatial all run user closures or build descriptors during setup and genuinely cannot know whether the result changed. The environment-writing case was handled separately in #346. Existing tests asserting the old always-true behaviour were updated.

---

## 344: RenderView.body creates MTLCommandQueue during GPU work

+++
status: closed
priority: high
kind: bug
labels: effort:s
created: 2026-05-05T21:45:06Z
updated: 2026-08-08T06:08:27Z
closed: 2026-08-08T06:08:27Z
+++

RenderView.body evaluates `device.makeCommandQueue()` every time SwiftUI re-evaluates the body (when no commandQueue is provided via the environment). This can happen during an active draw callback, triggering the Metal warning:

> Your application created a MTLCommandQueue object during GPU work

The commandQueue should be created once and cached, similar to how RenderViewViewModel is lazily created via ViewModelBox (#337). The `device ?? _MTLCreateSystemDefaultDevice()` line has the same potential issue.

- `2026-08-08T06:08:27Z`: Fixed: device/command queue are now resolved lazily and cached in ViewModelBox inside RenderViewHelper's update closure instead of being created during body evaluation.

---

## 345: Repeated .run() calls rebuild System and pay per-call overhead

+++
status: closed
priority: medium
kind: enhancement
labels: performance, effort:l
created: 2026-05-14T04:06:44Z
updated: 2026-08-08T06:59:29Z
closed: 2026-08-08T06:59:29Z
+++

When driving MetalSprockets headlessly across many independent one-shot workloads (e.g. an offline bake that runs a fixed element tree per input sample, hundreds or thousands of times), `Element.run()` is the obvious entry point.

Each `.run()` call:
- Looks up the default `MTLDevice` and creates a new `MTLCommandQueue`.
- Allocates a new `System`.
- Runs the full setup phase (PSO cache lookups, descriptor resolution, etc.).
- Runs the workload phase, commits a command buffer, and `waitUntilCompleted`s.

For a high-throughput batch workload, this per-call setup adds up. Profiling a bake that runs ~2900 `.run()` calls (each a one-frame depth render + compute dispatch on a stable element tree) shows non-trivial time spent re-running setup and re-creating per-call infrastructure that, in principle, could be amortised across all the calls.

There's no obvious public API for "run this element tree N times against a persistent driver / System / command queue." `OffscreenRenderer` is the closest, but it's targeted at a single render surface; `Element.run()` is general but throws everything away each call. Users have to either tolerate the overhead or reach into package-internal types (`System` is `package final class`) to roll their own.

Real-world use case: an offline UV-atlas visibility bake in <https://github.com/schwa/RoomCaptureTestbed>. Reusing one driver across all frames is the last big remaining win after caching the `ShaderLibrary` + resolved shader functions and reducing the per-frame attachment sizes.

Not prescribing the shape of the fix — could be a new public "Runner" type, a reusable `System`, an extended `OffscreenRenderer`, or something else entirely. Flagging the problem so it can be considered.

- `2026-08-08T06:59:29Z`: Already implemented: Sources/MetalSprockets/Roots/Runner.swift provides a public reusable driver holding a persistent device, command queue and System, with tests in RunnerTests.swift. The remaining amortization blocker described here (EnvironmentWritingModifier.requiresSetup always true) was fixed in #346, so structurally-stable trees now skip per-node setup across runs.

---

## 346: EnvironmentWritingModifier.requiresSetup always returns true, defeating setup-phase amortization

+++
status: closed
priority: medium
kind: bug
labels: performance, effort:m
depends: 345
created: 2026-05-14T04:14:09Z
updated: 2026-08-08T06:44:01Z
closed: 2026-08-08T06:44:01Z
+++

[`EnvironmentWritingModifier.requiresSetup(comparedTo:)`](Sources/MetalSprockets/Core/EnvironmentWritingModifier.swift) currently returns `true` unconditionally, with the comment "Since we can't compare closures, be conservative".

Because every `.environment(_:_:)` modifier produces an `EnvironmentWritingModifier`, this means that any element tree wrapped in `.environment()` always re-triggers per-node setup on every `System.update(root:)`, even when the tree is structurally identical to the previous one.

This is the main remaining blocker for #345 (Runner amortization). With a reused `System`, nodes are preserved across runs and `processSetup` could skip them — but the conservative `requiresSetup = true` here forces setup to re-run anyway. The wins from `Runner` today are limited to:

- Not allocating a new `System` per call.
- Not creating a new `MTLCommandQueue` per call.
- Reusing cached environment values on nodes (e.g. `renderPipelineState`), so PSO lookups hit cache.

The full "setup phase is a no-op on repeated calls with stable trees" win is gated on this.

### Possible approaches

1. **Compare the resulting environment values.** The modifier applies a closure to `MSEnvironmentValues`; if we apply both old and new closures to a baseline and diff the resulting storage, we can detect when nothing meaningful changed. Cost: one extra `MSEnvironmentValues` construction per modifier per update.
2. **Specialize the public `environment(_:_:)` overload.** The keypath + value form has enough information to compare — store the keypath + `AnyHashable` value on the modifier and compare directly. Only the closure-form (if there is one) needs to stay conservative.
3. **Track `requiresSetup` more granularly.** Most env values don't affect setup at all; only a small set (pipeline-relevant ones like `renderPipelineDescriptor`, MSAA settings, etc.) actually do. Could opt into setup invalidation per environment key.

Approach 2 is probably the cleanest first step and covers the vast majority of real-world uses.

### Repro / impact

Easy to demonstrate with a `Runner` test: run the same element tree N times, count how many times `BodylessElement.setup` is invoked. Today it's invoked on every run; with this fixed it should drop to once (on the first run) for any subtree under a stable `.environment()` chain.

- `2026-08-08T06:04:04Z`: Related: #343 tracks the general conservative-requiresSetup pattern.
- `2026-08-08T06:44:01Z`: Fixed via approach 2: added an Equatable-constrained .environment(_:_:) overload that records key path + value on EnvironmentWritingModifier, so requiresSetup(comparedTo:) compares values instead of closures. The opaque closure path stays conservative.

---

## 347: Replace isPOD with BitwiseCopyable where possible

+++
status: open
priority: low
kind: enhancement
labels: effort:m
created: 2026-05-18T04:25:45Z
updated: 2026-08-08T22:00:16Z
+++

Swift 6's `BitwiseCopyable` protocol covers most of what our `isPOD`/`_isPOD` helper checks (trivially copyable, no refs, no ARC), but as a compile-time constraint rather than a runtime check.

Investigate replacing uses of `isPOD` in `Sources/MetalSprocketsSupport/BaseSupport.swift` and its call sites:

- `Sources/MetalSprockets/Metal/Parameters.swift` (lines 189, 203): currently runtime `assert(isPOD(...))`. If the surrounding APIs can be made generic over `<T: BitwiseCopyable>`, the checks become compile-time and stricter.
- Tests in `Tests/MetalSprocketsTests/EasyWins2Tests.swift` would need updating.

Caveats:
- `BitwiseCopyable` requires declared/synthesized conformance; `_isPOD` is purely structural at runtime, so it can return true for types not marked `BitwiseCopyable`.
- If any call site takes erased `Any` values, a runtime check still needs to stay.

Decide: convert what we can to generic `BitwiseCopyable` constraints, keep `isPOD` only where runtime erasure forces it (or drop it entirely if no such sites remain).

- `2026-08-08T16:23:40Z`: parameter(_:value:) and parameter(_:values:) are now constrained to BitwiseCopyable, so the POD check happens at compile time; the runtime isPOD/isPODArray/isArray asserts and the (now unused) helpers in MetalSprocketsSupport are gone. MetalSupport still ships runtime equivalents if an erased check is ever needed.
- `2026-08-08T22:00:16Z`: Reverted: the BitwiseCopyable constraint on parameter(_:value:)/(_:values:) broke downstream callers (MetalSprocketsAddOns) passing C/Metal header structs. Back to some Any with runtime POD asserts for now.

---

## 348: Investigate SwiftUI 27 @ContentBuilder

+++
status: closed
priority: medium
kind: task
labels: effort:m
created: 2026-06-09T21:14:28Z
updated: 2026-08-08T06:59:03Z
closed: 2026-08-08T06:59:03Z
+++

Look at SwiftUI 27's @ContentBuilder result builder. Evaluate whether/how it could apply to MetalSprockets' DSL (e.g. replacing or complementing existing @PassBuilder/result builders, ambiguous overload behavior, etc.). See skill: swiftui-whats-new-27.

- `2026-08-08T06:59:03Z`: Investigated. Conclusion: no action needed, and @ContentBuilder does not apply to MetalSprockets' DSL.
- `2026-08-08T06:59:03Z`: @ContentBuilder is SwiftUI's unification of its own builders (ViewBuilder etc.); it removes the View constraint from those builders. It is not a mechanism for third-party DSLs — ElementBuilder already does what MetalSprockets needs, including variadic-generics buildBlock producing TupleElement.
- `2026-08-08T06:59:03Z`: Audited MetalSprocketsUI and the example app for the documented SDK 27 source incompatibilities: no hardcoded TupleView in generic parameters, no MapKit import (so no empty-builder/EmptyMapContent ambiguity), no ShapeStyle expressions passed to the non-builder overlay/background (both call sites use the trailing-closure/in: forms), no Swift Charts usage.
- `2026-08-08T06:59:03Z`: One theoretical shadowing risk: MetalSprockets declares its own public Group (an Element, not a View). Client code that imports both SwiftUI and MetalSprockets in a SwiftUI view body could hit an ambiguity that the old ViewBuilder View constraint used to resolve. Nothing in this repo trips it, and the fix would be client-side qualification (SwiftUI.Group). Worth a docs note if it ever bites; filing no change now.
- `2026-08-08T06:59:03Z`: The package builds clean against the SDK 27 toolchain.

---

## 349: Investigate SwiftUI 27 @State macro changes

+++
status: closed
priority: medium
kind: task
labels: effort:s
created: 2026-06-09T21:14:43Z
updated: 2026-08-08T06:05:23Z
closed: 2026-08-08T06:05:23Z
+++

In SwiftUI 27, @State became a macro. This can cause compile errors like 'used before being initialized', 'invalid redeclaration of synthesized property', or 'extraneous argument label' after SDK update. Reordering init is the WRONG fix. Audit MetalSprockets for affected @State usage and apply correct migration. See skill: swiftui-whats-new-27.

- `2026-08-08T06:05:23Z`: Closing as moot: no observed problem under the current SDK/CI. Reopen if it resurfaces.

---

## 350: Missing useComputeResources(_:usage:) array variant

+++
status: closed
priority: low
kind: enhancement
labels: effort:xs
created: 2026-06-18T17:32:16Z
updated: 2026-08-08T16:12:02Z
closed: 2026-08-08T16:12:02Z
+++

`Support.swift` defines:

- `Element.useResource(_ resource:, usage:, stages:)` (single, render)
- `Element.useResource(_ resource:?, usage:, stages:)` (optional, render)
- `Element.useResources(_ resources: [any MTLResource], usage:, stages:)` (array, render)
- `Element.useComputeResource(_ resource:, usage:)` (single, compute)
- `Element.useComputeResource(_ resource:?, usage:)` (optional, compute)

But there is **no `useComputeResources(_ resources: [any MTLResource], usage:)`** array variant for compute.

Use case: Phosphor 2 binds a Metal 3 bindless argument buffer of N textures (`iChannel0..N`) to a compute kernel, and needs to call `useResource` on each so they're resident when the GPU dereferences the argument buffer. Today you have to either chain individual `useComputeResource` modifiers (compile-time loop fights the result builder) or drop into an `.onWorkloadEnter { env.computeCommandEncoder?.useResource(...) }` and lose the nice element modifier shape.

Mirror the render-side `useResources(_:usage:stages:)` signature, minus `stages`:

```swift
func useComputeResources(_ resources: [any MTLResource], usage: MTLResourceUsage) -> some Element
```

(Also probably worth adding an optional-array variant for symmetry.)

- `2026-08-08T16:12:02Z`: Added useComputeResources(_:usage:) plus an optional-array variant, mirroring the render-side useResources.

---

## 351: ComputeDispatch does not support indirect dispatch

+++
status: closed
priority: medium
kind: enhancement
created: 2026-07-20T19:44:57Z
updated: 2026-07-21T20:29:29Z
closed: 2026-07-21T20:29:29Z
+++

ComputeDispatch only supports CPU-specified grid sizes (threadgroupsPerGrid / threadsPerGrid). Metal's MTLComputeCommandEncoder.dispatchThreadgroups(indirectBuffer:indirectBufferOffset:threadsPerThreadgroup:) has no equivalent, so GPU-driven pipelines whose workload size is computed on the GPU (e.g. survivor counts after culling, expanded entry counts after binning) cannot size their dispatches without over-dispatching to capacity or reading counts back to the CPU. Needed by MetalSprocketsGaussianSplats RFC 0002 (TileAlt renderer).

---

## 352: Elements holding an @Observable model are treated as changed every frame

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m
created: 2026-08-08T16:09:14Z
updated: 2026-08-08T21:12:51Z
closed: 2026-08-08T21:12:51Z
+++

An element whose stored properties are class references (e.g. an @Observable model) is not Equatable, so isEqual(node.element, element) returns false on every update. shouldUpdateNode therefore reports a change each frame, which resets the node's environment and sets needsSetup = true, so the setup phase re-runs for that node every frame even when nothing about the model changed.

Observation tracking (#287) means a genuine change already marks the node dirty, so the per-frame 'changed' verdict is pure overhead.

Seen with:

    struct ModelElement: Element {
        let model: Model   // @Observable class
        var body: some Element { ... }
    }

Wanted: identity-based comparison for class-typed (and @Observable) stored properties in the non-Equatable isEqual fallback, so an element holding the same model instance compares equal.

- `2026-08-08T20:40:18Z`: Related: #367-#371 (subtree skipping) — @Observable-holding elements will still compare as changed; the equality question is separate from the traversal-skipping work.

---

## 353: Three functions exceed the cyclomatic_complexity limit

+++
status: closed
priority: low
kind: task
labels: effort:m
created: 2026-08-08T16:32:00Z
updated: 2026-08-08T23:08:03Z
closed: 2026-08-08T23:08:03Z
+++

The swiftlint cyclomatic_complexity rule is commented out of only_rules in .swiftlint.yml because three functions violate it:

- Sources/MetalSprockets/Core/System+Process.swift:27 (processWorkloadWithSkipping, complexity 11)
- Sources/MetalSprockets/Metal/FunctionConstants.swift:99 (complexity 13)
- Sources/MetalSprockets/Metal/ShaderLibrary.swift:210 (complexity 16)

Each is a long switch or if-chain that would need splitting before the rule can be enabled. Until then the rule catches nothing project-wide.

Wanted: split the three functions, then enable cyclomatic_complexity in .swiftlint.yml.

---

## 354: .msaa(sampleCount:) never anti-aliases and drops rendering after the first frame

+++
status: closed
priority: high
kind: bug
labels: bug, effort:m
created: 2026-08-08T18:46:37Z
updated: 2026-08-08T19:53:13Z
closed: 2026-08-08T19:53:13Z
+++

The .msaa(sampleCount:) element modifier does not anti-alias, and from the second frame onwards the caller's render target stops being updated.

Repro (256x256 offscreen, diagonal-edged triangle, one OffscreenRenderer reused):

1. Render a RenderPass wrapped in .msaa(sampleCount: 4). Capture the image.
2. Render the same tree again with different geometry (a smaller triangle). Capture the image.

Expected: frame 1 has a smoothed diagonal edge; frame 2 shows the smaller triangle, also smoothed.

Actual: frame 1 is byte-identical to the same scene rendered with no .msaa() at all (hard aliased edge). Frame 2 is byte-identical to frame 1 — the smaller triangle never appears; the returned texture still holds frame 1's contents.

Evidence: rendering the aliased scene and the sampleCount:4 scene through OffscreenRenderer produces PNGs that compare byte-identical (cmp). In the two-frame repro, the frame-2 image shows frame 1's geometry.

Observed mechanics:
- MSAAModifier.configureNodeBodyless returns early while its @MSState multisampleTexture / resolveTexture are nil, so on the first frame the pass descriptor is never modified. Those textures are created in setupEnter, which runs after configureNode in the same frame.
- On later frames the textures exist, the pass descriptor is rewritten to target the modifier's own multisample texture with resolveTexture set to the modifier's own private resolve texture. Nothing copies that resolve texture back into the render target the caller supplied, so OffscreenRenderer keeps returning its untouched (stale) colorTexture.

Existing coverage did not catch this: MSAATests and MSAAModifierTests only assert that rendering completes and that the returned texture has the expected width/height/sampleCount, all of which hold whether or not MSAA does anything.

Env: macOS, Apple silicon, Xcode 27.0 beta 4, MetalSprockets @ 61a6c479.

---

## 355: Misplaced .msaa() is a silent no-op

+++
status: closed
priority: medium
kind: bug
labels: bug, effort:s
created: 2026-08-08T18:49:44Z
updated: 2026-08-08T19:53:13Z
closed: 2026-08-08T19:53:13Z
+++

`.msaa(sampleCount:)` rewrites the render pass descriptor, so it only has an effect when it wraps a `RenderPass`. Applying it to a `RenderPipeline` (or anything else inside the pass) does nothing at all: no error, no log, no warning — just an un-antialiased image that looks like a correct render.

Repro:

    // No effect, no diagnostic.
    try RenderPass {
        try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
            Draw { ... }
        }
        .msaa(sampleCount: 4)
    }

Expected: either the modifier works wherever it is placed, or the misplacement is reported (thrown error or logged warning), the way a misplaced .parameter() reports 'must be placed inside a RenderPipeline or ComputePipeline content block'.

Actual: silently ignored.

Found while writing golden-image tests: the first version of the test applied the modifier to the pipeline and produced an image byte-identical to the no-MSAA render, with nothing to indicate why.

Related: #354 (msaa does not anti-alias even when correctly placed), #11 (element graphs that compile but are meaningless).

---

## 356: Capture modifier cannot produce a .gpuTraceDocument

+++
status: closed
priority: medium
kind: bug
labels: bug, effort:s
created: 2026-08-08T18:52:50Z
updated: 2026-08-08T19:55:28Z
closed: 2026-08-08T19:55:28Z
+++

`.capture(_:target:destination:)` accepts any `MTLCaptureDestination`, but `.gpuTraceDocument` can never succeed: the modifier builds an `MTLCaptureDescriptor` with a destination and a capture object and never sets `outputURL`, which Metal requires for that destination.

Repro (host launched with MTL_CAPTURE_ENABLED=1, so captures are permitted):

1. Render any element wrapped in `.capture(true, target: .device, destination: .gpuTraceDocument)`.
2. Observe `MTLCaptureManager.shared().isCapturing` during and after the render.

Expected: a .gputrace file is written somewhere the caller can find it.

Actual: `startCapture(with:)` throws, the error is swallowed by the modifier's do/catch and logged as 'capture: Failed to start capture: ...', rendering proceeds, and no capture ever runs. Nothing surfaces to the caller.

There is also no way for a caller to say where the trace should be written, so the destination is unusable even if the start succeeded.

Applies to both `Element.capture(_:target:destination:)` and the `View.capture(_:target:destination:)` used by RenderView.

---

## 357: An error thrown during the workload phase aborts the process

+++
status: closed
priority: high
kind: bug
labels: bug, effort:m
created: 2026-08-08T19:03:49Z
updated: 2026-08-08T19:49:04Z
closed: 2026-08-08T19:49:04Z
+++

Any error thrown while a render or compute pass is encoding takes the whole process down with SIGABRT instead of propagating to the caller. The encoder is created by the pass's workloadEnter and ended in its workloadExit; when a descendant throws, the traversal unwinds without running workloadExit, so the encoder is released un-ended and Metal asserts.

Repro:

    let pass = try RenderPass {
        try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
            Draw { _ in throw MyError() }
        }
        .vertexDescriptor(vs.inferredVertexDescriptor())
    }
    let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
    _ = try renderer.render(pass)   // process aborts here

Expected: `render` throws MyError and the process stays alive.

Actual: Abort trap: 6.

Crash trace:

    __assert_rtn
    MTLReportFailure.cold.1
    MTLReportFailure
    -[_MTLCommandEncoder dealloc]
    -[AGXG17XFamilyRenderContext dealloc]
    AutoreleasePoolPage::releaseUntil(objc_object**)

This is not limited to user code throwing from a Draw closure. The framework's own errors go the same way, so the diagnostics it takes care to produce cannot actually be caught:

- `.parameter()` applied outside a pipeline throws 'missingEnvironment(reflection)' with a hint explaining the correct placement — thrown mid-pass, so the process aborts instead of showing it.
- An unknown parameter name throws `missingBinding`.
- A parameter targeting a stage the encoder cannot serve throws `configurationError`.

Consequence for tests: none of those error paths can be asserted through `OffscreenRenderer` or `Runner`, because reaching them kills the test process.

Related: the same unwinding problem was fixed for `System.activeNodeStack` in the #296 commit, where the phase traversals now clear the stack on the way out. The encoders need equivalent treatment.

---

## 358: Depth-stencil state is frozen after the first frame

+++
status: closed
priority: high
kind: bug
labels: effort:m
created: 2026-08-08T19:56:32Z
updated: 2026-08-08T20:21:28Z
closed: 2026-08-08T20:21:28Z
+++

## What happens

Once a `RenderPipeline` (or `MeshRenderPipeline`) node has run setup once, changing the depth-stencil descriptor on a later frame has no effect. The pipeline keeps using the depth-stencil state built on the very first frame.

## Why

`RenderPipeline.setupEnter` only builds a depth-stencil state when the node's environment does not already have one:

    var builtDepthStencilState: MTLDepthStencilState?
    if environment.depthStencilState == nil, let depthStencilDescriptor = environment.depthStencilDescriptor {
        builtDepthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        node.environmentValues.depthStencilState = builtDepthStencilState
    }

`node.environmentValues` persists across frames (`System+Process` merges the parent environment into the node's existing storage rather than replacing it), so from frame 2 onwards `environment.depthStencilState` is never nil and the descriptor is ignored. `MeshRenderPipeline` has the same shape.

Two knock-on effects:

- The cache-hit branch `if environment.depthStencilState == nil, let cachedDSS = cache.depthStencilState` is unreachable for the same reason — dead code in both files.
- The `depthStencil:` component of the pipeline cache key correctly registers a miss when the descriptor changes, so a *new* pipeline state is built, but it is paired with the *old* depth-stencil state.

## Reproduction

`GoldenRenderingTests.'changing the depth compare function between frames takes effect'`. Two coplanar quads, red then green:

- Fresh renderer, `.always`: green covers the overlap (golden `CoplanarDepthAlways`).
- Same renderer, frame 1 `.less` then frame 2 `.always`: frame 2 still renders as if `.less` were in force (red keeps the overlap).

The test is currently wrapped in `withKnownIssue`; unwrap it when this is fixed.

---

## 359: renderPipelineDescriptorModifier changes are ignored after the first frame

+++
status: closed
priority: high
kind: bug
labels: effort:m
created: 2026-08-08T20:02:36Z
updated: 2026-08-08T20:24:39Z
closed: 2026-08-08T20:24:39Z
+++

## What happens

A `renderPipelineDescriptorModifier` that changes what it does between frames has no effect from frame 2 onwards. The pipeline state built on the first frame keeps being used.

## Why

`RenderPipelineCache.Key` is built from shader identities, linked functions, the vertex descriptor, attachment pixel formats and sample count, the depth-stencil descriptor, and the label. Nothing a `renderPipelineDescriptorModifier` does is part of the key, so a frame that only changes the descriptor is a cache *hit* and `setupEnter` returns early with the stale `MTLRenderPipelineState`.

This is the same failure mode as #358 but a different mechanism: #358 is a stale depth-stencil state, this is a stale pipeline state.

## Reproduction

`testBlendStateChangeBetweenFramesTakesEffect` in `RenderPipelineDescriptorModifierTests`. Two overlapping half-alpha triangles, one `OffscreenRenderer`, a descriptor modifier that is always present and only toggles `isBlendingEnabled`:

- Frame 1, blending off: matches the `NoAlphaBlend` golden.
- Frame 2, blending on: still matches `NoAlphaBlend`, not `WithAlphaBlend`.

Rendering the blending-on frame into a fresh renderer produces `WithAlphaBlend` correctly (`testRenderPipelineDescriptorModifierWithAlphaBlending`), which rules out the golden being wrong.

## Notes

Fixing this means the cache key has to reflect the modified descriptor. Hashing the `MTLRenderPipelineDescriptor` after the modifier has run (the way `NSObjectValueKey` already does for `MTLVertexDescriptor`) would work, at the cost of running the modifier on every frame before the cache lookup.

The test is currently wrapped in `withKnownIssue`; unwrap it when this is fixed.

---

## 360: Make the command buffer descriptor configurable via the environment

+++
status: closed
priority: medium
kind: enhancement
labels: effort:s, subtask
created: 2026-08-08T20:06:55Z
updated: 2026-08-08T20:19:47Z
closed: 2026-08-08T20:19:47Z
+++

`CommandBufferElement.workloadEnter` (Sources/MetalSprockets/Metal/CommandBufferElement.swift) constructs a bare `MTLCommandBufferDescriptor()` with no way for callers to influence it.

Add an environment entry for the command buffer descriptor and a modifier to set/mutate it, following the existing `RenderPassDescriptorModifier` pattern (copy-on-write into the child environment so a shared descriptor is never mutated in place).

Acceptance criteria:
- `UVEnvironmentValues` has a `commandBufferDescriptor` entry.
- A public modifier lets an element supply or mutate the descriptor for its subtree.
- `CommandBufferElement` uses a copy of the environment descriptor when present, and a fresh `MTLCommandBufferDescriptor()` otherwise.
- Test covers a descriptor property (e.g. `retainedReferences` or `errorOptions`) set via the modifier reaching the created command buffer.

Part of #89.

---

## 361: Make Metal logging a per-subtree environment value

+++
status: closed
priority: medium
kind: enhancement
labels: effort:s, subtask
created: 2026-08-08T20:06:59Z
updated: 2026-08-08T20:20:53Z
closed: 2026-08-08T20:20:53Z
+++

`CommandBufferElement.workloadEnter` reads the global `SystemEnvironment.current.metalLoggingEnabled` to decide whether to call `addMetalSprocketsLogging(device:)`. Callers cannot enable or disable Metal logging for a specific element subtree.

Acceptance criteria:
- `UVEnvironmentValues` has a `metalLoggingEnabled` entry that defaults to the current `SystemEnvironment` value.
- A public modifier sets it for a subtree.
- `CommandBufferElement` consults the environment value instead of the global.
- Existing behaviour is unchanged when no modifier is applied.

Part of #89.

---

## 362: Publish render attachment formats into the environment

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m, subtask
created: 2026-08-08T20:07:06Z
updated: 2026-08-08T21:08:47Z
closed: 2026-08-08T21:08:47Z
+++

`RenderPipeline` currently derives attachment pixel formats and sample count by reaching into the render pass descriptor's textures. Before it can stop doing that, the elements that produce render pass descriptors must publish the formats themselves.

Scope: every place that sets `environmentValues.renderPassDescriptor` — RenderView / root runners, offscreen render setups, `MSAAModifier`, `MetalFXSpatial`, `MetalFXTemporal`, and `RenderPassDescriptorModifier` — also publishes the corresponding attachment formats.

Acceptance criteria:
- Environment entries exist for colour attachment pixel format(s), depth pixel format, stencil pixel format, and raster sample count.
- Every descriptor producer sets them consistently with the attachments it configures.
- `RenderPassDescriptorModifier` recomputes them after the caller mutates the descriptor.
- Tests assert the published values match the descriptor's attachment textures for the MSAA and MetalFX paths.

No behaviour change yet: `RenderPipeline` still reads the descriptor (see the follow-up subtask).

Part of #89.

---

## 363: Make RenderPipeline read attachment formats from the environment

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m, subtask
depends: MetalSprockets-mature-robin#362
created: 2026-08-08T20:07:15Z
updated: 2026-08-08T21:10:18Z
closed: 2026-08-08T21:10:18Z
+++

`RenderPipeline.setupEnter` (Sources/MetalSprockets/Metal/RenderPipeline.swift) copies the render pass descriptor and pulls `colorAttachments[0].texture`, `depthAttachment.texture` and `stencilAttachment.texture` to fill in pipeline descriptor formats, `rasterSampleCount`, and the `RenderPipelineCache.Key`. The pipeline should not need the render pass descriptor at all.

Depends on the attachment format environment values being published.

Acceptance criteria:
- `setupEnter` no longer reads `environment.renderPassDescriptor`.
- Pixel formats, `rasterSampleCount`, and the cache key come from the environment format values.
- Explicitly configured formats on the pipeline descriptor still win over the environment defaults, as today.
- PSO caching behaviour from #327 / #333 / #334 is preserved: no per-frame cache misses when only texture identity changes.
- MSAA and MetalFX example/test scenes still render correctly.

Part of #89.

---

## 364: StateBox has no synchronization but is written from GPU completion handlers

+++
status: closed
priority: high
kind: bug
labels: concurrency, effort:m
created: 2026-08-08T20:31:19Z
updated: 2026-08-08T21:07:42Z
closed: 2026-08-08T21:07:42Z
+++

StateBox (Sources/MetalSprockets/Core/StateBox.swift) is a plain final class with no synchronization around its stored value or its dependency list.

Off-isolation writes are a documented, supported scenario: the comment at StateBox.swift:47 lists "a GPU completion handler" as a place an MSBinding write can arrive from, and System.markDirty was wrapped in OSAllocatedUnfairLock for #330 specifically because "onCommandBufferCompleted handlers write back to @MSState" concurrently with System.update on the owning isolation.

markDirty only protects the dirty identifier set. The value and dependency list underneath it are unprotected:

- The wrappedValue setter writes _value and then walks/notifies dependencies.
- The wrappedValue *getter* also mutates state: it reassigns dependencies (filter) and appends the current node.

So a completion-handler write can race a main-thread traversal read, and two reads on different threads can race each other. Concurrent mutation of the dependencies array is a memory-safety problem (reallocation under another thread) rather than just a stale value.

Not yet observed as a crash in tests; found by review. Whether off-isolation writes should be supported at all, or rejected with a precondition, is undecided — the docs currently promise both.

- `2026-08-08T20:40:17Z`: Related: #367 (propagate dirty marks up the ancestor chain) touches the same StateBox write path.

---

## 365: ShaderLibrary.ID is @unchecked Sendable and carries a mutable MTLCompileOptions

+++
status: closed
priority: medium
kind: bug
labels: concurrency, effort:s
created: 2026-08-08T20:31:31Z
updated: 2026-08-08T21:08:57Z
closed: 2026-08-08T21:08:57Z
+++

ShaderLibrary.ID (Sources/MetalSprockets/Metal/ShaderLibrary.swift:81) is declared `public enum ID: Hashable, @unchecked Sendable`, and one of its cases is `source(String, MTLCompileOptions?)`.

MTLCompileOptions is a mutable, non-Sendable reference type. The @unchecked annotation asserts the whole enum is safe to share, so two isolation domains can end up holding the same options object and one can mutate it while the other reads it. Nothing in the type provides the locking or immutability that would justify the annotation.

Second effect: because the payload is a class, Hashable/== for the `.source` case compare by object identity. Two structurally identical MTLCompileOptions instances therefore produce different IDs, so library lookups that should hit an existing entry miss instead.

---

## 366: KVO observation leaks in OffscreenVideoRenderer.defaultWaitUntilReady

+++
status: closed
priority: low
kind: bug
labels: concurrency, effort:s
created: 2026-08-08T20:31:31Z
updated: 2026-08-08T21:09:48Z
closed: 2026-08-08T21:09:48Z
+++

Sources/MetalSprockets/Roots/OffscreenVideoRenderer.swift:141-165.

defaultWaitUntilReady observes AVAssetWriterInput.isReadyForMoreMediaData with `options: [.new, .initial]`. The .initial option means the observation block can run synchronously inside the `input.observe(...)` call, i.e. before the returned NSKeyValueObservation has been assigned to the local `observation` variable.

In that path:
1. The block resumes the continuation (correctly guarded against double-resume by the OSAllocatedUnfairLock).
2. `observation?.invalidate()` is a no-op because `observation` is still nil.
3. `input.observe` then returns and assigns the live observation to the variable, which nobody ever invalidates.

Result: the observation outlives the await, stays registered on the input, and its block runs again on every subsequent readiness change for the lifetime of the input. No crash — the resumed flag prevents a second resume — but the observer and its captured continuation leak.

Hit whenever the input is not ready at call time but becomes ready between the readiness check and the observe call, or whenever .initial delivers a ready value synchronously.

---

## 367: Propagate dirty marks up the ancestor chain

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m, subtask
created: 2026-08-08T20:39:19Z
updated: 2026-08-08T20:47:38Z
closed: 2026-08-08T20:47:38Z
+++

Part of #197.

StateBox currently marks only the owning node dirty. Subtree skipping needs the whole ancestor chain marked so an update can tell whether any node inside a subtree is dirty.

Acceptance criteria:

- `2026-08-08T20:39:19Z`: StateBox marking a node dirty also marks each ancestor via Node.parentIdentifier.
- `2026-08-08T20:39:19Z`: System exposes a way to ask whether a subtree contains any dirty node.
- `2026-08-08T20:39:19Z`: Tests cover nested state mutation marking root..leaf, and clearing after update.
- `2026-08-08T20:40:17Z`: Related: #364 (StateBox has no synchronization) — ancestor-chain dirty marking touches the same write path; coordinate the two.

---

## 368: tmpprobe

+++
status: closed
priority: medium
kind: none
created: 2026-08-08T20:39:21Z
updated: 2026-08-08T20:39:26Z
closed: 2026-08-08T20:39:26Z
+++

---

## 369: Record subtree extents in traversal events

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m, subtask
depends: 367
created: 2026-08-08T20:39:34Z
updated: 2026-08-08T20:48:25Z
closed: 2026-08-08T20:48:25Z
+++

Part of #197. Depends on #367.

To reuse an unchanged subtree, System.update must be able to splice the previous nodes and traversal events for that subtree as a unit.

Acceptance criteria:
- Traversal events (or a parallel index) let you locate the contiguous enter/exit range for a given node.
- A helper returns the previous nodes and events for a subtree root.
- Tests assert extents are correct for nested and sibling structures.

---

## 370: Skip re-evaluating clean subtrees in System.update

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m, subtask
depends: 369
created: 2026-08-08T20:39:34Z
updated: 2026-08-08T20:51:14Z
closed: 2026-08-08T20:51:14Z
+++

Part of #197. Depends on #369.

Acceptance criteria:
- update(root:) skips element.visitChildren/body evaluation for subtrees containing no dirty node, splicing previous nodes and traversal events instead.
- previousIterator alignment, needsSetup, and teardown of removed nodes stay correct.
- Existing System/NeedsSetup/SystemProcess tests still pass.

---

## 371: Enable SelectiveRebuildTests and cover skipping edge cases

+++
status: closed
priority: medium
kind: enhancement
labels: effort:s, subtask
depends: 370
created: 2026-08-08T20:39:35Z
updated: 2026-08-08T20:59:45Z
closed: 2026-08-08T20:59:45Z
+++

Part of #197. Depends on #370.

Acceptance criteria:
- statelessChildDoesNotRebuild and unusedBindingDoesNotRebuildChild drop withKnownIssue and pass.
- Added coverage for conditional branch switches, node removal, and elements moved by explicit .id() while skipping is active.

---

## 372: Extract TreeReconciler from System.update

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m, subtask
created: 2026-08-08T20:39:47Z
updated: 2026-08-08T21:08:52Z
closed: 2026-08-08T21:08:52Z
+++

Part of #292.

update(root:) is a 100+ line nest of local functions with shared mutable captures.

Acceptance criteria:
- A TreeReconciler type owns element-tree diffing and produces the ordered node dictionary plus traversal events.
- System.update delegates to it; no behaviour change.
- TreeReconciler is testable without driving setup/workload phases.

---

## 373: Make activeNodeStack private to the phase runner and pass environment explicitly

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m, subtask
depends: 372
created: 2026-08-08T20:39:47Z
updated: 2026-08-08T21:11:06Z
closed: 2026-08-08T21:11:06Z
+++

Part of #292. Depends on #372.

Acceptance criteria:
- activeNodeStack is no longer readable state on System; a phase/traversal context owns it.
- @MSEnvironment and @MSState resolve values through an explicit context rather than reaching into System.current's stack.
- Existing environment and state tests pass unchanged in behaviour.

---

## 374: Add a single render(root:) entry point enforcing phase order

+++
status: closed
priority: medium
kind: enhancement
labels: effort:s, subtask
depends: 373
created: 2026-08-08T20:39:47Z
updated: 2026-08-08T21:12:30Z
closed: 2026-08-08T21:12:30Z
+++

Part of #292. Depends on #373.

Acceptance criteria:
- render(root:) runs update -> setup -> workload in order.
- update/processSetup/processWorkload become internal (or otherwise not the supported call sequence).
- Callers in the repo and samples use render(root:).

---

## 375: Rebalance System tests toward the render(root:) boundary

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m, subtask
depends: 374
created: 2026-08-08T20:39:47Z
updated: 2026-08-08T21:14:25Z
closed: 2026-08-08T21:14:25Z
+++

Part of #292. Depends on #374.

Acceptance criteria:
- SystemTests/NeedsSetupTests/SystemProcessTests/NodeTests no longer assert interior mechanics (needsSetup flags, node identity internals) where an observable outcome would do.
- Replacement tests exercise render(root:) and assert observable rendering outcomes.
- Coverage does not regress.

---

## 376: Define a ShaderLoader port for shader function lookup

+++
status: closed
priority: low
kind: enhancement
labels: effort:m, subtask
created: 2026-08-08T20:40:04Z
updated: 2026-08-08T20:46:50Z
closed: 2026-08-08T20:46:50Z
+++

Part of #295.

Acceptance criteria:
- A ShaderLoader protocol declares function(named:type:constants:) throws -> MTLFunction.
- The real implementation wraps LibraryRegistry + ShaderCache + MTLLibrary.
- ShaderLibrary.function(type:named:) routes through the port; behaviour unchanged.

---

## 377: Move FunctionConstants resolution onto the ShaderLoader port

+++
status: closed
priority: low
kind: enhancement
labels: effort:m, subtask
depends: 376
created: 2026-08-08T20:40:05Z
updated: 2026-08-08T20:47:53Z
closed: 2026-08-08T20:47:53Z
+++

Part of #295. Depends on #376.

Acceptance criteria:
- buildMTLConstants and the namespace resolution (constants ending in ::name) are reachable through the port rather than requiring a live MTLLibrary at the call site.
- A mock library supplying a fixed functionConstantsDictionary can drive constant resolution in tests.

---

## 378: Make ShaderLibrary a value type holding a ShaderLoader

+++
status: closed
priority: low
kind: enhancement
labels: effort:m, subtask
depends: 377
created: 2026-08-08T20:40:05Z
updated: 2026-08-08T20:48:51Z
closed: 2026-08-08T20:48:51Z
+++

Part of #295. Depends on #377. Overlaps #339 (LibraryRegistry leak).

Acceptance criteria:
- ShaderLibrary holds a ShaderLoader instead of an interned ShaderLibrary.State.
- LibraryRegistry becomes an internal detail of the real loader; LibraryRegistry.shared is a default that callers can replace with their own loader.
- Tests and multi-device callers can get an isolated loader.

---

## 379: Add GPU-free tests for shader loading and constants

+++
status: closed
priority: low
kind: enhancement
labels: effort:s, subtask
depends: 378
created: 2026-08-08T20:40:05Z
updated: 2026-08-08T20:50:44Z
closed: 2026-08-08T20:50:44Z
+++

Part of #295. Depends on #378.

Acceptance criteria:
- Tests without a real MTLDevice cover: cache hit returns the same MTLFunction, ambiguous namespace constants throw the expected error, missing constants produce the correct diagnostic, and error paths in function(type:named:).

---

## 380: RenderView @Entry closure environment keys warn and may invalidate every update

+++
status: closed
priority: medium
kind: bug
labels: effort:s, swiftui
created: 2026-08-08T22:16:59Z
updated: 2026-08-08T23:03:57Z
closed: 2026-08-08T23:03:57Z
+++

`Sources/MetalSprocketsUI/RenderView.swift:19` and `:22` store closures in `@Entry` environment values (`drawableSizeChange`, `frameTimingChange`), producing build warnings:

    Storing a closure in '@Entry var drawableSizeChange' may invalidate dependents on every update because closures may not be comparable. (from macro 'Entry')

Beyond the noise, any view reading those keys can be invalidated on every SwiftUI update. Plausible contributor to the repeated 'RenderViewViewModel has been allocated N times' churn seen alongside #298/#299/#337.

Note: wrapping the closure in an Equatable struct is NOT the fix (see swiftui-specialist guidance); needs a real design change, e.g. an identity-carrying box or moving the callbacks off the environment.

---

## 381: Optional element node double-runs its wrapped element's workload/setup phase

+++
status: closed
priority: high
kind: bug
labels: effort:s, regression
created: 2026-08-08T22:22:52Z
updated: 2026-08-08T22:22:57Z
closed: 2026-08-08T22:22:57Z
+++

An 'if let' in an ElementBuilder produces an Optional node above the wrapped element. The phase traversals cast with 'node.element as? any WorkloadElement'; Optional did not conform to WorkloadElement/SetupElement, so the dynamic cast fell back to unwrapping and matched the WRAPPED element. Both the Optional node and the real node then ran enter/exit.

For 'if let buffer { RenderPass { ... } }' (PointCloudDemo) this opens two MTLRenderCommandEncoders on one command buffer:

    -[MTLDebugCommandBuffer renderCommandEncoderWithDescriptor:]:672: failed assertion 'RenderCommandEncoder Validation encoding in progress'

Regression from splitting BodylessElement into SetupElement/WorkloadElement: the old cast targeted BodylessElement, which Optional conforms to directly, so the no-op default won.

Fixed by giving Optional explicit no-op SetupElement/WorkloadElement conformances plus regression tests in OptionalWorkloadTests. General trap worth auditing: any 'as? any SomeProtocol' on node.element can unwrap an Optional node.

---

## 382: Collapsing .parameter() modifiers drops per-stage bindings of the same name

+++
status: closed
priority: high
kind: bug
labels: effort:s, regression
created: 2026-08-08T22:27:27Z
updated: 2026-08-08T22:27:31Z
closed: 2026-08-08T22:27:31Z
+++

ParameterElementModifier.parameters was keyed by name only, so collapsing a chain merged bindings that differ only by stage. SkyboxRenderPipeline binds inverseViewProjectionMatrix for .vertex and .fragment; the fragment binding was dropped:

    Fragment Function(SkyboxShader::fragment_main): missing Buffer binding at index 0 for inverseViewProjectionMatrix[0].

Regression from #54 (collapse chained .parameter() modifiers into one node). Fixed by keying on (name, functionTypes); a repeated name in the SAME stage still resolves nearest-to-content.

---

## 383: Support separate linked functions for vertex and fragment stages

+++
status: new
priority: low
kind: enhancement
created: 2026-08-08T22:39:01Z
+++

`RenderPipeline` assigns `environment.linkedFunctions` to both `vertexLinkedFunctions` and `fragmentLinkedFunctions` (Sources/MetalSprockets/Metal/RenderPipeline.swift). There is no way to supply a different set per stage.

Decide whether the environment key should become stage-keyed (like `Parameters`) or whether a second key is added.

---

## 384: MSBinding uses a UUID for identity

+++
status: closed
priority: low
kind: task
created: 2026-08-08T22:39:02Z
updated: 2026-08-08T23:03:57Z
closed: 2026-08-08T23:03:57Z
+++

`MSBinding` allocates a `UUID` per instance purely to give the binding an identity for `Equatable` (Sources/MetalSprockets/Core/Binding.swift). A cheaper monotonic counter or `ObjectIdentifier` on the backing storage would avoid the allocation and the entropy call on every binding construction.

---

## 385: Data race: StateBox writes Node.needsSetup from off-isolation threads

+++
status: closed
priority: high
kind: bug
labels: concurrency, effort:s
created: 2026-08-08T22:47:30Z
updated: 2026-08-08T23:03:57Z
closed: 2026-08-08T23:03:57Z
+++

StateBox.valueDidChange() can run from a GPU command-buffer completion handler (this is the documented reason System._dirtyIdentifiers is an OSAllocatedUnfairLock, see #330). It calls system.markDirtyIncludingAncestors(node), which takes that lock, and then writes node.needsSetup = true directly.

Node is a plain `final class Node: Identifiable` with an unsynchronized `var needsSetup`. That write can race with System.update(root:)/setup traversal on the owning isolation, so the fix for #330 only closed half the race.

Files: Sources/MetalSprockets/Core/StateBox.swift (valueDidChange, ~lines 100-103), Sources/MetalSprockets/Core/Node.swift:9.

Suggested direction: record needs-setup identifiers under the same lock as the dirty set and apply them at the top of System.update(root:), instead of mutating Node from the completion-handler thread.

---

## 386: ImmersiveRuntime render loop blocks the executor and cannot be cancelled

+++
status: closed
priority: high
kind: bug
labels: concurrency, visionOS, effort:m
created: 2026-08-08T22:47:39Z
updated: 2026-08-08T23:03:57Z
closed: 2026-08-08T23:03:57Z
+++

ImmersiveRuntime.renderLoop() (Sources/MetalSprocketsUI/VisionOS/ImmersiveRuntime.swift:44-58) runs `while true` with no Task.checkCancellation(), and its `.paused` branch calls the synchronous blocking `layerRenderer.waitUntilRunning()` from inside an async, @ImmersiveRendererActor-isolated function. That parks a cooperative-pool thread and blocks the global actor for the whole pause, so nothing else on that actor can run.

The loop is started by a fire-and-forget `Task(priority: .high)` in ImmersiveRenderContent.body (Sources/MetalSprocketsUI/VisionOS/ImmersiveRenderContent.swift:89) whose handle is discarded, so teardown has no way to stop it; it only exits when layerRenderer.state becomes .invalidated. Its error path also uses `print` rather than `logger?.error`.

Effects: a torn-down immersive space can leave a high-priority task alive, and a paused compositor starves the renderer actor.

---

## 387: GPUCountersModifier.Storage is @unchecked Sendable with unsynchronized mutable state

+++
status: closed
priority: medium
kind: bug
labels: concurrency, effort:s
created: 2026-08-08T22:47:39Z
updated: 2026-08-08T23:03:57Z
closed: 2026-08-08T23:03:57Z
+++

Sources/MetalSprockets/Metal/GPUCounters.swift:114. `Storage` is marked @unchecked Sendable but has two plain `var`s (sampler, sampleBuffer) written during the configure phase and read from a command-buffer completed handler on another thread, with no synchronization. Ordering happens to work today because the writes precede submission, but the annotation asserts thread safety the type does not provide.

Options: make the fields immutable (`let`, populated at init) or guard them with an OSAllocatedUnfairLock.

---

## 388: GPUCounterSampler's NSLock guards nothing and misstates why it is @unchecked Sendable

+++
status: closed
priority: low
kind: task
labels: concurrency, effort:s
created: 2026-08-08T22:47:45Z
updated: 2026-08-08T23:03:57Z
closed: 2026-08-08T23:03:57Z
+++

Sources/MetalSprockets/Metal/GPUCounters.swift:41, 94-97. `seconds(forTicks:)` takes an NSLock solely around `device.sampleTimestamps()`, then reads only immutable `let` state. There is no shared mutable state to protect, and sampleTimestamps() is itself thread-safe, so the lock is a no-op.

It is also the only thing that makes the class look internally synchronized, which is the usual justification for @unchecked Sendable. The real reason is that MTLDevice/MTLCounterSet are not Sendable. Remove the lock and document the actual reason (or use nonisolated(unsafe) let for the Metal objects).

---

## 389: System.current is a global side-channel for traversal context

+++
status: new
priority: medium
kind: enhancement
labels: effort:l, architecture
created: 2026-08-08T23:14:01Z
+++

Ten call sites reach traversal state through the `@TaskLocal System.current` rather than being handed the context they need: `MSEnvironment` (EnvironmentValues.swift:170), `EnvironmentReader`, `Element` body evaluation (Element.swift:82), `StateBox.resolveSystem()`, `Element+SystemExtensions`, and the modifiers in `RenderPipelineDescriptorTransformer`, `RenderPassDescriptorModifier`, `MSAAModifier`, `GPUCounters`, plus ambient `ShaderStore` lookup in `ShaderLibrary`.

Consequences: any code can reach into the whole `System` (not just the node it is entitled to), the dependency is invisible in signatures, and anything that runs outside a traversal (a completion handler, a `Task`) silently sees `nil` and has to guess whether that means teardown or misuse.

#292 called for the active node stack to be private to the phase runner, with environment access passed explicitly. #373 encapsulated the stack in `TraversalContext` but left the task-local reach-through in place.

Wanted: pass the traversal context (or just the current node/environment) explicitly to the places that need it, and shrink or remove `System.current`.

---

## 390: System still owns the node dictionary, phases, dirty set and snapshotting

+++
status: new
priority: low
kind: enhancement
labels: effort:l, architecture
created: 2026-08-08T23:14:01Z
+++

#292 proposed splitting `System` into a `TreeReconciler` (done, #372), a `PhaseRunner` that drives setup/workload over a frozen traversal event list, and a thin `System` facade composing the two.

Only the reconciler was extracted. Setup and workload traversal still live on `System` (System+Process.swift) alongside the node dictionary, traversal events, dirty/pending-setup sets, and the snapshot/dump machinery.

Wanted: move the phase traversal into its own type that owns the traversal context, leaving `System` as the facade that composes reconciliation and phase running.

Note: mostly subsumes the remaining god-object part of #292; the side-channel half is tracked separately.

---

## 391: api-check CI job cannot be reproduced locally

+++
status: new
priority: medium
kind: bug
labels: effort:s, ci
created: 2026-08-08T23:39:15Z
+++

The `api-check` job in `.github/workflows/swift.yml` regenerates `.public-api.yaml` with `swift-api-tool` and diffs it against the committed file. On mismatch it tells you to run `swift-api-tool . -o .public-api.yaml` locally and commit.

Following that instruction produces a file that fails CI, because `swift-api-tool`'s output depends on the toolchain it runs under. Comparing CI (Xcode 26.4) with a local Xcode 27.0 beta on the same source:

- Existential spelling: CI emits `any MTLTexture`, `[any MTLFunction]`, `(any CAMetalDrawable)?`; Xcode 27 emits `MTLTexture`, `[MTLFunction]`, `CAMetalDrawable?`.
- Synthesized `==`: CI emits `public static func == (lhs: ComputeKernel, rhs: ComputeKernel) -> Bool`; Xcode 27 emits `(lhs: `Self`, rhs: `Self`)`.

That is roughly 150 spurious diff lines. So the snapshot can only be regenerated by someone running the exact CI Xcode, and any Xcode bump silently invalidates the whole file.

Consequence: `api-check` has been red on `main` since at least 2026-08-08, and the documented remedy makes it worse. It was last fixed by hand-applying CI's own diff output to the committed file, which is not a workflow anyone should have to repeat.

Options worth considering:
- Normalise the snapshot before comparing (canonicalise `any`/`Self` spellings) so it is toolchain-independent.
- Have the job upload the regenerated `public-api.yaml` as a workflow artifact, so the fix is "download and commit" rather than "reproduce CI's Xcode".
- Pin the tool and toolchain together and state the required Xcode version in the failure message.

---

## 392: Touching @MSState from onCommandBufferCompleted crashes: Index out of range in TraversalContext

+++
status: closed
priority: high
kind: bug
labels: effort:m
created: 2026-08-09T18:48:34Z
updated: 2026-08-09T19:01:50Z
closed: 2026-08-09T19:01:50Z
+++

Reading or writing @MSState inside an onCommandBufferCompleted handler crashes. The handler runs on Metal's completion queue, which has no traversal context, so TraversalContext.currentNode subscripts an empty node stack.

Crash (Release, macOS 27.0, MetalSprockets-Examples StamFluid demo):

    Thread 4 Crashed:: Dispatch queue: com.Metal.CompletionQueueDispatch
    0  Swift runtime failure: Index out of range
    ...
    6  TraversalContext.currentNode.getter (TraversalContext.swift:23)
    7  StateBox.wrappedValue.getter (StateBox.swift:32)
    8  MSState.wrappedValue.getter (State.swift:57)
    9  closure #6 in StamFluid.body.getter
    11 thunk for @escaping @Sendable (MTLCommandBuffer) -> ()
    12 MTLDispatchListApply
    13 -[_MTLCommandBuffer didCompleteWithStartTime:endTime:error:]

Reproduce: attach .onCommandBufferCompleted to an element in a scene that submits several command buffers per frame, and flip an @MSState Int or Bool inside it.

This is worse than a plain crash, because it is a race rather than a hard failure. If a tree traversal happens to be in flight on the main thread when the completion fires, currentNode returns *some* node and the write silently lands on the wrong one. MetalSprocketsExamples has two places doing exactly this today and they have not crashed yet — GameOfLife and PhosphorPipeline both do 'currentTextureIsA.toggle()' from onCommandBufferCompleted, which is the canonical double-buffer swap and an obvious thing for users to copy.

Questions this raises for the API:
1. Should @MSState access outside a traversal trap with a clear diagnostic instead of an out-of-range crash? Right now the failure gives no hint about the real rule.
2. Is there a supported way to mutate element state from a completion handler? Ping-ponging textures on completion is a normal Metal pattern and the framework currently has no safe answer for it. If the answer is 'marshal back to the main thread and mutate there', the docs should say so and ideally the framework should offer the hop.
3. If it is simply unsupported, onCommandBufferCompleted's documentation should say so explicitly.

Found while restructuring StamFluid for MetalSprocketsExamples#385.

- `2026-08-09T19:01:50Z`: Fixed: StateBox reads only consult the traversal context when System.current is the owning system; off-isolation reads (GPU completion handlers) no longer race the node stack.

---

## 393: gpuCounters reports only whole-pass time: no vertex/fragment stage breakdown, no compute pass support

+++
status: closed
priority: medium
kind: enhancement
labels: performance
created: 2026-08-11T05:39:49Z
updated: 2026-08-11T06:34:33Z
closed: 2026-08-11T06:34:33Z
+++

The .gpuCounters() modifier samples just 2 timestamps per render pass — start-of-vertex and end-of-fragment (endOfVertexSampleIndex and startOfFragmentSampleIndex are set to MTLCounterDontSample) — so callers only get whole-pass GPU duration. There is no way to see time spent in the vertex stage vs the fragment stage, even though .atStageBoundary sampling supports all 4 boundaries. The modifier also only works on render passes: ComputePass has no counter support at all (MTLComputePassDescriptor sample buffer attachments with dispatch boundaries are never used), so compute work like splat sorting cannot be timed via counters. For comparison, the splat-render tool in gaussiansplats-ios samples all 4 render stage boundaries plus compute pass dispatch boundaries, reporting per-pass GPU time with separate vertex and fragment times.

---
