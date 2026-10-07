# ISSUES.md

---

## 11: Address Type Safety

+++
status: open
priority: medium
kind: enhancement
labels: effort:l, deferred, area:api
created: 2026-02-19T00:00:00Z
updated: 2026-09-30T16:17:56Z
+++

MetalSprockets does not provide enough type safety.

SwiftUI accepts almost any combination of views as another view's content. The resulting interface runs, even if the design is poor.

MetalSprockets accepts invalid element graphs at compile time. These graphs can produce no output or crash because elements lack the setup they require.

SwiftUI constrains some combinations: TableView expects TableRows/TableColumns.

Investigate equivalent constraints in MetalSprockets. One option is additional element-builder types, similar to SwiftUI's TableRowBuilder.

*Imported from #3*

---

## 13: Improve ParameterValues

+++
status: closed
priority: medium
kind: enhancement
labels: effort:l, deferred, area:api
created: 2026-02-19T00:00:00Z
updated: 2026-10-07T14:19:23Z
closed: 2026-10-07T14:19:23Z
+++

The `ParameterValues` constructors do not identify the second `.buffer(…, …)` parameter as a buffer offset.
The proposed API also removes the `T` generic parameter.

Consider a struct that accepts closures to call the corresponding `MTLXXXCommandEncoder.setXXXX` methods.

*Imported from #5*

- `2026-04-03T17:33:50Z`: Related: #54 (consolidate parameter nodes)
- `2026-10-07T14:19:23Z`: Closing as obsolete: ParameterValues no longer exists in the codebase, and the proposal (setXXXX encoder closures, .buffer offset) predates the Metal 4 argument-table model. Parameter binding is now handled via the Metal4Parameters path; file a fresh issue if the current API needs work.

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
status: closed
priority: medium
kind: enhancement
labels: effort:l, deferred, area:api
created: 2026-02-19T00:00:00Z
updated: 2026-10-07T14:21:15Z
closed: 2026-10-07T14:21:15Z
+++

Consolidate modifier architecture improvements:

- ElementModifier is not a true Element (was #22)
- Bring back modifiers (was #184)
- Investigate reducing closure usage in modifiers (was #186)

Related issues:

- `2026-02-19T00:00:00Z`: #186 notes closures make element comparison impossible
- `2026-02-19T00:00:00Z`: Need to decide if modifiers should be true Elements or a separate concept
- `2026-04-03T17:33:50Z`: Related: #31 (shaders as modifiers)
- `2026-10-07T14:21:15Z`: Closing as addressed: modifiers are now true Elements (conforming to Element + BodylessContentElement/EnvironmentModifyingElement); no ElementModifier type remains. Sub-items #184 and #186 are already closed. Remaining shader-as-modifier idea tracked separately in #31.

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
status: closed
priority: low
kind: enhancement
labels: effort:l, deferred, area:api
created: 2026-02-19T00:00:00Z
updated: 2026-10-07T14:22:55Z
closed: 2026-10-07T14:22:55Z
+++

By default a vertex and fragment shader should be a modifier instead of a parameter

Right now we have `RenderPipeline(vertexShader, fragmentShader)` - it would be better to do `RenderPipeline().vertexShader(xxx).fragementShader(xxx)` where the shaders get stored in the environment.

This allows shaders to be propagated through environment and override if needed? (maybe - is this actually a useful thing?)

WE can also provide an init method on RenderPipeline that works the same as before.

Also make this change on compute shaders.

*Imported from #23*

- `2026-04-03T17:33:50Z`: Related: #22 (modifier architecture)
- `2026-10-07T14:22:55Z`: Closing for now: speculative (shaders-as-modifiers), uncertain value even in its own description. Reopen if environment-propagated/overridable shaders prove worthwhile.

---

## 32: Re-visit MainActor usage through MetalSprockets

+++
status: closed
priority: none
kind: none
labels: effort:l, area:concurrency
created: 2026-02-19T00:00:00Z
updated: 2026-09-30T16:17:58Z
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

In this proposal, a true boolean triggers capture of the next GPU frame. A button or keyboard shortcut can change the boolean.

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
This is not a problem today, but could become one. Consider:

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
status: closed
priority: low
kind: enhancement
labels: effort:m, deferred, area:api
created: 2026-02-19T00:00:00Z
updated: 2026-10-07T14:17:58Z
closed: 2026-10-07T14:17:58Z
+++

Align MetalSprockets API terminology with SwiftUI's shader API where it makes sense:
- SwiftUI uses "argument", MetalSprockets uses "parameter"
- Review other naming differences
- Goal: make the API feel familiar to SwiftUI developers

- `2026-10-07T14:17:58Z`: Closing wontfix: cosmetic terminology alignment with no concrete scope. Reopen with specific renames if worth doing.

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
status: closed
priority: medium
kind: enhancement
labels: effort:l, deferred, area:api
created: 2026-02-19T00:00:00Z
updated: 2026-10-07T14:20:03Z
closed: 2026-10-07T14:20:03Z
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
- `2026-10-07T14:20:04Z`: Closing.

---

## 70: Improve Attachment flow

+++
status: closed
priority: medium
kind: enhancement
labels: effort:l, deferred
created: 2026-02-19T00:00:00Z
updated: 2026-10-07T14:17:58Z
closed: 2026-10-07T14:17:58Z
+++

We need a nice clean way to allow the user to customise attachments incl (but not limited to) color, depth, stencil etc.

*Imported from #62*

- `2026-04-02T18:39:04Z`: Needs concrete examples of what's painful today before addressing this.
- `2026-10-07T14:17:58Z`: Closing: vague, no concrete pain points ever supplied despite the standing request for examples. Reopen with specific attachment-customization use cases if needed.

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
labels: effort:xl, area:concurrency
created: 2026-02-19T00:00:00Z
updated: 2026-09-30T16:17:58Z
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
- Ensure clear error messages when functions are not found

---

## 89: Improve environment/descriptor modification in CommandBufferElement and RenderPipeline

+++
status: closed
priority: medium
kind: enhancement
labels: effort:l, source:todo, has-subtasks, deferred
depends: 358, 359, 360, 361
created: 2026-02-19T00:00:00Z
updated: 2026-10-07T14:20:17Z
closed: 2026-10-07T14:20:17Z
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

- `2026-10-07T14:20:18Z`: All subtasks (#358, #359, #360, #361) are closed; umbrella complete.

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

Make `ViewAdaptor` internal instead of public. It is only used by RenderView internally.

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
labels: source:todo, effort:m, area:testing
created: 2026-02-19T00:00:00Z
updated: 2026-09-30T16:17:59Z
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
labels: effort:s, source:todo, area:concurrency
created: 2026-02-19T00:00:00Z
updated: 2026-09-30T16:17:58Z
closed: 2026-03-31T17:31:14Z
+++

Both `SplatCloud` and `SplatIndices` are marked as `@unchecked Sendable`, which bypasses Swift's concurrency safety checks.

## Issues:

### SplatCloud
- It is a class (reference type) with mutable state
- Contains mutable properties that could cause data races
- No synchronization mechanisms in place

### SplatIndices
- Contains `TypedMTLBuffer` which is not Sendable
- No synchronization for concurrent access

## Potential Solutions:
1. Make them actors for proper isolation
2. Add proper synchronization (locks/queues)
3. Remove @unchecked Sendable if concurrent access is not needed
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
labels: effort:xl, area:testing
created: 2026-02-19T00:00:00Z
updated: 2026-09-30T16:17:59Z
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
labels: effort:xl, area:testing
created: 2026-02-19T00:00:00Z
updated: 2026-09-30T16:17:59Z
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
labels: source:todo, effort:m, deferred, area:api
created: 2026-02-19T00:00:00Z
updated: 2026-09-30T16:17:56Z
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
labels: enhancement, area:examples
created: 2026-02-19T00:00:00Z
updated: 2026-09-30T16:18:03Z
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

MetalSupport.swift has a custom convenience initializer that converts MDLVertexDescriptor to MTLVertexDescriptor. MetalKit provides MTKMetalVertexDescriptorFromModelIO() for this conversion.
The proposed change replaces the custom implementation with that API.

File: Sources/MetalSprocketsSupport/MetalSupport.swift

The custom implementation manually iterates through attributes and layouts, converting formats and copying offsets. This should be replaced with a call to MTKMetalVertexDescriptorFromModelIO().

*Imported from #162*

- `2026-04-21T04:28:45Z`: Stale — referenced MetalSupport.swift no longer exists; MDLVertexDescriptor use is minimal and not worth tracking.

---

## 171: Might as well make vertex descriptor a parameter to Render

+++
status: closed
priority: low
kind: enhancement
labels: enhancement, effort:m, deferred, area:api
created: 2026-02-19T00:00:00Z
updated: 2026-10-07T14:17:58Z
closed: 2026-10-07T14:17:58Z
+++

Make vertex descriptor a parameter on Render and RenderPipeline instead of requiring environment setup or modifiers. This would make common cases simpler.

- `2026-10-07T14:17:58Z`: Closing: folded into #259 (unify transform/amplification/uniforms), which covers per-vertex data configuration.

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
Since we are creating fresh Storage instances anyway (to prevent the cycles from #68), do we still need the parent chain? Or could we simplify by copying values instead?

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
Some closures, such as @ElementBuilder content, are fundamental to the API. Focus on modifiers that use closures only to capture values.

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
NeoNode has minimal test coverage. The proposed work adds tests for more scenarios.

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
- Test parentIdentifier with state changes that do not affect structure

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

When comparing elements to determine if they need rebuilding, the `isEqual` function returns `false` for types that do not conform to `Equatable`. This means:
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
updated: 2026-10-07T14:21:52Z
+++

EnvironmentReader should ideally be passed a Node as a parameter as noted in the TODO.

File: Sources/MetalSprockets/Core/EnvironmentReader.swift

*Imported from #204*

- `2026-10-07T14:21:52Z`: Specific instance of #389 (System.current global side-channel): visitChildrenBodyless reaches into System.current.traversalContext.currentNode instead of being handed the Node. Best addressed alongside the broader #389 refactor.

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

Audit System class and make properties private that should not be public API. Reduce the exposed surface area.

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

System currently records node removal without cleanup. One option is to call cleanup/onDisappear when a node is removed.

File: Sources/MetalSprockets/Core/System.swift

*Imported from #206*

- `2026-04-21T03:09:00Z`: Added BodylessElement.teardown(_:) protocol hook with empty default; System.update now calls it for nodes removed from the tree (errors are logged, not propagated, so a misbehaving teardown cannot break update). Exposed as a public .onDisappear { ... } element modifier on Element. Covered by OnDisappearTests (8 cases: basic fire/no-fire, reorder, multiple removals, nested modifiers, full replacement, throwing teardown is swallowed).

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

we have explicit labels to computepass and friends. Add them to more places. Use them in more places.

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

Currently, `RenderPipeline` and `ComputePipeline` have a temporary `requiresSetup` implementation that always returns `false`. This works for now because shaders do not change after initial setup, but it will break when shader constants are introduced.

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

- `2026-08-08T15:39:21Z`: Closing as will not-do: the MetalSprocketsSupport split still earns its keep. Revisit under #202 if the batteries-included work needs a home.

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

- `2026-04-21T02:41:30Z`: Closing. MetalSprockets itself does not construct argument buffers internally — the useResource/useResources element modifiers are the API surface for users to call from their own code. No in-tree audit target.

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

We still have not solved the shader compilation problem.

One possible outcome is documented guidance.

Another option is to represent shaders as elements.

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

## 256: Port MetalSprockets to Metal 4

+++
status: closed
priority: high
kind: feature
labels: effort:xl, has-subtasks, area:metal4, area:api
depends: 399, 400, 401, 402, 403, 404, 405, 406, 407, 408, 409
created: 2026-02-19T00:00:00Z
updated: 2026-09-30T16:17:57Z
closed: 2026-09-30T00:53:47Z
+++

Restart index for [RFC 0002 — Port MetalSprockets to Metal 4](RFCs/0002-metal-4.md).

## Current checkpoint

- Complete: #399 baseline, #400 inventory, #401 submission design, #402 copy/barrier design, #403 shader provenance, #420 OS 26 minimums, and #410 internal context/allocator slots.
- Latest implementation commit: 8975c140 (OS 26 floor). Shader provenance: 90642577. Planning index: f9bab1db. #410 context/slot changes are complete but uncommitted in the current working copy.
- Latest validation: 626 tests in 109 suites pass. Ten context/slot tests separately pass with Metal API Validation, including 12 real GPU fill/readback submissions. macOS, generic iOS, and generic visionOS example builds pass; new Swift files lint cleanly.
- Environment: M5 Max/macOS 27/Xcode 27 RC. This is not OS 26 runtime evidence. The native context probe is serial; full overlapping-frame ownership remains ahead.
- Package and examples now require iOS/macOS/visionOS 26. CI remains pinned to Xcode 26.4/macOS 26.
- Production rendering is still legacy. The internal context is not connected to public roots. Its caller currently coordinates commit/event/feedback primitives; tokens, error/timeout delivery, retained resources, and scratch storage are still pending.
- Recommended next: #411 recorded-submission ownership. #415 compiler/cache integration is also dependency-ready. #404 compositor research requires authorized supported-device evidence.
- Known unrelated diagnostics: seven Package.swift trailing-comma warnings on unchanged lines; iOS deprecations recorded under #431/#433; baseline experiment-discovery/GoldenImage bundle warnings. See leaf checkpoints for exact validation logs.

## Phase index

### #405 — Submission foundation
- #410 Context/allocator slots — complete.
- #411 Recorded-submission ownership — next.
- #412 Completion, errors, timeout, callbacks, and shutdown.
- #413 Residency, resource owners, and retirement.
- #414 Value-parameter scratch storage.

### #406 — Internal offscreen proof
- #415 Compiler, reflection, and cache integration — ready.
- #416 Parameter tables and indexed bindings.
- #417 Render/compute/copy encoding.
- #418 Barrier elements and traversal semantics.
- #419 Integrated compute-to-render-to-readback exit gate.

### #407 — Public APIs and rendering roots
- #420 OS 26 deployment minimums — complete.
- #421 Candidate core element/environment/descriptor contracts.
- #422 Runner, Element.run(), and offscreen rendering.
- #423 RenderView drawable lifecycle.
- #424 Offscreen video export.
- #425 Coordinated public-backend cutover after parity.

### #408 — Existing-feature parity
- #426 Render state, depth/stencil, and MSAA.
- #427 Object/mesh pipelines.
- #428 Visible-function tables.
- #429 MetalFX spatial scaling.
- #430 MetalFX temporal history.
- #431 GPU counters and frame timing.
- #432 Capture, logging, labels, and debug groups.
- #433 ARKit texture owners and YCbCr output.
- #404 Existing compositor presentation/device evidence gate.
- #434 Immersive product integration after #404.

### #409 — Release gates
- #435 Platform/device/CI evidence.
- #436 Performance and sustained-memory comparison.
- #437 Migration guide, docs, examples, and API snapshot.
- #438 Legacy/staging cleanup and final completion audit.

## Dependency and staging rules

Dependency fields define readiness. Foundation/compiler work can overlap where prerequisites permit. Candidate roots enable parity tests before #425 public cutover, which depends on all parity leaves. No silent feature removal and no supported dual backend.

No leaf depends on a tracking parent that depends on that leaf. Phase trackers close after their children. This umbrella closes only after the entire scope has evidence or an explicitly approved disposition.

## Pause/resume protocol

Before ending an implementation session, append a checkpoint to its leaf with:
- Completed work, exact files/revision or working-copy state.
- Remaining acceptance criteria and unverified paths.
- Last validation commands/results, OS/SDK/device, and artifact locations.
- Concrete prerequisite, hardware/permission, or design blockers.
- One executable next action.

Update this current checkpoint when a milestone completes or the recommended next action changes. Close work only with its stated evidence. A build is not GPU-output proof. Do not remove failing tests or omit features to make a phase green. Build/test through xcb after implementation tasks; record docs-only skips.

## References and scope

- Documentation/Metal4-Baseline.md and retained Release JSON measurements.
- Documentation/Metal4-Migration-Inventory.md: baseline API/root/feature map and progress notes.
- Documentation/Metal4-Submission-Design.md: ownership/completion contract and #410 implementation boundary.
- Documentation/Metal4-Command-Design.md: copy/barrier contract.
- Documentation/Metal4-Shader-Design.md: implemented shader inputs.

The port is Metal 4-only. Archives, specialization optimizations, automatic dependency inference, ML/tensors, new MetalFX effects, and other new Metal 4 features remain outside this issue.

- `2026-02-19T00:00:00Z`: Evaluate new Metal 4 features
- `2026-02-19T00:00:00Z`: Update framework to use improved APIs
- `2026-02-19T00:00:00Z`: Take advantage of performance improvements
- `2026-02-19T00:00:00Z`: Consider requiring Metal 4 as minimum or providing fallbacks
- `2026-04-18T17:21:58Z`: Draft RFC: [RFCs/0002-metal-4.md](RFCs/0002-metal-4.md) — proposes a phased rollout (backend abstraction → Metal 4 backend → argument tables → pipeline caching → residency sets → ML dispatch element).
- `2026-09-29T16:33:07Z`: The rewritten RFC supersedes the historical phased dual-backend plan in earlier comments. Its status is Proposed; earlier implementation claims are not evidence for this checkout.
- `2026-09-29T16:58:09Z`: Preparation #399–#402 is complete in the working copy: measured baseline, migration inventory, submission design, and copy/barrier design. RFC links all deliverables. Final macOS package run reports 610 tests in 104 suites passing (opt-in measurements/probes disabled there); the 2 focused Metal 4 probes separately pass with API Validation, and the example builds. New gates: #403 raw shader injection contract, #404 immersive presentation device verification. No production backend changes, deployment-target bump, or commits were made in this preparation batch.
- `2026-09-29T18:02:18Z`: Expanded the remaining RFC scope into phase trackers #405–#409 and 29 implementation/release leaves #410–#438. Existing #404 is reused for compositor evidence. Every leaf has acceptance, source/design references, verification, and a resumable checkpoint. Dependencies protect feature parity before #425 public cutover. Recommended restart: #420, then #410. This planning batch changes tracking/docs only.
- `2026-09-29T18:03:56Z`: Planning validation: issues doctor reports no problems. A read-only dependency audit found 41 issues reachable from #256, no missing dependencies, and no cycles. All 29 new implementation leaves contain acceptance, verification, and all checkpoint fields. Currently dependency-ready leaves are #420 (deployment targets), #410 (context/slots), and #404 (compositor evidence, with hardware/permission still required). No compilation was run because this batch changes only tracking and RFC text.
- `2026-09-29T18:59:36Z`: Progress: #411 recorded-submission ownership complete (tokens, one-shot commit, discard, commit-order identifiers, resource retention through completion, encoding unwind). 633 tests pass; macOS/iOS/visionOS builds green. Next ready: #412 completion/error/timeout/callback delivery, then #413/#414. #415 compiler/cache also dependency-ready.
- `2026-09-29T19:08:13Z`: Progress: #412 complete (results, ordered exactly-once callbacks, timeout/fault/quarantine, drain). 652 tests pass; all platform builds green. Next: #413 residency, #414 scratch; #415 compiler/cache is also dependency-ready.
- `2026-09-29T19:11:03Z`: Progress: #413 residency/retirement complete (reference-counted, bounded context residency set). 658 tests pass. Next: #414, then #415.
- `2026-09-29T19:13:14Z`: Progress: #414 scratch storage complete; phase #405 (submission foundation) closed. 664 tests pass. Next: #415 compiler/cache.
- `2026-09-29T19:15:20Z`: Progress: #415 compiler/cache complete. 669 tests pass. Next: #416 argument tables/bindings.
- `2026-09-29T19:18:35Z`: Progress: #416 argument tables/indexed bindings complete. 674 tests pass. Next: #417 render/compute/copy encoding.
- `2026-09-29T19:22:07Z`: Progress: #417 encoder scopes complete. 681 tests pass. Next: #418 barriers.
- `2026-09-29T19:25:59Z`: Progress: #418 barriers complete (element traversal + GPU visibility incl. cross-queue events). 688 tests pass. Next: #419 integrated offscreen proof.
- `2026-09-29T19:30:26Z`: Progress: #419 integrated proof passed; phase #406 closed. 692 tests pass. Next: #421 core element contracts.
- `2026-09-29T20:30:11Z`: Progress: #421 internal core contracts complete (candidates internal until #425 by user decision). 700 tests pass. Next: #422 headless roots.
- `2026-09-29T20:34:47Z`: Progress: #422 headless roots complete (legacy RedTriangle golden parity). Fixed a stale-environment bug in #421 modifiers. 706 tests pass. Next: #423 RenderView, #424 video.
- `2026-09-29T20:38:43Z`: Progress: #423 automatable RenderView lifecycle complete and committed; issue left open pending on-screen evidence (needs launch permission) and MTKView wiring (package visibility vs #425). 711 tests pass.
- `2026-09-29T20:53:30Z`: Progress: #423 complete with real-window evidence (600/600 frames, API Validation clean). Candidate surface is package-visible (not public). 711 tests pass. Next: #424 video export.
- `2026-09-29T20:56:41Z`: Progress: #424 video export complete (shared VideoFrameWriter; decoded-frame verification). 716 tests pass. Next: parity #426 render state/MSAA.
- `2026-09-29T21:04:31Z`: Progress: #426 render state/MSAA parity complete (legacy goldens unchanged; blending, depth/stencil, bias, viewport/scissor, MSAA resolve). 725 tests pass. Next: #427 mesh.
- `2026-09-29T21:09:57Z`: Progress: #427 mesh pipeline parity complete (legacy mesh goldens; fixed payload table-size bug). 731 tests pass. Next: #428 visible-function tables.
- `2026-09-29T21:16:02Z`: Progress: #428 visible-function tables complete (legacy goldens, specializations, residency, diagnostics). 736 tests pass. Next: #429 MetalFX spatial.
- `2026-09-29T21:21:28Z`: Progress: #429 MetalFX spatial complete (Metal 4 compiler-based scaler, explicit queue-barrier/fence sync proven by mutation). 740 tests pass. Next: #430 MetalFX temporal.
- `2026-09-29T21:28:06Z`: Progress: #430 MetalFX temporal complete (history/reset/in-flight verified numerically; visionOS still excluded). 745 tests pass. Next: #431 counters/frame timing.
- `2026-09-29T21:34:58Z`: Progress: #431 counters/timing complete (counter heaps; fragment interval explicitly absent; UIScreen.main fixed). 750 tests pass. Next: #432 capture/logging.
- `2026-09-29T21:59:24Z`: Progress: #432 capture/logging/debug complete with real gpudebug-inspected traces; capture must wrap passes on Metal 4 (GPUTools crash otherwise; #425 must handle roots). 759 tests pass. Next: #433 ARKit (device-gated).
- `2026-09-29T22:07:01Z`: Progress: #433 synthetic/lifetime/orientation work committed; issue open pending an authorized iOS AR device run. 763 tests pass.
- `2026-09-29T22:16:19Z`: Checkpoint: parity #426-#432 closed; #433 open (AR device run); #404/#434 blocked on Vision Pro device runs, deferred by the user. #425 cutover waits on #433/#434.
- `2026-09-29T22:53:45Z`: Checkpoint: #425 cutover landed; public API is Metal 4 only. 737 tests pass with API Validation; all platforms and example build. Remaining: #433 AR device run (use example app), #404/#434 Vision Pro, #435-#438.
- `2026-09-29T23:06:52Z`: On-screen: public RenderView verified by the user on macOS (example app), MSAA off and on, after fixing a launch crash: memoryless attachments (MTKView's default depth) were added to the residency set, which Metal rejects. Fixed in RecordingScope.retainAllocation with a regression test. 738 tests pass under API Validation.
- `2026-09-29T23:23:36Z`: #433 closed: AR verified by the user on iPhone (example app). Remaining device gate: Vision Pro (#404/#434).
- `2026-09-29T23:53:17Z`: #404 and #434 closed with Vision Pro device evidence. All device gates now passed (Mac RenderView, iPhone AR, Vision Pro immersive). Remaining: #435-#438.
- `2026-09-30T00:50:34Z`: Status: all implementation children closed (#425-#434, #436-#439, #438 cleanup). Remaining before release: #435 (OS 26 runtime evidence, CI), #443 (CI Xcode pin), #444 (GPU-less CI runners). Follow-ups: #440 (intermittent GPU output mismatches), #441 (render GPU p95 tail), #442 (first-frame setup).
- `2026-09-30T00:53:47Z`: All children closed. Port complete. Open follow-ups: #440, #441, #442, #443, #444.

---

## 259: Look at unifying transform/amplification/uniforms

+++
status: open
priority: low
kind: enhancement
labels: enhancement, effort:l, deferred, area:api
created: 2026-02-19T00:00:00Z
updated: 2026-10-07T14:17:51Z
+++

We currently pass data to shaders through three different mechanisms, each with a distinct API:

1. **Per-shader uniforms** — transforms and other constants bound once per draw (for example model/view/projection matrices).
2. **Per-amplification-index data** — values that vary per rendered view in amplified rendering (stereo / visionOS), indexed by amplification ID.
3. **Per-vertex data** — vertex buffers / attributes.

Conceptually these are all just 'data bound to shaders', differing only in granularity (per-draw, per-amplification, per-vertex). The current APIs evolved independently and do not share a common vocabulary.

Investigate whether these can be unified (or at least aligned) behind a more consistent API — making it easier to reason about what's varying at what rate, and to move data between granularities without rewriting call sites.

- `2026-10-07T14:17:51Z`: Folded in #171 (make vertex descriptor a parameter to Render): per-vertex/descriptor configuration is part of this unification.

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

Implement a `.transformEnvironment()` modifier similar to SwiftUI's. It changes an environment value based on its current value, rather than replacing it directly:
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

Add `extension MSState: @unchecked Sendable where Value: Sendable {}`. MSState is backed by a reference type (Box<StateBox<Value>>) so it is safe to send across concurrency boundaries. Currently requires `nonisolated(unsafe)` workarounds when capturing @MSState in Tasks.

- `2026-04-02T18:39:04Z`: Unsafe to implement as described. StateBox has no synchronization — _value, dependencies, and hasBeenConnected are all mutated without locking. Box is similarly unprotected. Concurrent access from multiple isolation domains would cause data races. Would need to add a lock to StateBox (or make access actor-isolated) before this conformance is safe.
- `2026-04-02T18:39:04Z`: Merged into #291 (Audit and improve Swift concurrency)

---

## 290: onCommandBufferCompleted and onCommandBufferScheduled modifiers are unreliable and underdocumented

+++
status: closed
priority: high
kind: bug
labels: documentation, area:api
created: 2026-03-31T16:45:51Z
updated: 2026-09-30T16:17:57Z
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

This blocks buffer pooling in MetalSprocketsGaussianSplats (issue #22). That project needs to return index buffers to a pool after GPU completion.

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

Tests prove the mechanism *should* work, yet the issue reports it does not. Possible causes:
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
labels: effort:xl, area:concurrency
created: 2026-03-31T18:27:17Z
updated: 2026-09-30T16:17:58Z
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

**Why they are coupled:** Node stores system: weak System? as a back-reference; BodylessElement protocol methods receive Node directly, giving them full access to mutate arbitrary node state; environment propagation, state restoration, and dirty-marking all happen inside a single traversal context with shared mutable state.

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

**Why they are coupled:** Storage is a class that holds a weak var parent, so reference identity matters; MSEnvironmentValues is a struct wrapping the class, creating COW friction; the parent chain is rebuilt in two separate code paths (update phase and process phase) that can get out of sync. The process-phase patch is a TODO comment noting it may no longer be needed — meaning the two paths may already be inconsistent.

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
3. At minimum, add a non-optional typed wrapper around the reflection environment slot — for example a PipelineContext value type — so that accessing reflection outside of a configured pipeline produces a compile-time or clear runtime error, not a confusing 'must be placed inside' hint.

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

**Why they are coupled:** The three-phase orchestration is repeated verbatim in multiple unrelated types. FrameTimingTracker, error handling, MSAA change detection, and phase ordering all live inside draw(in:) with no seam to test them independently. The nonisolated(unsafe) var for GPU time is a data race waiting to happen and exists only because the frame orchestration and the async GPU completion handler share no typed boundary.

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

When a `RenderView` is removed from the SwiftUI view hierarchy (for example switching tabs in a TabView), the closures and Metal resources captured by the render closure are not released.

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

RenderViewHelper creates a new RenderViewViewModel in its struct init as the default value for @State. SwiftUI only uses this value once (the first time), but the init expression runs every time the struct is recreated — which happens every frame when parent state changes (for example frame timing callback updating @State). This means a class instance + System() is heap-allocated and immediately discarded ~60 times per second for nothing.

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

Issue #298 fixes a new RenderViewViewModel allocation every frame in RenderViewHelper. There is no regression check for this behavior.
Options include an allocation-count test, a debug assertion for repeated initialization per RenderView identity, or Instruments signposts.
Without a check, later changes can restore per-frame allocation.

- `2026-04-21T02:12:40Z`: Added RenderViewViewModelAllocationTracker that counts allocations per Content type and logs a warning at 3 allocations, then every 10 thereafter. Always-on (one atomic increment + dict lookup per allocation). Follow-up #337 filed for the structural fix to make init cheap enough that churn does not matter.

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

ViewAdaptor wraps NSViewRepresentable/UIViewRepresentable but does not implement the static dismantle methods. Adding dismantleNSView and dismantleUIView would let us pause the MTKView and clear its delegate when SwiftUI tears down the representable — preventing stray draw callbacks after the view model is released. Belt-and-suspenders for the .onDisappear fix in #297.

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

\- `2026-08-08T06:54:18Z`: Punting: this is a DNS/hosting change for docs.metalsprockets.com (plus DocC base-path config), which needs access to the domain and Pages settings that I do not have. Unblocker: confirm where docs are hosted (GitHub Pages?) and whether you want DocC published at the site root with a redirect, then I can do the DocC/workflow side.
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
labels: needs-info, effort:m, deferred, area:api
created: 2026-04-02T16:16:32Z
updated: 2026-09-30T16:17:57Z
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

This breaks any BlitPass that uses EnvironmentReader to access \.renderPassDescriptor — for example, to blit a texture into the stencil attachment before a render pass. When the environment value is nil, the blit silently does not execute. The stencil buffer stays all zeros, so a stencil test with compareFunction .equal (reference 0) passes everywhere and no clipping occurs.

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

Root cause identified in #329: data race on System.dirtyIdentifiers from off-main markDirty calls (for example @MSState writes inside onCommandBufferCompleted). Tracked and being fixed in #330.

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

The demo app appears blank on the iPad Pro 11-inch (M5) simulator with iOS 26.4.
A white card contains faint horizontal separators and a green '60' FPS counter in the top-right corner. No rendered content is visible.
The lower screen is empty gray. The Metal surface appears to show no output.

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

FrameTimingView.fpsColor(for:) uses hardcoded thresholds (55 = green, 30 = yellow, else red). These should be relative to the target framerate (for example 120Hz displays would show yellow at 55fps which is wrong).

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

ImmersiveRuntime runs its own render loop but does not expose frame timing statistics like RenderView does via .onFrameTimingChange. Consumers have no way to get FPS or frame duration for immersive rendering without tracking timestamps manually. Add FrameTimingStatistics support to ImmersiveRenderContent or ImmersiveContext.

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

When using .depthCompare() with different compare functions across frames (for example switching between .lessEqual and .greaterEqual), the depth stencil state is cached from the first configuration and not recreated. The Metal debugger confirmed the stencil state remained .lessEqual even after requesting .greaterEqual. Discovered while implementing switchable inverse-Z shadow mapping in MetalSprocketsAddOns.

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

@MSState persists its initial value across frames and never updates, even when the element is reconstructed with a new value. This means function constants or other pipeline configuration stored in @MSState cannot be changed at runtime without destroying and recreating the entire RenderView (for example via .id()).

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

Option 1 is the right general fix. If it is not feasible, at minimum the existing `MetalFXSpatial` should be audited (and its docstring updated) to confirm setup is supposed to be per-frame.

\- `2026-04-21T01:50:13Z`: Fixed: MetalFXSpatial is now a BodylessElement that uses the per-node cache pattern established in #333. The MTLFXSpatialScaler is keyed on (inputFormat, outputFormat, inputWidth, inputHeight, outputWidth, outputHeight) and only rebuilt when one of those changes — so steady-state rendering reuses the same scaler every frame, and the size-change branch still does the right thing.

requiresSetup returns true (AnyBodylessElement's conservative behavior no longer applies since MetalFXSpatial is now its own BodylessElement), but setupEnter is a cache lookup. No more wasted allocations per frame.

Existing MetalFXSpatialTests (encode path, size-change recreation) still pass.

MetalFXTemporal is not in the tree yet; when it lands it should follow the same pattern.

---

## 320: Add .vertexBuffer(_:layoutIndex:) modifier for stage_in vertex buffers

+++
status: closed
priority: medium
kind: feature
labels: area:metal4, area:api
created: 2026-04-18T23:50:57Z
updated: 2026-09-30T16:17:55Z
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
- **Sparse layout indices** (for example layout 0 and 2, no 1). `PipelineBindings` already sizes tables to max(index)+1; should work transparently.

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
labels: cleanup, area:metal4
created: 2026-04-18T23:55:21Z
updated: 2026-09-30T16:17:49Z
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
labels: effort:l, area:testing, area:architecture
created: 2026-04-19T18:36:16Z
updated: 2026-09-30T16:18:01Z
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
2. Exposes typed accessors for each flag (for example `dumpSnapshotsEnabled: Bool`, `renderViewLogFrameEnabled: Bool`).
3. Can be overridden for tests by injecting a custom instance (either via initializer parameter, task-local, or a static-override hook scoped with `defer`).

Call sites (Snapshotter, logging, any future env-gated code) take an optional `SystemEnvironment` parameter that falls back to the default.

## Benefits

- Coverage: tests can exercise the enabled paths without subprocesses or env-var juggling.
- Testability: removes hidden global state from call sites.
- Single point of truth for which env vars MetalSprockets responds to.

## Notes

- `2026-04-19T18:36:16Z`: Current Snapshotter already has a test-only injection (`init(shouldDumpSnapshots:fileURL:)`) added during the coverage push. This issue generalizes that pattern.
- `2026-04-19T18:36:16Z`: Not a `@MSEnvironment` style thing — this is about *process* environment, not element-tree environment. Pick a name that does not collide (for example `SystemEnvironment`, `ProcessEnvironment`, or `RuntimeFlags`).
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

Suggested fix: add an opt-in invalidation key to `ComputePipeline` (for example `invalidationKey: AnyHashable?` at init) and compare it in `requiresSetup`. That avoids rebuilding the PSO every frame for existing demos while letting consumers that depend on environment values (like `linkedFunctions`) opt in. Alternative: compare `computeKernel.function` identity and stash a hash of `linkedFunctions` on the struct.

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

The crash occurs in the normal element-tree comparison path, called from `MTKView.draw`.
Continued rendering can reproduce it without snippet changes or `.id()` teardown.

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

So `MSBinding` captures its enclosing `StateBox` via `unowned`, and the `StateBox` is deallocated between the GPU completion callback and the next main-queue tick. This means `MSBinding`s cannot outlive a single synchronous body evaluation — any deferred capture (Task, DispatchQueue.main.async, continuation) can dangle.

Both the original `Set.contains` crash and this `MSBinding` unowned-read crash point at the same general issue: `System`/`StateBox` lifetime assumes all reads and writes happen inline during body evaluation on main, but nothing in the API prevents (or even discourages) off-main or deferred access. `onCommandBufferCompleted` documents that it 'Called on an unspecified queue after GPU execution finishes', yet any realistic use case (ping-pong toggle, frame counter, perf stats) wants to feed that back into `@MSState`, which is not safe.

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
  hatch for deferred writes (for example an explicit `@MainActor` write API on
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
compare struct fields. This means environment-driven changes (for example a new
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
whatever they know changed (for example the selected shader snippet name, the current
MSAA count, a monotonic counter). Callers who dont pass a key keep todays
behavior.

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

This closes the same class of bug as #327 for render and mesh pipelines (for example linkedFunctions changes no longer silently fail to invalidate the PSO).

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
2. Expose a way to throttle encoding (for example artificially small pixel buffer
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

RenderViewDebugViewModifier is currently dead code: it is not applied anywhere (the .modifier call in RenderViewHelper.body is commented out), and its inspector panel body is entirely commented out too. It was a scaffold for a SwiftUI inspector that would browse the render graph (node tree + node details) via @Environment(RenderViewViewModel<Root>.self).

Revisit: either finish it (wire up a proper node browser using a SystemSnapshot API) or delete it. Related: now that RenderViewHelper no longer does .environment(viewModel), this modifier would not even work as-is — it would need viewModel re-plumbed back into the SwiftUI environment if we keep it.

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

- `2026-04-21T02:36:47Z`: Design idea: a .shaderScope() element modifier that establishes a scoped ShaderLibrary cache via the element environment. Libraries/functions compiled inside the scope live in the scope's cache and die with it. No global singleton. Apps get explicit lifetime control — for example per-RenderView, per-scene, or per-experimental-area. Default behavior (no explicit scope) could still use a process-wide cache for convenience, but it would be opt-in or overridable.
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

Expose Metal's pushDebugGroup/popDebugGroup as an element modifier, for example .debugGroup("Scene") { ... }. Makes GPU captures and Instruments traces much easier to read. Follow-up from #48 — the label coverage for buffers/textures/pipelines/encoders is already in place; debug groups are the remaining piece.

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

1. `RenderPipelineDescriptorModifier.requiresSetup(comparedTo:)` always returns `true` because closures are not comparable. This means `setupEnter` runs every frame.

2. `setupEnter` calls `copyWithType` on the `MTLRenderPipelineDescriptor`, creating a new object identity each frame. Downstream, `RenderPipeline`'s PSO cache key may be affected by the fresh descriptor identity (for example if the modifier sets a new `vertexDescriptor` on the copy, that sub-object gets a new identity each frame).

Even if child `needsSetup` flags are not directly propagated, the modifier writing a fresh-identity descriptor into the environment every frame means any child `RenderPipeline` that *does* run setup (for any reason) will always cache-miss.

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

The configureNodeBodyless fix was a valid improvement (avoids unnecessary `needsSetup` flags), but it does not solve the PSO rebuild problem.

**Actual root cause:** The PSO cache key uses `ObjectIdentifier(environment.vertexDescriptor)`. When the element tree is rebuilt each frame (as RenderView does), `.vertexDescriptor(shader.inferredVertexDescriptor())` creates a **new** `MTLVertexDescriptor` instance each frame. The `ObjectIdentifier` changes → cache miss → PSO rebuilt every frame.

This happens with or without `RenderPipelineDescriptorModifier`. The modifier is a red herring — the real issue is that the cache key relies on object identity for values that are recreated each frame.

**Fix needed:** Replace `ObjectIdentifier`-based cache key fields with value-based comparisons. The `vertexDescriptor` (and potentially `linkedFunctions`) fields in `RenderPipelineCache.Key` need to compare by content, not by identity.

\- `2026-05-05T21:25:36Z`: ## Actual fix

Replaced `ObjectIdentifier`-based cache key for `vertexDescriptor` with value-based comparison using `NSObjectValueKey<MTLVertexDescriptor>`. This wrapper uses `MTLVertexDescriptor`'s `isEqual(_:)` and `hash` (which compare by content) instead of object identity.

`MTLVertexDescriptor` instances are frequently recreated each frame when the element tree is rebuilt (for example `.vertexDescriptor(shader.inferredVertexDescriptor())`), so using `ObjectIdentifier` caused the cache key to change every frame even though the descriptor contents were identical.

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

Find all code similar to:\n\n```swift\nnonisolated func requiresSetup(comparedTo old: RenderPipelineDescriptorModifier<Content>) -> Bool {\n    // Since we can't compare closures, be conservative\n    true\n}\n```\n\nThese always return `true` because closures cannot be compared, causing unnecessary pipeline rebuilds. Investigate alternative approaches (e.g., identity tokens, dirty flags, or value-based descriptors) to avoid redundant setup work.

- `2026-08-08T06:04:04Z`: Related: #346 is a concrete instance of this pattern (EnvironmentWritingModifier).
- `2026-08-08T06:58:29Z`: Audited every conservative requiresSetup. Fixed three that hold no setup state of their own: _ConditionalContent now compares which branch is active, EnvironmentReader compares its key path, AnyElement compares the wrapped element's type. The remaining conservative sites are correct as-is: SetupModifier, AnyBodylessElement, RenderPipeline/MeshRenderPipeline/ComputePass/MetalFXSpatial all run user closures or build descriptors during setup and genuinely cannot know whether the result changed. The environment-writing case was handled separately in #346. Existing tests asserting the old always-true behavior were updated.

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
labels: effort:l, area:performance
created: 2026-05-14T04:06:44Z
updated: 2026-09-30T16:18:00Z
closed: 2026-08-08T06:59:29Z
+++

When driving MetalSprockets headlessly across many independent one-shot workloads (for example an offline bake that runs a fixed element tree per input sample, hundreds or thousands of times), `Element.run()` is the obvious entry point.

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
labels: effort:m, area:performance
depends: 345
created: 2026-05-14T04:14:09Z
updated: 2026-09-30T16:18:01Z
closed: 2026-08-08T06:44:01Z
+++

[`EnvironmentWritingModifier.requiresSetup(comparedTo:)`](Sources/MetalSprockets/Core/EnvironmentWritingModifier.swift) currently returns `true` unconditionally, with the comment "Since we can't compare closures, be conservative".

Because every `.environment(_:_:)` modifier produces an `EnvironmentWritingModifier`, this means that any element tree wrapped in `.environment()` always re-triggers per-node setup on every `System.update(root:)`, even when the tree is structurally identical to the previous one.

This is the main remaining blocker for #345 (Runner amortization). With a reused `System`, nodes are preserved across runs and `processSetup` could skip them — but the conservative `requiresSetup = true` here forces setup to re-run anyway. The wins from `Runner` today are limited to:

- Not allocating a new `System` per call.
- Not creating a new `MTLCommandQueue` per call.
- Reusing cached environment values on nodes (for example `renderPipelineState`), so PSO lookups hit cache.

The full "setup phase is a no-op on repeated calls with stable trees" win is gated on this.

### Possible approaches

1. **Compare the resulting environment values.** The modifier applies a closure to `MSEnvironmentValues`; if we apply both old and new closures to a baseline and diff the resulting storage, we can detect when nothing meaningful changed. Cost: one extra `MSEnvironmentValues` construction per modifier per update.
2. **Specialize the public `environment(_:_:)` overload.** The keypath + value form has enough information to compare — store the keypath + `AnyHashable` value on the modifier and compare directly. Only the closure-form (if there is one) needs to stay conservative.
3. **Track `requiresSetup` more granularly.** Most env values do not affect setup at all; only a small set (pipeline-relevant ones like `renderPipelineDescriptor`, MSAA settings, etc.) actually do. Could opt into setup invalidation per environment key.

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
labels: effort:m, deferred
created: 2026-05-18T04:25:45Z
updated: 2026-10-06T06:21:09Z
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

Look at SwiftUI 27's @ContentBuilder result builder. Evaluate whether/how it could apply to MetalSprockets' DSL (for example replacing or complementing existing @PassBuilder/result builders, ambiguous overload behavior, etc.). See skill: swiftui-whats-new-27.

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

Use case: Phosphor 2 binds a Metal 3 bindless argument buffer of N textures (`iChannel0..N`) to a compute kernel, and needs to call `useResource` on each so they are resident when the GPU dereferences the argument buffer. Today you have to either chain individual `useComputeResource` modifiers (compile-time loop fights the result builder) or drop into an `.onWorkloadEnter { env.computeCommandEncoder?.useResource(...) }` and lose the nice element modifier shape.

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

ComputeDispatch only supports CPU-specified grid sizes (threadgroupsPerGrid / threadsPerGrid). Metal's MTLComputeCommandEncoder.dispatchThreadgroups(indirectBuffer:indirectBufferOffset:threadsPerThreadgroup:) has no equivalent, so GPU-driven pipelines whose workload size is computed on the GPU (for example survivor counts after culling, expanded entry counts after binning) cannot size their dispatches without over-dispatching to capacity or reading counts back to the CPU. Needed by MetalSprocketsGaussianSplats RFC 0002 (TileAlt renderer).

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

An element whose stored properties are class references (for example an @Observable model) is not Equatable, so isEqual(node.element, element) returns false on every update. shouldUpdateNode therefore reports a change each frame, which resets the node's environment and sets needsSetup = true, so the setup phase re-runs for that node every frame even when nothing about the model changed.

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

`.msaa(sampleCount:)` rewrites the render pass descriptor, so it affects rendering only when it wraps a `RenderPass`.
On a `RenderPipeline` or another element inside the pass, it has no effect. There is no error, log, or warning.
The image appears correct except for missing anti-aliasing.

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
- Test covers a descriptor property (for example `retainedReferences` or `errorOptions`) set via the modifier reaching the created command buffer.

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
- Existing behavior is unchanged when no modifier is applied.

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

No behavior change yet: `RenderPipeline` still reads the descriptor (see the follow-up subtask).

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
- PSO caching behavior from #327 / #333 / #334 is preserved: no per-frame cache misses when only texture identity changes.
- MSAA and MetalFX example/test scenes still render correctly.

Part of #89.

---

## 364: StateBox has no synchronization but is written from GPU completion handlers

+++
status: closed
priority: high
kind: bug
labels: effort:m, area:concurrency
created: 2026-08-08T20:31:19Z
updated: 2026-09-30T16:17:58Z
closed: 2026-08-08T21:07:42Z
+++

StateBox (Sources/MetalSprockets/Core/StateBox.swift) is a plain final class with no synchronization around its stored value or its dependency list.

Off-isolation writes are a documented, supported scenario: the comment at StateBox.swift:47 lists "a GPU completion handler" as a place an MSBinding write can arrive from, and System.markDirty was wrapped in OSAllocatedUnfairLock for #330 specifically because "onCommandBufferCompleted handlers write back to @MSState" concurrently with System.update on the owning isolation.

markDirty only protects the dirty identifier set. The value and dependency list underneath it are unprotected:

- The wrappedValue setter writes _value and then walks/notifies dependencies.
- The wrappedValue *getter* also mutates state: it reassigns dependencies (filter) and appends the current node.

A completion-handler write can race a main-thread traversal read. Two reads on different threads can also race.
Concurrent mutation of the dependencies array can reallocate storage while another thread accesses it. This is a memory-safety problem, not only a stale value.

Not yet observed as a crash in tests; found by review. Whether off-isolation writes should be supported at all, or rejected with a precondition, is undecided — the docs currently promise both.

- `2026-08-08T20:40:17Z`: Related: #367 (propagate dirty marks up the ancestor chain) touches the same StateBox write path.

---

## 365: ShaderLibrary.ID is @unchecked Sendable and carries a mutable MTLCompileOptions

+++
status: closed
priority: medium
kind: bug
labels: effort:s, area:concurrency
created: 2026-08-08T20:31:31Z
updated: 2026-09-30T16:17:58Z
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
labels: effort:s, area:concurrency
created: 2026-08-08T20:31:31Z
updated: 2026-09-30T16:17:58Z
closed: 2026-08-08T21:09:48Z
+++

Sources/MetalSprockets/Roots/OffscreenVideoRenderer.swift:141-165.

defaultWaitUntilReady observes AVAssetWriterInput.isReadyForMoreMediaData with `options: [.new, .initial]`. The .initial option means the observation block can run synchronously inside the `input.observe(...)` call, that is before the returned NSKeyValueObservation has been assigned to the local `observation` variable.

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
- System.update delegates to it; no behavior change.
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
- Existing environment and state tests pass unchanged in behavior.

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
- ShaderLibrary.function(type:named:) routes through the port; behavior unchanged.

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
labels: effort:s, area:ui
created: 2026-08-08T22:16:59Z
updated: 2026-09-30T16:18:03Z
closed: 2026-08-08T23:03:57Z
+++

`Sources/MetalSprocketsUI/RenderView.swift:19` and `:22` store closures in `@Entry` environment values (`drawableSizeChange`, `frameTimingChange`), producing build warnings:

    Storing a closure in '@Entry var drawableSizeChange' may invalidate dependents on every update because closures may not be comparable. (from macro 'Entry')

Beyond the noise, any view reading those keys can be invalidated on every SwiftUI update. Plausible contributor to the repeated 'RenderViewViewModel has been allocated N times' churn seen alongside #298/#299/#337.

Note: wrapping the closure in an Equatable struct is NOT the fix (see swiftui-specialist guidance); needs a real design change, for example an identity-carrying box or moving the callbacks off the environment.

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
status: closed
priority: low
kind: enhancement
labels: effort:s, area:api
created: 2026-08-08T22:39:01Z
updated: 2026-10-07T14:36:56Z
closed: 2026-10-07T14:36:56Z
+++

`RenderPipeline` assigns `environment.linkedFunctions` to both `vertexLinkedFunctions` and `fragmentLinkedFunctions` (Sources/MetalSprockets/Metal/RenderPipeline.swift). There is no way to supply a different set per stage.

Decide whether the environment key should become stage-keyed (like `Parameters`) or whether a second key is added.

- `2026-10-07T14:36:56Z`: Fixed: added .linkedFunctions(_:functionType:). .vertex/.fragment link into that stage only; .linkedFunctions(_:) still links into both. PipelineCache now builds separate vertex/fragment static linking descriptors and keys the cache on each stage's list. Tests: fragment-only linking renders red (golden); vertex-only linking is not visible to a fragment table (unlinkedFunction); cache distinguishes stage and per-stage function handles. Mesh pipelines unchanged (still share one list across object/mesh/fragment).

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
labels: effort:s, area:concurrency
created: 2026-08-08T22:47:30Z
updated: 2026-09-30T16:17:59Z
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
labels: effort:m, area:concurrency, area:visionos
created: 2026-08-08T22:47:39Z
updated: 2026-09-30T16:18:01Z
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
labels: effort:s, area:concurrency
created: 2026-08-08T22:47:39Z
updated: 2026-09-30T16:17:59Z
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
labels: effort:s, area:concurrency
created: 2026-08-08T22:47:45Z
updated: 2026-09-30T16:17:59Z
closed: 2026-08-08T23:03:57Z
+++

Sources/MetalSprockets/Metal/GPUCounters.swift:41, 94-97. `seconds(forTicks:)` takes an NSLock solely around `device.sampleTimestamps()`, then reads only immutable `let` state. There is no shared mutable state to protect, and sampleTimestamps() is itself thread-safe, so the lock is a no-op.

It is also the only thing that makes the class look internally synchronized, which is the usual justification for @unchecked Sendable. The real reason is that MTLDevice/MTLCounterSet are not Sendable. Remove the lock and document the actual reason (or use nonisolated(unsafe) let for the Metal objects).

---

## 389: System.current is a global side-channel for traversal context

+++
status: open
priority: medium
kind: enhancement
labels: effort:l, area:architecture, needs-decision
created: 2026-08-08T23:14:01Z
updated: 2026-10-07T14:28:22Z
+++

Ten call sites reach traversal state through the `@TaskLocal System.current` rather than being handed the context they need: `MSEnvironment` (EnvironmentValues.swift:170), `EnvironmentReader`, `Element` body evaluation (Element.swift:82), `StateBox.resolveSystem()`, `Element+SystemExtensions`, and the modifiers in `RenderPipelineDescriptorTransformer`, `RenderPassDescriptorModifier`, `MSAAModifier`, `GPUCounters`, plus ambient `ShaderStore` lookup in `ShaderLibrary`.

Consequences: any code can reach into the whole `System` (not just the node it is entitled to), the dependency is invisible in signatures, and anything that runs outside a traversal (a completion handler, a `Task`) silently sees `nil` and has to guess whether that means teardown or misuse.

#292 called for the active node stack to be private to the phase runner, with environment access passed explicitly. #373 encapsulated the stack in `TraversalContext` but left the task-local reach-through in place.

Wanted: pass the traversal context (or just the current node/environment) explicitly to the places that need it, and shrink or remove `System.current`.

\- `2026-09-30T16:18:18Z`: Related: #390 (the god-object half of #292). This issue is the side-channel half.
\- `2026-10-06T06:18:06Z`: Audited all 10 System.current uses. Punting: needs a design decision and has core-wide blast radius.

Easy group (4): Element.configureNode, RenderPassDescriptorModifier, RenderPipelineDescriptorTransformer, MSAAModifier only need the parent node / ancestor walk. A weak Node.parent set in TreeReconciler would remove these with no API change.

Structural group (5): MSEnvironment.wrappedValue, StateBox read-tracking (resolveSystem + currentNode), Element.trackedBody, EnvironmentReader (#212, deferred), ShaderLibrary ambient ShaderStore. These run inside parameterless property-wrapper getters or body, so there is no explicit channel. Removing them means changing the dynamic-property model: e.g. resolve @MSEnvironment values and bind StateBox to its node in update(in:) before body runs (SwiftUI-style), and pass the node into trackedBody from the reconciler.

Decision needed: (a) split this: file the easy group as a subtask (effort:s) and keep the structural group as the design issue; or (b) commit to the SwiftUI-style dynamic-property injection redesign (effort:l, touches State/Environment/Element core).

- `2026-10-07T14:25:42Z`: Auto-fixer punt: decision-gated and core-wide. The issue's own audit lays out the choice \u2014 (a) carve off the easy group (Element.configureNode + the 3 descriptor/MSAA modifiers) via a weak Node.parent in TreeReconciler as an effort:s subtask, or (b) commit to the SwiftUI-style dynamic-property injection redesign (effort:l, touches State/Environment/Element core). Not inferable from code. Recommend (a): file the easy group as a subtask and keep this as the structural design issue. Say the word and I'll split it.

---

## 390: System still owns the node dictionary, phases, dirty set and snapshotting

+++
status: open
priority: low
kind: enhancement
labels: effort:l, area:architecture
created: 2026-08-08T23:14:01Z
updated: 2026-09-30T16:18:18Z
+++

#292 proposed splitting `System` into a `TreeReconciler` (done, #372), a `PhaseRunner` that drives setup/workload over a frozen traversal event list, and a thin `System` facade composing the two.

Only the reconciler was extracted. Setup and workload traversal still live on `System` (System+Process.swift) alongside the node dictionary, traversal events, dirty/pending-setup sets, and the snapshot/dump machinery.

Wanted: move the phase traversal into its own type that owns the traversal context, leaving `System` as the facade that composes reconciliation and phase running.

Note: mostly subsumes the remaining god-object part of #292; the side-channel half is tracked separately.

- `2026-09-30T16:18:18Z`: Related: #389 tracks the System.current side-channel half of #292.

---

## 391: api-check CI job cannot be reproduced locally

+++
status: closed
priority: medium
kind: bug
labels: effort:s, area:ci
created: 2026-08-08T23:39:15Z
updated: 2026-09-30T16:17:42Z
closed: 2026-09-30T03:41:58Z
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

- `2026-09-30T02:10:11Z`: Additional causes found during the Metal 4 port (from #445, now closed as a duplicate):
- `2026-09-30T02:10:11Z`: The local swift-api-tool 0.2.0 on this Mac is built from ~/Shared/Projects/Scratch/swift-api-tool and emits doc: fields; CI installs crates.io 0.2.0, which does not. So even with the right Xcode, the local build produces a different file.
- `2026-09-30T02:10:11Z`: Buildkite build #4 (shelob, newer Xcode than CI's 26.6, crates.io tool) differs from the committed snapshot by 321 lines: the any/non-any spelling plus View extension members listed in a different group/order. Buildkite's api-check step is soft_fail for now.
- `2026-09-30T02:10:11Z`: On the metal4 branch the snapshot was again fixed by rebuilding CI's output from the run log (GitHub run 36653335857).
- `2026-09-30T03:41:57Z`: Resolved on metal4 by decision: only Xcode 27 is trusted for the snapshot. Scripts/api-snapshot.sh pins swift-api-tool to git tag 0.2.2 (commit 489d57a1; installed into ~/.cache/metalsprockets/, same output as the local Scratch build, deterministic across runs) and refuses to run under any Xcode other than 27. '--check' is a blocking Buildkite step; GitHub's api-check job is removed (its runners only have Xcode 26.x). Snapshot regenerated with Xcode 27. Known quirk: the 0.2.2 tag's Cargo.toml still says 0.2.0, so --version misreports. Still open on main (different snapshot, same problem) until metal4 merges.
- `2026-09-30T04:02:45Z`: Tool version quirk fixed upstream: swift-api-tool main cb998d7d bumps Cargo.toml to 0.2.3 (tags 0.2.1/0.2.2 never bumped it); tagged 0.2.3; output identical to 0.2.2 on this package. Scripts/api-snapshot.sh now pins 0.2.3.

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
3. If this use is unsupported, document that constraint for onCommandBufferCompleted.

Found while restructuring StamFluid for MetalSprocketsExamples#385.

- `2026-08-09T19:01:50Z`: Fixed: StateBox reads only consult the traversal context when System.current is the owning system; off-isolation reads (GPU completion handlers) no longer race the node stack.

---

## 393: gpuCounters reports only whole-pass time: no vertex/fragment stage breakdown, no compute pass support

+++
status: closed
priority: medium
kind: enhancement
labels: area:performance
created: 2026-08-11T05:39:49Z
updated: 2026-09-30T16:18:01Z
closed: 2026-08-11T06:34:33Z
+++

The .gpuCounters() modifier samples two timestamps per render pass: start-of-vertex and end-of-fragment.
endOfVertexSampleIndex and startOfFragmentSampleIndex are set to MTLCounterDontSample. Callers therefore receive only the GPU duration of the whole pass.
Although .atStageBoundary supports all four boundaries, the modifier does not report separate vertex and fragment times.

ComputePass has no counter support. MTLComputePassDescriptor sample-buffer attachments with dispatch boundaries are never used, so counters cannot measure compute work such as splat sorting.

The splat-render tool in gaussiansplats-ios samples all four render boundaries and compute dispatch boundaries.
It reports per-pass GPU time and separate vertex and fragment times.

---

## 394: OffscreenRenderer: expose command-buffer GPU time on Rendering

+++
status: closed
priority: low
kind: enhancement
labels: area:api, area:timing, area:offscreen
created: 2026-08-18T22:43:34Z
updated: 2026-09-30T16:18:03Z
closed: 2026-08-18T23:02:10Z
+++

OffscreenRenderer.render(_:) creates, commits, and waits on the MTLCommandBuffer internally and returns only Rendering { texture }. There is no way for callers to read the command buffer's GPU wall-clock time (commandBuffer.gpuEndTime - gpuStartTime).

That whole-submission GPU time is a correlation-free measurement (unlike timestamp counters, which need CPU/GPU timestamp correlation to convert ticks to seconds), so it is valuable as a sanity cross-check on counter-derived per-pass times.

Ask: capture commandBuffer.gpuStartTime / gpuEndTime in Runner/OffscreenRenderer after waitUntilCompleted and surface it, for example add `gpuTime: TimeInterval` (or start/end) to OffscreenRenderer.Rendering, or a small frame-timing report. Should be opt-in / near-zero cost (the values are already populated after the buffer completes).

Downstream: needed by MetalSprocketsGaussianSplats issue #123 (CLI stats: command-buffer GPU clock cross-check), which is blocked until this hook exists. The splat renderer would plumb it through OffscreenSplatRenderer.FrameReport to the bench CLI.

---

## 395: Release builds can embed development-only Metal shader source

+++
status: closed
priority: high
kind: bug
labels: area:metal, area:build
created: 2026-08-25T22:10:25Z
updated: 2026-09-30T16:18:02Z
closed: 2026-08-25T22:46:26Z
+++

The MetalCompilerPlugin is attached to the MetalSprocketsUIShaders target, but the manifest does not provide a configuration-dependent compilation condition to the plugin. MetalCompilerPlugin cannot read SwiftPM's active debug or release configuration directly. As a result, its debug metallib behavior cannot differ safely between configurations, and release products can contain development-only embedded Metal shader source. App Store validation reports ITMS-91306 for affected archives.

Expected: Debug builds retain shader debugging support. Release builds produce metallibs without embedded development-only shader source.

Actual: The plugin invocation has no target build-setting signal that distinguishes debug from release.

## Proposed fix (per user)

Update MetalCompilerPlugin to a version that supports configuration conditions. Then add this setting to every target that uses the plugin:

```swift
cSettings: [
    .define("METAL_COMPILER_PLUGIN_DEBUG", .when(configuration: .debug))
],
```

- `2026-08-25T22:46:26Z`: Updated MetalCompilerPlugin to 0.1.7 and added the debug-only compilation condition. Debug and Release builds pass, and the test suite passes.

---

## 396: Default metallib output name implies a debug build

+++
status: open
priority: low
kind: enhancement
labels: area:metal, area:plugin, effort:xs, blocked, deferred
created: 2026-08-25T22:45:15Z
updated: 2026-10-07T14:28:22Z
+++

MetalCompilerPlugin names its default output `debug.metallib` in every build configuration. Release builds therefore ship a metallib whose filename incorrectly suggests that it contains debug output.

Expected: The default filename is configuration-neutral.

Actual: Debug and Release builds both produce `debug.metallib`.

## Proposed fix (per user)
Rename the default output to a configuration-neutral filename.

- `2026-10-07T14:27:55Z`: Auto-fixer punt: the default 'debug.metallib' name is produced by MetalCompilerPlugin (external package github.com/schwa/MetalCompilerPlugin), not this repo. This repo only consumes it (ShaderLibrary loads default.metallib and falls back to debug.metallib). The configuration-neutral rename must land in the MetalCompilerPlugin repo, then this repo's fallback can be updated to match. Suggest moving/retitling this issue against that package, or fix it there and bump the dependency.

---

## 397: FrameTimingView flashes at a steady frame rate

+++
status: closed
priority: medium
kind: bug
labels: area:ui, effort:s
created: 2026-09-14T17:18:52Z
updated: 2026-10-05T22:38:03Z
closed: 2026-10-05T22:38:03Z
+++

FrameTimingView (MetalSprocketsUI) visibly flashes even when the frame rate is steady (reported at a stable 60 FPS on iPad).

The view drives an internal TimelineView(.animation(minimumInterval: 1/15)), so it re-renders about 15 times per second. With options: .all the volatile fields (frame time, 1s min–max range, GPU time) change on nearly every tick, and the rows grid uses .fixedSize(), so the badge re-lays-out as digit widths change. The result is a visible flash/jitter of the overlay.

Repro:
1. Show FrameTimingView(statistics:, options: .all) over a RenderView.
2. Run at a stable frame rate on iPad.

Expected: the readout updates smoothly without the whole badge flashing.
Actual: the badge visibly flashes while values tick.

Reported downstream in MetalSprocketsGaussianSplats. Device: iPad (model/OS not specified).

- `2026-10-05T22:38:04Z`: Likely cause: on a 120 Hz iPad the default target is 120, so the yellow/red boundary is exactly 60 FPS; a steady ~60 FPS jitters across it and the colour flips each tick. Added a 3% tolerance below each threshold. Test: jitter 59–61 FPS at a 120 Hz target stays one colour (failed before). Layout: .monospacedDigit keeps widths stable, so I left it alone. Not verified on device; reopen if the badge still flashes.

---

## 398: ImmersiveRuntime.renderFrame calls endSubmission on an invalidated frame when leaving immersive space

+++
status: closed
priority: high
kind: bug
labels: area:visionos
created: 2026-09-14T17:53:09Z
updated: 2026-09-30T16:18:01Z
closed: 2026-09-14T17:57:57Z
+++

Exiting an immersive space crashes with:

BUG IN CLIENT: cp_frame_end_submission() failed because the frame is not valid. Are failures from calls to cp_frame_query_drawables() or cp_frame_predict_timing() properly handled? (Namespace: 18, Code:2)

Cause: in ImmersiveRuntime.renderFrame() (MetalSprocketsUI/VisionOS/ImmersiveRuntime.swift), submission is ended unconditionally:

    frame.startSubmission()
    defer { frame.endSubmission() }
    guard let drawable = frame.queryDrawables().first else {
        return
    }

renderFrame awaits sleep(until: timing.optimalInputTime) before submitting. If the immersive space is dismissed during that await, the frame becomes invalid. After the sleep the state == .running guard can still pass (or race), startSubmission() runs, then queryDrawables().first returns empty because the frame is no longer valid. The guard returns, but the defer still calls endSubmission() on the invalid frame, producing the error above. The runtime message explicitly says an empty queryDrawables()/predictTiming() result must not lead to endSubmission().

Reproduction:
1. Enter an immersive space that runs the ImmersiveRuntime render loop.
2. Exit the immersive space.

Expected: the render loop tears down cleanly.
Actual: cp_frame_end_submission() fails on an invalid frame and the app crashes.

Proposed fix (per reporter): do not end submission when queryDrawables() is empty. Remove the unconditional defer and only call frame.endSubmission() on the path where a drawable is obtained, returning early (without ending submission) when it is empty.

Reported downstream in MetalSprocketsGaussianSplats #170. Device: Apple Vision Pro.

- `2026-09-14T17:57:57Z`: Fixed in renderFrame(): removed the unconditional defer { endSubmission() }; when queryDrawables() returns empty (frame invalidated during the pre-submit sleep, for example leaving the immersive space) we now return without ending submission, and call endSubmission() only after a successful encode. Verified on Apple Vision Pro: exiting immersive mode no longer crashes.

---

## 399: Metal 4 port lacks a reproducible rendering baseline

+++
status: closed
priority: high
kind: task
labels: area:metal4
created: 2026-09-29T16:32:55Z
updated: 2026-09-30T16:17:49Z
closed: 2026-09-29T16:45:22Z
+++

Parent: #256. RFC: [RFC 0002](RFCs/0002-metal-4.md), implementation step 1.

The port has no recorded baseline against which to judge output, test failures, or performance regressions.

Acceptance criteria:
- Record the revision, SDK, OS, device, xcb commands, test results, and known failures or skips.
- Identify and preserve representative golden images for render, compute, copy, MSAA/depth, and offscreen output where current coverage exists.
- Record representative CPU encoding time, GPU time, and memory measurements with reproducible workloads.
- Document missing coverage and hardware limitations separately from passing results.

This task establishes evidence for the existing backend. It does not change rendering behavior.

- `2026-09-29T16:36:50Z`: Started baseline collection in Documentation/Metal4-Baseline.md. On M5 Max/macOS 27/Xcode 27, xcb test reported 607 Swift Testing tests in 102 suites passing, with one explicit Swift Testing skip and two separate XCTest macro skips. The macOS example also builds. Preserved existing image references and recorded warnings and conditional coverage caveats. CPU encoding, GPU timing, and sustained memory measurements remain outstanding; this issue is not complete.
- `2026-09-29T16:45:22Z`: Completed the reproducible macOS correctness/performance baseline in Documentation/Metal4-Baseline.md. Added opt-in Metal4BaselineTests and three retained Release JSON runs. Each workload has 200 warm-up frames, 2,000 timing samples, and 10,000 sustained frames. Compute encoding median ~8.3 us; render ~13.5–14.1 us. GPU medians ~2.4–2.5 us and ~9.0–9.4 us. Metal allocations remained constant; RSS growth was at most 32 KiB per workload. Full suite and example build pass; platform and conditional-coverage limits are documented.

---

## 400: Metal 4 port lacks a complete API and feature migration inventory

+++
status: closed
priority: high
kind: task
labels: area:metal4, area:api
created: 2026-09-29T16:32:55Z
updated: 2026-09-30T16:17:57Z
closed: 2026-09-29T16:58:08Z
+++

Parent: #256. RFC: [RFC 0002](RFCs/0002-metal-4.md), implementation step 1.

The port needs an inventory of legacy Metal exposure and existing integrations before implementation can establish parity.

Acceptance criteria:
- Inventory public queue, command-buffer, encoder, descriptor, callback, and parameter APIs.
- Cover every rendering root, including Runner, Element.run(), UI, offscreen/video, and immersive rendering.
- Map MetalSupport and shader-tooling dependencies to supported Metal 4 paths or documented blockers.
- Account for mesh shaders, MetalFX, visible function tables, counters/timing, capture/logging, ARKit, CompositorServices, and render state.
- Record SDK/device evidence for uncertain capabilities, rather than assuming availability from OS minimums.
- Give each existing feature a proposed destination and verification requirement. Flag removals or deferrals for explicit approval.
- Reconcile relevant historical issues, including closed #320, against this checkout.

Deliverable: a repository migration inventory linked from the RFC. No existing feature can remain unassigned.

- `2026-09-29T16:58:09Z`: Completed Documentation/Metal4-Migration-Inventory.md against current sources, public API inventory, dependency checkouts, and Xcode 27 macOS/XROS SDK headers. Mapped public API families, every rendering root and existing integration, dependency destinations, and acceptance evidence. Corrected stale Draw/ComputeDispatch assumptions and reconciled closed #320. Retained API-validated SDK probes. Remaining shader compatibility and device-only compositor evidence are explicitly tracked in #403 and #404, not silently deferred or marked implemented.

---

## 401: Metal 4 submission ownership and callback contracts are unresolved

+++
status: closed
priority: high
kind: task
labels: area:metal4, area:api
created: 2026-09-29T16:32:55Z
updated: 2026-09-30T16:17:55Z
closed: 2026-09-29T16:58:09Z
+++

Parent: #256. RFC: [RFC 0002](RFCs/0002-metal-4.md), renderer context and submission sections.

Legacy completion modes and callbacks expose MTLCommandBuffer behavior that the proposed Metal 4 backend cannot preserve unchanged. Caller-owned submission can also outlive reusable recording storage.

Acceptance criteria:
- Document the contract replacing .none, commit, and commit-and-wait, including ownership before commit and after discard.
- Define allocator/resource retention, submission identifiers, timeout behavior, encoding failure, GPU failure, and shutdown.
- Define callback payloads, exactly-once delivery, isolation, ordering, and optional timing semantics.
- Distinguish CPU submission, GPU scheduling, and GPU completion. Do not present an event listener as equivalent to a legacy scheduled handler.
- Identify SDK mechanisms and targeted experiments needed to substantiate the contracts.
- Include a test matrix and public migration examples in the design decision.

Deliverable: a reviewed RFC decision before lifecycle implementation. This issue does not authorize the backend rewrite.

- `2026-09-29T16:58:09Z`: Recorded the submission design in Documentation/Metal4-Submission-Design.md and linked it from RFC 0002. Defines per-slot command buffers, recorded tokens, commit-order identifiers, commit/discard/wait semantics, ownership and quarantine rules, exactly-once terminal results, isolation/ordering, and a failure/race test matrix. Header evidence and retained success-path feedback/event probes support the decision. This completes the design task; backend implementation and its failure-path tests remain required.

---

## 402: Metal 4 copy-command and barrier placement APIs are unresolved

+++
status: closed
priority: high
kind: task
labels: area:metal4, area:api
created: 2026-09-29T16:32:55Z
updated: 2026-09-30T16:17:55Z
closed: 2026-09-29T16:58:09Z
+++

Parent: #256. RFC: [RFC 0002](RFCs/0002-metal-4.md), encoder and synchronization sections.

Removing BlitPass leaves no settled public contract for copy-only compute workloads. The proposed explicit synchronization API also lacks precise placement and scope in the element tree.

Acceptance criteria:
- Define a copy/fill command surface that does not require a compute pipeline.
- Define barriers within passes and dependencies between passes, including ordering under nested elements and modifiers.
- Define framework versus caller responsibilities for raw encoder closures and resource declarations.
- Cover compute-to-render, render-to-compute, copy-to-consumer, and between-submission dependencies.
- State how cross-queue dependencies differ from same-queue barriers.
- Substantiate the design with SDK references or focused experiments, migration examples, and a GPU-output test matrix.

Deliverable: a reviewed RFC decision before encoder integration. Automatic hazard inference remains outside scope.

- `2026-09-29T16:58:09Z`: Recorded the command design in Documentation/Metal4-Command-Design.md and linked it from RFC 0002. Defines pipeline-free ComputeCommand, explicit EncoderBarrier/QueueBarrier elements, pass-owned producer-barrier hooks, traversal semantics, resource responsibilities, cross-queue events, and GPU-output acceptance cases. Retained probe verifies fill/dispatch/copy, table rebinding, and all three barrier scopes with API Validation. This completes design preparation, not element implementation.

---

## 403: Raw shader injection has no settled Metal 4 migration contract

+++
status: closed
priority: high
kind: task
labels: area:metal4, area:api
depends: 400
created: 2026-09-29T16:57:47Z
updated: 2026-09-30T16:17:56Z
closed: 2026-09-29T17:48:07Z
+++

Parent: #256. Discovered by #400; see Documentation/Metal4-Migration-Inventory.md.

ShaderProtocol.function, init(_ function:), ShaderLoader, and visible/linked-function APIs expose MTLFunction. MTL4LibraryFunctionDescriptor requires a library and name, but an arbitrary MTLFunction does not expose its originating library. A name alone cannot reconstruct identity or specialization.

Acceptance criteria:
- Define migration contracts for directly injected functions, custom ShaderProtocol conformers, custom loaders, and visible functions.
- Account for library ownership, function constants, vertex-layout inference, device identity, and cache keys.
- Establish SDK evidence and retained compilation/output tests for the chosen path.
- Include before/after API examples and identify any source breaks requiring approval.
- Do not silently remove or ignore existing shader entry points.

This is a design gate before shader-wrapper migration, not a request to introduce a legacy rendering backend.

- `2026-09-29T17:05:28Z`: Investigation and retained SDK/output probe complete. Documentation/Metal4-Shader-Design.md proposes provenance-bearing ShaderFunction values, preserving library/name/source loading and read-only MTLFunction metadata access. Four Metal 4 compute pipelines verify two same-named libraries, two constant selections each, visible-function linkage/table binding, reflection and output under API Validation. Full suite and example build pass. Awaiting explicit approval for raw-function initializer/overload migration, removal of direct .function mutation, and custom ShaderProtocol/ShaderLoader conformance changes. No production API changed.
- `2026-09-29T17:48:07Z`: User approved the source-breaking shader migration. Implemented immutable ShaderFunction provenance, typed wrappers/read-only function access, custom loader contract, typed linked/visible functions, cache identities, strict declared-constant validation, explicit specialized export names, and unavailable raw-function migration diagnostics. Migrated callers and tests, retained GPU-free test coverage, added public-import custom loader/conformer output tests, and updated the Metal 4 probe to use production descriptors with two visible specializations. Final verification: 616 tests in 107 suites pass; API-validated Metal 4 probe passes; example builds; changed Swift files lint cleanly. Updated RFC, design/migration notes, release notes, and generated API snapshot. The rendering backend port remains separate.

---

## 404: Metal 4 immersive presentation ordering lacks device verification

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4, area:visionos
depends: 400
created: 2026-09-29T16:57:47Z
updated: 2026-09-30T16:18:02Z
closed: 2026-09-29T23:53:17Z
+++

Parent: #256. Discovered by #400; see Documentation/Metal4-Migration-Inventory.md.

The installed CompositorServices headers expose a compositor-owned Metal 4 queue and no-buffer addRenderContext/encodePresent APIs. The presentation header includes both a commit-before-present note and inherited legacy wording. CP_MTL4_AVAILABLE excludes the simulator, so a simulator run cannot settle presentation correctness.

Acceptance criteria:
- Resolve the presentation sequence using current Apple guidance and a supported-device experiment.
- Record OS/SDK/device and the Metal 4 configuration, queue, render-context, end-encoding, and presentation sequence.
- Verify stereo output, drawable timing, retention, and failure/teardown behavior.
- Document the proven sequence for ImmersiveRuntime integration and retain an appropriate regression or device-verification procedure.

No visionOS hardware execution was performed during the macOS preparation work. This gate does not authorize removing immersive rendering.

\- `2026-09-29T18:01:16Z`: Included under phase tracker #408 (umbrella #256). Product integration is separately tracked by #434, which depends on this issue.

Checkpoint:
- Completed: header inspection recorded in Documentation/Metal4-Migration-Inventory.md.
- Remaining: current Apple guidance, supported-device sequencing experiment, stereo/timing/lifetime verification, and retained procedure.
- Last validation: no visionOS device execution; macOS probes are not compositor evidence.
- Blockers: authorized supported-visionOS-device access must be established; do not invent simulator parity.
- Next action: inspect current Apple presentation guidance and identify an available supported device before the experiment.

Verification: build the focused experiment through xcb for visionOS; record the exact SDK/OS/device and authorized device-run results.

- `2026-09-29T22:16:18Z`: Blocked (autonomous run): needs an authorized experiment on the paired Apple Vision Pro. The user has deferred device testing. Simulator/macOS cannot establish compositor presentation parity. Unblocker: permission to build/install/launch the presentation experiment on the Vision Pro.
- `2026-09-29T23:53:17Z`: Settled on device (Apple Vision Pro, example app, user-run after the #425 cutover). Working Metal 4 sequence: record into the LayerRenderer.commandQueue context; drawable.addRenderContext() after setting the device anchor; the compositor's renderContext.endEncoding(commandEncoder:) is REQUIRED (skipping it gives 'cannot present drawable ... render context that's still encoding') and, undocumented, leaves our MTL4 command buffer ended, so the framework must not end it again; then commit to the layer queue; then drawable.encodePresent(). Commit-before-present works. Frames without a device anchor are dropped by the compositor ('Presenting a drawable without a device anchor'); seen only while world tracking is not running.

---

## 405: Metal 4 submission foundation is incomplete

+++
status: closed
priority: high
kind: feature
labels: tracking, has-subtasks, effort:l, area:metal4
depends: 410, 411, 412, 413, 414
created: 2026-09-29T17:54:14Z
updated: 2026-09-30T16:17:50Z
closed: 2026-09-29T19:13:14Z
+++

Part of #256. Phase tracker for renderer context, recorded-submission ownership, completion/error delivery, residency, and scratch storage.

Contract: Documentation/Metal4-Submission-Design.md and RFCs/0002-metal-4.md. This tracker is complete only when every child issue is complete. Internal coexistence during development is staging, not a supported dual backend.

Checkpoint: Not started. Shader provenance is already implemented in #403. No Metal 4 renderer lifecycle exists in production. Child issues own implementation and validation evidence.

- `2026-09-29T18:01:15Z`: Children, in dependency order: #410 context/slots; #411 recorded tokens; #412 completion/errors; #413 residency/retirement; #414 scratch values. Resume at #410. Each child owns its acceptance evidence and checkpoint.
- `2026-09-29T18:22:21Z`: Checkpoint: #410 internal context/allocator slots is complete in the working copy and validated on macOS plus iOS/visionOS builds. Remaining children: #411–#414. Next action: #411 recorded-submission tokens, retaining the context/lease until discard or terminal GPU retirement. No public renderer cutover occurred.
- `2026-09-29T18:59:31Z`: Checkpoint: #411 recorded-submission ownership complete in working copy (uncommitted with this batch). Metal4SubmissionCompletion already coordinates event+feedback and retains failed work; #412 adds the public completion/error/timeout/callback contract and shutdown. Remaining: #412-#414.
- `2026-09-29T19:08:12Z`: Checkpoint: #411 and #412 complete. Submission foundation now has tokens, commit-order identifiers, ordered exactly-once terminal delivery, timeout/fault/quarantine, and drain. Remaining children: #413 residency/retirement, #414 scratch storage.
- `2026-09-29T19:11:02Z`: Checkpoint: #410-#413 complete. Remaining: #414 scratch storage.
- `2026-09-29T19:13:14Z`: All children #410-#414 complete. Submission foundation phase done.

---

## 406: Metal 4 internal offscreen proof is incomplete

+++
status: closed
priority: high
kind: feature
labels: tracking, has-subtasks, effort:l, area:metal4
depends: 415, 416, 417, 418, 419
created: 2026-09-29T17:54:14Z
updated: 2026-09-30T16:17:50Z
closed: 2026-09-29T19:30:26Z
+++

Part of #256. Phase tracker for compiler/cache integration, argument bindings, encoders, barriers, and a complete compute-to-render-to-readback proof.

References: RFCs/0002-metal-4.md; Documentation/Metal4-Migration-Inventory.md; Documentation/Metal4-Command-Design.md.

Acceptance: All children complete, with verified GPU output over repeated submissions and no Metal API Validation errors. SDK probes alone do not satisfy this gate.

Checkpoint: Not started. Existing probes validate API viability but do not run a Metal 4 element graph. Child issues own implementation and validation evidence.

- `2026-09-29T18:01:15Z`: Children: #415 compiler/cache (after #410); #416 argument/indexed bindings (after scratch/compiler); #417 encoders/copy (after lifecycle/compiler); #418 barrier elements; #419 integrated GPU-output proof. #419 is the phase exit gate, not the raw SDK probes.
- `2026-09-29T19:30:26Z`: All children #415-#419 complete; internal offscreen proof passed.

---

## 407: Metal 4 public APIs and rendering roots remain on the legacy backend

+++
status: closed
priority: high
kind: feature
labels: tracking, has-subtasks, effort:l, area:metal4
depends: 420, 421, 422, 423, 424, 425
created: 2026-09-29T17:54:14Z
updated: 2026-09-30T16:17:50Z
closed: 2026-09-30T00:06:31Z
+++

Part of #256. Phase tracker for deployment targets, core element/environment contracts, headless roots, RenderView, video output, and final public-backend cutover.

Reference: Documentation/Metal4-Migration-Inventory.md, public API and root tables.

Acceptance: Every supported public root uses the shared Metal 4 lifecycle with documented source breaks and preserved behavior. Candidate implementations can remain internal while feature parity is established; the final cutover depends on parity, so intermediate commits do not silently disable existing features.

Checkpoint: Not started. Only shader provenance changed so far. Package minimums and renderer APIs still use the legacy backend. Child issues own implementation and validation evidence.

- `2026-09-29T18:01:15Z`: Children: #420 deployment minimums; #421 core candidate API/environment contracts; #422 headless/offscreen roots; #423 RenderView; #424 video export; #425 coordinated public cutover. #420 is independently ready now. #425 waits for all feature-parity leaves, while candidate root work can proceed earlier to keep intermediate changes buildable.
- `2026-09-29T18:09:12Z`: Checkpoint update: #420 is complete in the working copy. Package and example deployment minimums are OS 26 on macOS/iOS/visionOS. macOS tests and macOS/generic iOS/generic visionOS example builds pass under Xcode 27 RC. The backend is unchanged. Remaining children #421–#425 depend on the internal renderer work; restart overall at #410. See #420 for exact commands and warnings.
- `2026-09-30T00:06:31Z`: All children closed: #421, #422, #423, #424, #425 (public cutover). Public roots and APIs run on Metal 4.

---

## 408: Metal 4 existing-feature parity is incomplete

+++
status: closed
priority: high
kind: feature
labels: tracking, has-subtasks, effort:l, area:metal4
depends: 404, 426, 427, 428, 429, 430, 431, 432, 433, 434
created: 2026-09-29T17:54:15Z
updated: 2026-09-30T16:17:50Z
closed: 2026-09-30T00:06:31Z
+++

Part of #256. Phase tracker for render state, mesh, visible functions, spatial/temporal MetalFX, counters/timing, diagnostics, ARKit/YCbCr, and immersive rendering.

Reference: Documentation/Metal4-Migration-Inventory.md. Existing #404 remains the device-only compositor presentation evidence gate.

Acceptance: Each existing feature has output or behavior evidence for its Metal 4 implementation. An unsupported feature requires explicit approval for any removal or deferral; it must not disappear behind a passing build or silent test skip.

Checkpoint: Not started. Current feature tests exercise the legacy renderer. Child issues own implementation and validation evidence.

- `2026-09-29T18:01:15Z`: Children: #426 render-state/MSAA; #427 object/mesh; #428 visible functions; #429 MetalFX spatial; #430 MetalFX temporal; #431 counters/timing; #432 capture/logging/debug groups; #433 ARKit/YCbCr; #434 immersive integration. Existing #404 supplies device-backed compositor sequencing and is reused, not duplicated. Dependencies target candidate root leaves, not the public-cutover gate.
- `2026-09-29T22:20:45Z`: Checkpoint: 7 of 10 children closed with Metal 4 output evidence: #426 render state/MSAA, #427 mesh, #428 visible functions, #429 MetalFX spatial, #430 temporal, #431 counters/timing, #432 capture/logging/debug. Remaining: #433 (synthetic parity done; needs an iOS AR device run), #404 and #434 (need Vision Pro runs). Device testing is deferred by the user. No feature was removed or deferred without approval. Documented behavior changes: fragment counter interval is absent; an unlinked visible-function table entry is an error; .capture() must wrap passes (see Metal4-Migration-Inventory.md and Metal4-Evidence/capture-macos.md). Close when #404/#433/#434 close.
- `2026-09-30T00:06:31Z`: All children closed with Metal 4 output or device evidence: #404, #426-#434.

---

## 409: Metal 4 release readiness is unverified

+++
status: closed
priority: high
kind: feature
labels: tracking, has-subtasks, effort:l, area:metal4
depends: 435, 436, 437, 438
created: 2026-09-29T17:54:15Z
updated: 2026-09-30T16:17:50Z
closed: 2026-09-30T00:53:47Z
+++

Part of #256. Phase tracker for platform/device verification, performance comparison, migration documentation/examples, and removal of the obsolete backend.

References: RFCs/0002-metal-4.md; Documentation/Metal4-Baseline.md.

Acceptance: All release-gate children complete. Every advertised integration has supported-device evidence or an explicitly approved disposition. No unexplained output, memory, or performance regression remains.

Checkpoint: Not started. Baseline measurements exist, but no integrated Metal 4 renderer has been verified. Child issues own final evidence and remaining blockers.

- `2026-09-29T18:01:16Z`: Children: #435 platform/device/CI evidence; #436 performance/memory comparison; #437 migration docs/examples/API snapshot; #438 final legacy/staging cleanup. First three follow public cutover; cleanup follows all three. Closing this tracker requires recorded evidence, not only implementation claims.
- `2026-09-30T00:50:34Z`: Remaining: #435 only (OS 26 devices and CI). #436/#437/#438 closed.
- `2026-09-30T00:53:47Z`: All children closed (#435 accepted by user with known gaps; CI in #443/#444).

---

## 410: Metal 4 renderer context and allocator slots are missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 401
created: 2026-09-29T17:55:12Z
updated: 2026-09-30T16:17:50Z
closed: 2026-09-29T18:22:20Z
+++

Part of #405 / #256.

Missing: a shared Metal 4 device/queue context with bounded recording slots. Current CommandBufferElement creates legacy buffers per workload.

Sources: Sources/MetalSprockets/Metal/CommandBufferElement.swift; Sources/MetalSprockets/Roots/FrameRenderer.swift. Contract: Documentation/Metal4-Submission-Design.md, renderer context and state transitions.

Acceptance:
- Context initialization checks Metal 4 support and injected-queue device identity with actionable errors.
- Slots own distinct command buffers and allocators; unused slots require no initial wait.
- Explicit retirement controls allocator reset. Exhaustion cannot overwrite active or recorded work.
- Encoding remains confined to one isolation domain; independent contexts have independent mutable state.
- Tests cover first acquisition, capacity, reuse after retirement, and rejection of unsafe reset. Keep the existing public renderer working.

Verification: xcb test --raw; xcb build --raw. Retain targeted slot-state tests and any hardware capability skips.

Checkpoint:
- Completed: none.
- Remaining: all acceptance criteria.
- Last validation: not run; issue creation only.
- Blockers: none; #401 design is complete.
- Next action: inspect the submission contract and introduce the smallest internal context/slot implementation with lifecycle tests.

\- `2026-09-29T18:22:20Z`: Implemented the internal context/slot substrate in Sources/MetalSprockets/Metal/Metal4Context.swift and Metal4SlotPool.swift. Contexts validate Metal 4/device identity, own distinct recording objects, and are deliberately not Sendable. Generation-checked leases prevent stale/foreign mutation; bounded slot states prevent overwriting recorded/in-flight work. Reset occurs only after a safely reusable slot is acquired. Retirement requires successful-feedback acknowledgment and queue completion.

Checkpoint:
- Completed: all #410 acceptance criteria. Tests are in Metal4ContextTests.swift and Metal4SlotPoolTests.swift; the submission design/RFC record the implementation boundary.
- Remaining: none for this substrate. Recorded tokens/native commit ownership are #411; callback/error/timeout/teardown coordination #412; residency/retained resource owners #413; scratch storage #414. The public renderer is unchanged.
- Last validation: 10 targeted tests in 2 suites pass with MTL_DEBUG_LAYER=1, including 12 real GPU fill/readback submissions; full suite passes 626 tests in 109 suites; macOS, generic iOS, and generic visionOS example builds succeed; all four new Swift files lint cleanly.
- Environment: M5 Max, macOS 27.0, Xcode 27 RC. Device-mismatch/unsupported branches use a GPU-free identity/capability validation seam. The native GPU loop is serial, not full overlapping-frame renderer evidence.
- Artifacts: /tmp/metalsprockets-context-validation.log, /tmp/metalsprockets-context-full-tests.log, /tmp/metalsprockets-context-build.log, /tmp/metalsprockets-context-ios.log, /tmp/metalsprockets-context-vision.log.
- Blockers: none.
- Next action: #411 recorded-submission token ownership. #415 compiler/cache integration is also dependency-ready. These changes remain uncommitted in the current working copy.

---

## 411: Metal 4 recorded-submission ownership is missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 410
created: 2026-09-29T17:55:13Z
updated: 2026-09-30T16:17:50Z
closed: 2026-09-29T18:59:30Z
+++

Part of #405 / #256.

Missing: ownership for encode-without-submit, one-shot commit, discard, and dropped tokens. Legacy completion .none lets callers hold raw command buffers without allocator ownership.

Sources: Metal/CommandBufferElement.swift; Roots/Runner.swift under Sources/MetalSprockets. Contract: Documentation/Metal4-Submission-Design.md.

Acceptance:
- A recorded token retains its slot, finalized commands, and resource owners until commit or discard.
- Duplicate commit, foreign-context use, and commit after discard produce typed errors.
- Dropping an unsubmitted token releases safely; dropping a submitted token does not cancel GPU work.
- Submission identifiers are assigned in commit order, including out-of-order token commits.
- Exhaustion by unsubmitted tokens is an error, not a wait for nonexistent GPU work.
- Encoding exceptions unwind active encoders without commit or event waits.

Verification: new token state-machine and unwind tests; xcb test --raw; xcb build --raw. Public API wiring belongs to #421/#425.

Checkpoint:
- Completed: none.
- Remaining: all acceptance criteria.
- Last validation: not run.
- Blockers: #410.
- Next action: exercise recorded/discarded/submitted transitions using the internal slot owner.

\- `2026-09-29T18:59:30Z`: Implemented recorded-submission ownership: Metal4RecordingScope, Metal4RecordedSubmission, Metal4Submission, Metal4SubmissionCompletion, and Metal4Context.record/commit/retireCompletedSubmissions.

Acceptance evidence:
- Recorded token retains its slot, command buffer/allocator, and resource owners until commit or discard; dropping an unsubmitted token releases the slot and owners (deinit discards).
- Duplicate commit, commit-after-discard, and foreign-context commit throw typed Metal4RecordedSubmission.Failure; discard is idempotent.
- Submitted work retains command buffer, allocator, and owners through completion via Metal4SubmissionCompletion even after the token and context are released; owner released only after feedback+event.
- Submission identifiers follow commit order, not recording order (out-of-order commit test asserts 1 then 2).
- Exhaustion by unsubmitted tokens throws capacityExceeded without waiting; new record() retires completed submissions first.
- Throwing compute/render encoding and nested-encoder attempts unwind the encoder, discard the recording, and leave the slot free with no event signal.

Checkpoint:
- Completed: all #411 acceptance criteria. Tests in Metal4RecordedSubmissionTests.swift (7 tests, incl. 2 real GPU submission cases and ownership-after-release).
- Remaining: none for tokens. Native commit currently coordinates event+feedback inside commit(); the completion object already models both arrival orders and holds failed work retained. Public policy/callback surface is #412; residency/registration #413; scratch #414.
- Last validation: 7 targeted tests pass with MTL_DEBUG_LAYER=1; full suite 633 tests in 110 suites; macOS/iOS/visionOS example builds succeed; changed Swift files lint clean.
- Environment: M5 Max, macOS 27, Xcode 27 RC. Serial GPU path.
- Blockers: none.
- Next action: #412 completion errors, timeout, and callback delivery contract on top of Metal4SubmissionCompletion.

---

## 412: Metal 4 completion errors and callback delivery are missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 411
created: 2026-09-29T17:55:13Z
updated: 2026-09-30T16:17:50Z
closed: 2026-09-29T19:08:12Z
+++

Part of #405 / #256.

Missing: package-owned submission results, shared-event/feedback coordination, exactly-once callback delivery, timeouts, and safe shutdown.

Sources: Metal/CommandBufferElement.swift; Roots/FrameRenderer.swift. Contract: Documentation/Metal4-Submission-Design.md, including its complete failure/race test matrix.

Acceptance:
- Commit notification is CPU-side and precedes the recording terminal callback; no legacy GPU-scheduled semantics are fabricated.
- Feedback error surfaces without waiting for an event that might never signal. Success retirement observes both feedback and event completion.
- Results carry recording/submission identifiers, outcome/error, and optional validated GPU timing.
- Both event/feedback arrival orders, duplicate/late notifications, canceled async waits, and callback reentrancy are tested using injectable sources.
- Timeout faults the context without unsafe allocator/resource release; late completion cannot notify twice.
- Document a finite configurable timeout default and verify shutdown/drain/quarantine behavior.
- Callback isolation and submission-order delivery match the design.

Verification: state-machine tests plus successful hardware feedback/event integration; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: none.
- Remaining: all acceptance criteria.
- Last validation: not run.
- Blockers: #411.
- Next action: introduce injectable event/feedback completion sources and test the two success arrival orders before failure cases.

\- `2026-09-29T19:08:12Z`: Implemented the completion/error/callback contract: Metal4SubmissionResult, Metal4SubmissionCompletion (reworked), Metal4ResultDelivery, and Metal4Context fault/timeout/awaitResult/drain/onSubmissionCommitted/onSubmissionTerminated.

Acceptance evidence:
- Commit notification is CPU-side, on the committing isolation, and precedes the terminal result (GPU test asserts order). Not a GPU-start signal; documented that it fires just before the infallible native commit.
- Feedback error resolves immediately without an event; success requires feedback+event in either order (parameterized unit test).
- Results carry recording/submission identifiers, label, outcome, and validated optional GPU timing (invalid/missing timestamps -> nil).
- Injectable triggers cover both arrival orders, duplicate/late notifications, canceled waits after AND before continuation registration, and reentrant handlers (completion and delivery).
- Timeout faults the context, rejects further recording, never releases quarantined resources, and late GPU completion cannot re-notify (unit + GPU gated-queue tests).
- Finite configurable default timeout: 5 s per context. drain() awaits all submitted work and retires successes; failed/timed-out work stays quarantined with resources.
- Terminal results delivered serially, exactly once, in submission order (out-of-order, reentrant, and 200-way concurrent stress tests; no overlapping handler execution).

Fixed during review: concurrent-waiter identifier race; early-cancellation hang; single-handler slot that let callers displace internal fault/delivery; awaitResult hopping the non-Sendable context off its isolation (now nonisolated(nonsending)).

Checkpoint:
- Completed: all #412 acceptance criteria.
- Remaining: none for this issue. Real GPU-fault path verified by injection only (permitted by the design). A never-resolving submission holds back later ordered results until an awaiting caller times it out (documented).
- Last validation: 26 targeted tests with MTL_DEBUG_LAYER=1, stable across 5 repeat runs; full suite 652 tests in 113 suites; macOS, generic iOS, generic visionOS builds succeed; changed Swift lint clean.
- Environment: M5 Max, macOS 27, Xcode 27 RC.
- Blockers: none.
- Next action: #413 residency/resource registration (scope already separates allocations from owners; add residency sets and shared-allocation retirement).

---

## 413: Metal 4 residency and resource retirement are missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 412
created: 2026-09-29T17:55:13Z
updated: 2026-09-30T16:17:50Z
closed: 2026-09-29T19:11:02Z
+++

Part of #405 / #256.

Missing: unified resource registration, residency commits, and lifetime accounting across recorded and in-flight submissions.

Sources: Core/Element+Extensions.swift; Metal/Parameters.swift; rendering roots under Sources/MetalSprockets. References: RFC residency section and Documentation/Metal4-Submission-Design.md.

Acceptance:
- Registration covers direct allocations, heaps/indirect allocations, attachments, external owners, and framework-owned storage.
- Residency membership and strong references are tracked separately and prepared before submission.
- Per-command-buffer residency is reapplied after each begin-recording boundary.
- Shared allocations remain resident until their final recorded/in-flight use ends. Transient allocations leave the set after safe retirement.
- Samplers and argument tables are retained appropriately but are not treated as MTLAllocation members.
- Tests cover duplicate registration, two overlapping owners, discard, timeout retention, external-owner lifetime, and bounded repeated-frame membership.

Verification: ownership tests and API-validated GPU readback with registered resources; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: none.
- Remaining: all acceptance criteria.
- Last validation: not run.
- Blockers: #412.
- Next action: define per-recording resource ownership and test shared-allocation retirement without relying on a permanent global residency set.

\- `2026-09-29T19:11:02Z`: Implemented Metal4ResidencyTracker plus context/scope/token wiring.

Acceptance evidence (Metal4ResidencyTests, 6 GPU-backed tests):
- Registration covers any MTLAllocation (buffers, textures, heaps) via retainAllocation; external owners via retain; external residency sets via useResidencySet. Indirectly referenced allocations must be declared explicitly (no closure inspection).
- Residency membership (tracker) and strong references (completion) are separate; set committed before submission.
- Per-command-buffer sets reapplied per recording (test applies an external set across two recordings; output verified).
- Shared allocations remain resident until the last recorded/in-flight use ends; duplicate registrations within a recording count once.
- Transient allocations leave the set after retirement; 40 fresh buffers across frames end with an empty set (bounded, not a permanent global set).
- Discard, dropped tokens, and timeout retention covered; timed-out allocations stay resident after late completion.
- Samplers/argument tables never inserted (type system); argument-table retention belongs to #416.

Checkpoint:
- Completed: all #413 criteria.
- Remaining: none. Framework-owned registration of attachments/parameters happens as those paths port (#416/#417/#422).
- Last validation: 42 Metal 4 lifecycle tests with MTL_DEBUG_LAYER=1; full suite 658 tests in 114 suites; macOS/iOS/visionOS builds succeed; lint clean.
- Blockers: none.
- Next action: #414 scratch value storage.

---

## 414: Metal 4 value-parameter scratch storage is missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 413
created: 2026-09-29T17:55:13Z
updated: 2026-09-30T16:17:51Z
closed: 2026-09-29T19:13:14Z
+++

Part of #405 / #256.

Missing: aligned, submission-safe storage for value parameters now supplied through GPU addresses rather than setBytes.

Sources: Metal/ParameterValue.swift; Metal/Parameters.swift. References: RFC argument-table/value storage section; Documentation/Metal4-Submission-Design.md.

Acceptance:
- Each recording slot owns aligned shared scratch storage and reuses it only after safe retirement.
- Growth retains previous backing buffers through completion, preserving already-issued GPU addresses.
- Initial and grown buffers are registered for residency and retained for their submissions.
- Value/array layout handling rejects unsupported nontrivial Swift representations rather than copying references as shader data.
- Tests cover alignment, zero/edge sizes, growth during a frame, distinct values across draws and frames, discard, and bounded reuse.

Verification: unit tests plus GPU reads from allocations made before and after growth; xcb test --raw; xcb build --raw. Binding scope integration belongs to #416.

Checkpoint:
- Completed: none.
- Remaining: all acceptance criteria.
- Last validation: not run.
- Blockers: #413.
- Next action: audit existing ParameterValue layouts and define the supported scratch allocation/layout contract.

\- `2026-09-29T19:13:14Z`: Implemented Metal4ScratchArena (per slot) with scope.scratch(_:) for values and arrays.

Acceptance evidence (Metal4ScratchStorageTests, 6 tests):
- Aligned shared storage (min 16 bytes, type/requested alignment honored; invalid/zero alignment and empty arrays rejected).
- Growth appends buffers; earlier addresses remain valid (40 allocations across growth, CPU-verified; oversized request gets a dedicated buffer).
- GPU reads every scratch value across growth for 6 frames via copies (API Validation), then drain leaves zero resident allocations.
- Used scratch buffers registered for residency and retained with the recording; discard releases residency; reset only on reusable slots.
- Reuse bounded by peak use (50 resets x 20 allocations -> <=3 buffers).
- Layout contract: BitwiseCopyable, rejecting references at compile time (replaces legacy _isPOD assertion for the new path).

Note: new tests were written with the implementation in one step; they were red by non-existence (APIs absent) rather than observed failing.

Checkpoint:
- Completed: all #414 criteria.
- Remaining: none. Binding through argument tables and nontrivial ParameterValue migration is #416.
- Last validation: 52 Metal 4 tests with MTL_DEBUG_LAYER=1; full suite 664 tests in 115 suites; macOS/iOS/visionOS builds; lint clean.
- Blockers: none.
- Next action: #415 compiler/cache integration.

---

## 415: Metal 4 compiler pipelines and cache integration are missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 410, 403
created: 2026-09-29T17:56:16Z
updated: 2026-09-30T16:17:51Z
closed: 2026-09-29T19:15:20Z
+++

Part of #406 / #256.

Missing: production compiler integration for ordinary render/compute pipelines. Shader provenance and descriptor probes are complete, but current pipelines still use legacy creation APIs.

Sources: Metal/RenderPipeline.swift; ComputePass.swift; ShaderFunction.swift; RenderAttachmentFormats.swift. References: Documentation/Metal4-Shader-Design.md and RFC pipeline section.

Acceptance:
- Internal render/compute pipelines compile through the context MTL4Compiler using provenance-bearing shader descriptors.
- Binding reflection is requested and retained as immutable pipeline metadata.
- Cache identity covers exact libraries/devices, constants/export names, linking, vertex layout, formats, sample count, and relevant descriptor state.
- Setup invalidation rebuilds changed pipelines while unchanged steady-state workloads do not compile.
- Tests cover same-name different libraries, changed constants/attachments, specialization, reflection, and cache reuse.
- Mesh and public descriptor cutover are tracked separately; no persistent archives are introduced.

Verification: compiler/reflection/cache tests and GPU output; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: #403 supplies ShaderFunction and a working descriptor factory, not pipeline integration.
- Remaining: all acceptance criteria.
- Last validation: no implementation validation for this issue.
- Blockers: #410.
- Next action: connect the context compiler to a minimal compute pipeline and retain its reflection/cache key.

\- `2026-09-29T19:15:20Z`: Implemented Metal4PipelineCache (context.pipelines) compiling render/compute pipelines via MTL4Compiler from ShaderFunction provenance, with immutable reflected bindings (Metal4PipelineBindings).

Acceptance evidence (Metal4PipelineCacheTests, 5 tests, API Validation):
- Compiles through the context compiler with provenance descriptors (library+name+constants+export name) and binding reflection retained per stage.
- Cache identity: exact library/device, constants, linked functions, color formats, depth/stencil formats, sample count, vertex layout (value-equal copies hit; mutated layouts miss), label.
- Unchanged configurations do not recompile (compilationCount); same-name different libraries and changed constants do not alias.
- Device mismatch rejected before compilation.
- GPU output: specialized compute pipeline + reflected slots + scratch value produce expected results.
- Legacy public rendering untouched; mesh pipelines (#427) and public descriptor cutover (#421/#425) remain separate; no archives.

Gap noted: depth/stencil formats key the cache but are not MTL4RenderPipelineDescriptor state; pass validation of them belongs to #426. Blend state is not yet configured (render-state parity #426).

Checkpoint: complete. Validation: full suite 669 tests in 116 suites; macOS/iOS/visionOS builds; lint clean. Next: #416 parameter tables.

---

## 416: Metal 4 parameter tables and indexed bindings are missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 414, 415
created: 2026-09-29T17:56:16Z
updated: 2026-09-30T16:17:51Z
closed: 2026-09-29T19:18:34Z
+++

Part of #406 / #256.

Missing: named-parameter resolution and scoped argument-table state on the Metal 4 path.

Sources: Metal/Parameters.swift; ParameterValue.swift; Reflection.swift; FunctionTypes.swift. References: RFC bindings section; Documentation/Metal4-Migration-Inventory.md, historical #320 reconciliation.

Acceptance:
- Reflection produces stage/kind/index maps and correctly sized sparse argument tables for vertex, fragment, and compute.
- Named buffer/offset, texture, sampler, scalar and array parameters preserve stage filtering and scope.
- Explicit indexed vertex-layout bindings do not depend on synthetic reflection names.
- Nil textures clear slots; siblings and repeated draws cannot inherit unrelated stale bindings.
- Resources use #413 registration and values use #414 scratch storage.
- Diagnostics distinguish missing bindings, kind/type/range errors, and optimized-out optional inputs.
- Tests verify slot assignment, sparse vertex streams, mixed stages, distinct per-draw values, and table mutation/rebinding behavior. Object/mesh integration follows in #427.

Verification: binding unit tests and numeric/image GPU readback; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: SDK table-rebinding probe exists; no element binding implementation exists.
- Remaining: all acceptance criteria.
- Last validation: not run for this issue.
- Blockers: #414 and #415.
- Next action: build immutable reflected binding metadata and test sparse/indexed slot sizing before mutable encoding.

\- `2026-09-29T19:18:34Z`: Implemented Metal4Parameters and per-stage table sizing in Metal4PipelineBindings.

Acceptance evidence (Metal4ArgumentBindingTests, 5 tests, API Validation; red first: APIs absent):
- Reflection yields stage/kind/index maps; tables sized from highest sparse slot per kind (buffer 0,3,5 -> 6; texture 4 -> 5).
- Named buffer+offset, texture, sampler, scalar value, and array parameters; per-stage filtering via FunctionTypes (empty = all stages, legacy semantics). GPU readback proves sparse compute slots; a rendered pixel proves same-named values bound to different vertex/fragment slots.
- Explicit indexed vertex-layout buffers (sparse layout indices 0 and 3) with no dependence on synthetic reflection names.
- Fresh zero-initialized tables per call: nil textures clear, siblings/repeated draws cannot inherit stale bindings (distinct tables asserted).
- Buffers/textures register via #413 residency; values use #414 scratch (one copy shared across stages); tables and samplers retained with the recording.
- Diagnostics: missingBinding, kindMismatch(expected), offsetOutOfRange, invalidVertexBufferIndex; optional inputs skip silently.

Notes: fresh tables per call trade some CPU cost for correctness; reuse/caching is a later optimization, not claimed. Object/mesh stages are #427; visible-function tables #428.

Checkpoint: complete. Validation: 62 Metal 4 tests with MTL_DEBUG_LAYER=1; full suite 674 tests; macOS/iOS/visionOS builds; lint clean. One six-line signature change used sed (disclosed). Next: #417 encoders.

---

## 417: Metal 4 render compute and copy encoding are missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 412, 413, 415
created: 2026-09-29T17:56:16Z
updated: 2026-09-30T16:17:51Z
closed: 2026-09-29T19:22:07Z
+++

Part of #406 / #256.

Missing: internal pass/command encoding on Metal 4, including pipeline-free copy commands.

Sources: Metal/RenderPass.swift; ComputePass.swift; Draw.swift; ComputeDispatch.swift; BlitPass.swift. Contract: Documentation/Metal4-Command-Design.md.

Acceptance:
- Render and compute pass scopes create/end Metal 4 encoders and unwind safely after thrown user work.
- Draw binds its pipeline before the encoder closure. Direct and indirect compute dispatch preserve grid/threadgroup/range checks.
- ComputeCommand supports fill and buffer/texture copy with no compute pipeline.
- Indexed draws and indirect dispatch use valid GPU addresses and byte ranges.
- Nested active passes and commands outside valid scopes are configuration errors.
- Framework-owned copy resources are registered, and raw closures retain explicit registration responsibilities.
- Tests cover render/compute/copy output and error unwind without changing supported public roots yet.

Verification: internal encoding tests and GPU readback; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: raw SDK copy/dispatch probe only.
- Remaining: all acceptance criteria.
- Last validation: not run for this issue.
- Blockers: #412, #413, #415.
- Next action: integrate a copy-only internal compute pass with the submission context and verify buffer output.

\- `2026-09-29T19:22:07Z`: Implemented internal candidate encoder scopes (Metal4Encoding.swift): scope.withComputePass / withRenderPass, Metal4ComputePass (dispatch, command, fill, copy, intra-pass barrier), Metal4RenderPass (draw, drawIndexed), Metal4IndexBuffer, Metal4EncodingFailure.

Acceptance evidence (Metal4EncodingTests, 7 tests, API Validation; red first: APIs absent):
- Passes create/end Metal 4 encoders; thrown user work unwinds, discards, frees the slot, no event signal.
- draw binds pipeline + per-stage argument tables before the closure (closure only issues draws; red pixel verified).
- Direct non-uniform grid with automatic threadgroup size (Apple4 check preserved) and indirect dispatch via GPU address; indirect offset alignment/range validated (misaligned, too-short, negative rejected).
- Pipeline-free ComputeCommand-equivalent: fill + copy with no pipeline, output verified; fill/copy ranges validated.
- Indexed draws use GPU address + byte length (uint16 with byte offset, green pixel verified); index count/alignment/range validated.
- Nested passes -> nestedEncoder; escaped pass objects -> passEnded after the closure.
- Framework-owned resources registered: attachments (color/resolve/depth/stencil), copy/fill buffers, indirect and index buffers. Raw command closures still require explicit registration (documented).
- Public roots untouched; element wiring is #421.

Checkpoint: complete. Validation: 69 Metal 4 tests with MTL_DEBUG_LAYER=1; full suite 681 tests; macOS/iOS/visionOS builds; lint clean. Next: #418 barrier elements.

---

## 418: Metal 4 barrier elements lack traversal and GPU-ordering semantics

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 417, 402
created: 2026-09-29T17:56:16Z
updated: 2026-09-30T16:17:51Z
closed: 2026-09-29T19:25:59Z
+++

Part of #406 / #256.

Missing: element-level EncoderBarrier, QueueBarrier, and pass-exit producer barriers with the approved scope semantics.

Sources: Core/System+Process.swift; Metal/RenderPass.swift; ComputePass.swift; WorkloadModifier.swift. Contract: Documentation/Metal4-Command-Design.md and its full acceptance matrix.

Acceptance:
- EncoderBarrier emits at its intra-pass traversal position; QueueBarrier emits the consumer form against prior same-queue encoders.
- The pass-specific producer hook runs after children but before endEncoding, not in an outer modifier after the encoder ends.
- Wrong placement, empty/invalid stages, and nested active passes produce clear errors.
- Device visibility is the resource-dependency default; execution-only and resource-alias visibility remain explicit.
- Group, ForEach, conditionals, workload disabling, and setup reuse preserve barrier emission semantics.
- Tests cover fill-to-dispatch, dispatch-to-copy, compute/render dependencies, separate same-queue commits, and explicit cross-queue events.

Verification: traversal assertions plus API-validated numeric/image tests; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: #402 design and raw SDK scope probes.
- Remaining: all element-level acceptance criteria.
- Last validation: not run for this issue.
- Blockers: #417.
- Next action: assert exact internal encoder call order for each barrier scope, then verify dependent GPU output.

\- `2026-09-29T19:25:59Z`: Implemented barrier semantics: EncoderBarrier and QueueBarrier workload elements (Metal4BarrierElements.swift), candidate metal4ComputePass/metal4RenderPass environment entries, pass-level encoderBarrier/queueBarrier/producer-barrier operations with per-encoder stage validation, ordered operation logs, and context signalEvent/waitForEvent for explicit cross-queue dependencies.

Acceptance evidence (Metal4BarrierTests, 7 tests, API Validation, stable x3; red first: APIs absent):
- Exact traversal order through Group, ForEach (per iteration), workloadEnabled(false) subtrees (no commands, no barriers), and reused nodes on a second frame.
- Conditional content emits only the active branch barrier.
- Barriers outside an active pass throw configuration errors; empty/invalid stage masks rejected per encoder kind; queue-barrier after-stages may name other encoder kinds.
- Producer barrier emitted after all pass content and before endEncoding (log proves last position).
- GPU visibility: same-queue producer barrier + consumer queue barrier across separate submissions (two values); explicit cross-queue event with the consumer committed first; compute fill -> render fragment read via QueueBarrier (white pixel).
- Device visibility is the default; execution-only/resourceAlias remain explicit parameters.

Handoff (not claimed here): the public pass-element modifier `.barrierAfterPass` needs Metal 4 pass elements, which #421 creates; the scope-level producer hook it will call is implemented and tested. Aliasing-specific visibility is not separately tested. No negative missing-barrier test (undefined behavior cannot prove safety, per design).

Checkpoint: complete. Validation: 76 Metal 4 tests with MTL_DEBUG_LAYER=1; full suite 688; macOS/iOS/visionOS builds; lint clean. Next: #419 integrated proof.

---

## 419: Metal 4 element graph has no integrated offscreen readback proof

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 416, 417, 418
created: 2026-09-29T17:56:17Z
updated: 2026-09-30T16:17:51Z
closed: 2026-09-29T19:30:25Z
+++

Part of #406 / #256. This is the vertical-slice exit gate, not another raw SDK demonstration.

Missing: a complete internal Metal 4 element workload combining compilation, parameters, submission ownership, residency, barriers, rendering, and readback.

References: RFC implementation step 2; Documentation/Metal4-Baseline.md; Metal4BaselineTests and Metal4SDKProbeTests in Tests/MetalSprocketsTests.

Acceptance:
- A compute-generated texture feeds a render pass and an offscreen readback with exact numeric checks and a retained image reference/tolerance.
- More submissions than available slots succeed with changing per-frame/per-draw inputs and no stale output.
- Scratch growth, shared resources, setup reuse, and transient resource retirement are exercised together.
- Injected encoding/completion failures do not commit partial frames or recycle unsafe storage.
- A sustained run records allocator/residency/memory behavior and produces no Metal API Validation errors.
- Existing legacy tests remain green; a passing core-only suite is insufficient.

Verification: xcb test --raw with targeted GPU tests under MTL_DEBUG_LAYER=1; xcb build --raw. Record commands, OS/SDK/device, images/readbacks, and memory evidence in the issue checkpoint.

Checkpoint:
- Completed: none.
- Remaining: all acceptance criteria.
- Last validation: not run.
- Blockers: #416, #417, #418.
- Next action: compose the internal compute-to-render scene once the individual encoders and bindings pass.

\- `2026-09-29T19:30:25Z`: Integrated offscreen exit gate passed (Metal4IntegratedProofTests, 4 tests, API Validation, stable x4). Uses internal candidate elements on System traversal: Metal4ComputePassElement, Metal4RenderPassElement, Metal4DispatchElement, Metal4DrawElement, plus QueueBarrier; scope begin/end/abandon pass APIs let passes span child traversal, and workloadExit unwinding ends encoders before discard.

Evidence (M5 Max, macOS 27, Xcode 27 RC):
- Compute->barrier->render->readback: 12 overlapping frames (> 3 slots), every pixel of every frame verified with changing per-frame values; no stale output.
- Scratch growth each frame (3000-word array > 4 KiB initial), setup/node reuse across frames with one System, shared per-slot resources.
- Retained output: Golden Images/Metal4IntegratedProof.png (frame 200, inspected and verified per pixel before acceptance).
- Injected mid-graph encoding failure: no commit, slot freed, no fault, same System recovers with correct output.
- Injected completion timeout: context faults, new recording rejected, storage stays quarantined after late completion.
- Sustained 300 frames: peak 8-12 resident allocations, RSS change -114 KiB..-32 KiB; drain leaves zero resident.
- No Metal API Validation errors.

Checkpoint: complete. Validation: 80 Metal 4 tests with MTL_DEBUG_LAYER=1; full suite 692; macOS/iOS/visionOS builds; lint clean. Phase #406 complete. Next: #421 core element/descriptor contracts (candidate elements here are the starting point).

---

## 420: Package and examples still declare pre-Metal-4 deployment minimums

+++
status: closed
priority: high
kind: task
labels: subtask, effort:s, area:metal4
depends: 399
created: 2026-09-29T17:57:28Z
updated: 2026-09-30T16:17:51Z
closed: 2026-09-29T18:08:40Z
+++

Part of #407 / #256.

Missing: the agreed iOS 26, macOS 26, and visionOS 26 minimums in package/example configuration. The pre-port baseline is already recorded.

Sources: Package.swift; Example project configuration and CI platform settings. Reference: RFC platform policy.

Acceptance:
- Package and supported example targets consistently declare the agreed OS 26 minimums.
- SDK selection is documented separately from deployment minimums; an OS 27 host is not claimed as OS 26 runtime evidence.
- Availability guards that still protect optional/platform-specific APIs remain correct; do not remove them blindly.
- Build macOS, generic iOS, and generic visionOS destinations supported by the project; record unavailable toolchain/device limitations explicitly.
- Package tests and macOS example build pass. No renderer cutover or optional feature removal is bundled here.

Verification: xcb test --raw; xcb build --raw; xcb build --destination ios; xcb build --destination vision (select the appropriate supported scheme if required).

Checkpoint:
- Completed: none; minimums remain iOS 18/macOS 15/visionOS 26.
- Remaining: all acceptance criteria.
- Last validation: baseline only, not this change.
- Blockers: none; #399 is complete.
- Next action: inventory deployment settings and apply the agreed OS 26 floor.

\- `2026-09-29T18:08:40Z`: Completed the agreed OS 26 floor. Package.swift now declares iOS 26/macOS 26/visionOS 26. Both Debug/Release example configurations already declared OS 26 and needed no edit. CI already uses macOS 26 with Xcode 26.4; SDK selection remains distinct from deployment targets. Updated README requirements, release notes, RFC status, and inventory wording. Optional/platform-specific availability guards were preserved.

Checkpoint:
- Completed: all deployment-configuration acceptance criteria.
- Remaining: none for this issue. Actual OS 26 device runtime and integrated Metal 4 parity remain #435 and other backend issues.
- Last validation: xcb test --raw: 616 tests in 107 suites pass; xcb build --raw: macOS example succeeds; xcb build --destination ios --raw: generic iOS succeeds; xcb build --destination vision --raw: generic visionOS succeeds. Package.swift lint is clean.
- Environment: M5 Max, macOS 27.0 build 26A428, Xcode 27.0 RC/SDK 27. This is build evidence, not an OS 26 runtime claim.
- Artifacts: /tmp/metalsprockets-os26-tests.log, /tmp/metalsprockets-os26-mac.log, /tmp/metalsprockets-os26-ios.log, /tmp/metalsprockets-os26-vision.log. Raw compiler logs may contain environment data; review before sharing.
- Blockers: none.
- Next action: #410 context/allocator slots. These deployment changes are uncommitted in the current working copy.

- `2026-09-29T18:09:12Z`: Validation correction: Package.swift lint is not completely clean; it reports seven pre-existing trailing-comma warnings on unchanged lines. The two changed deployment lines introduce no lint warning. Build logs also contain the known incomplete local experiment discovery/GoldenImage bundle warnings, skipped AppIntents metadata extraction, and iOS 26 deprecation warnings for ARKit interfaceOrientation and FrameTimingView UIScreen.main. All requested builds and tests succeeded. The iOS warnings are handed to the existing feature-port issues rather than silently folded into this deployment-only change.
- `2026-09-29T18:22:20Z`: Deployment-floor changes were committed as 8975c140 (Require OS 26 across supported platforms). The previous uncommitted checkpoint is superseded.

---

## 421: Metal 4 core element and descriptor contracts are not wired

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 419, 420
created: 2026-09-29T17:57:29Z
updated: 2026-09-30T16:17:51Z
closed: 2026-09-29T20:30:10Z
+++

Part of #407 / #256.

Missing: complete candidate Metal 4 core elements, environment propagation, descriptor modifiers, parameter scopes, and submission callbacks ready for public cutover.

Sources: Core/Element+Extensions.swift; Metal/UVEnvironmentValues+Implementation.swift; CommandBufferDescriptorModifier.swift; RenderPassDescriptorModifier.swift; RenderPipelineDescriptorTransformer.swift; Parameters.swift; Draw.swift; ComputeDispatch.swift. References: migration inventory public API table and both submission/command design documents.

Acceptance:
- Every core legacy type exposure has its specified replacement and an actionable migration diagnostic where source compatibility ends.
- Descriptor copies and environment inheritance preserve sibling isolation, setup invalidation, formats, labels, and user overrides.
- Direct/indirect dispatch, indexed bindings, ComputeCommand, barriers, resource declarations, and result callbacks compose in element trees.
- Package-owned submission policies and recorded tokens expose the approved ownership contract.
- Candidate APIs can be exercised without prematurely routing unsupported legacy integrations through them. Global public cutover is #425.
- Public-import API tests and internal graph tests cover the complete core inventory; omitted rows block completion.

Verification: xcb test --raw; xcb build --raw; compiler diagnostics/API diff review.

Checkpoint:
- Completed: shader input API migration #403 only.
- Remaining: all core GPU API/environment work.
- Last validation: not run for this issue.
- Blockers: #419 and #420.
- Next action: map each core inventory row to a candidate declaration/test before changing the default public path.

\- `2026-09-29T19:25:59Z`: Handoff from #418: expose the pass-exit producer barrier as a pass-element modifier (.barrierAfterPass) once Metal 4 pass elements exist; call withComputePass/withRenderPass(producerBarrier:). Pass elements must set metal4ComputePass/metal4RenderPass environment values for EncoderBarrier/QueueBarrier.
\- `2026-09-29T19:30:55Z`: Tried: reviewed acceptance against current sources and RFC. Punting on a design decision, not size: acceptance requires public-import tests of candidate Metal 4 core APIs before #425, while legacy features must stay public until #425 and the RFC keeps the same public names (RenderPass, Draw, ComputePass, ComputeDispatch, CommandBufferElement). A public candidate therefore needs either a temporary parallel public namespace or deferring public exposure to the in-place cutover. Unblocker: choose (A) keep candidates internal with @testable graph tests now and move public-import tests to #425, or (B) add a temporary public namespace (for example Metal4.RenderPass) removed at cutover. Everything downstream (#422-#425, #426-#434, #435-#438) depends on this. Checkpoint: no code changes; tree clean at 7642b40c.
\- `2026-09-29T20:25:53Z`: Decision (user): keep the Metal 4 candidate API internal until #425. #421 delivers internal core contracts with @testable element-graph tests. Public-import tests and legacy migration diagnostics (where source compatibility ends) move to #425, where public names switch in place. No temporary public namespace ships.
\- `2026-09-29T20:30:11Z`: Implemented internal candidate core contracts per the user decision (internal until #425): Metal4CoreElements.swift (Metal4RenderPipelineElement, Metal4ComputePipelineElement, Metal4Dispatch, Metal4Draw, Metal4ComputeCommand, metal4Parameter/metal4VertexBuffer/metal4RenderPassDescriptorModifier/metal4UseResources/onMetal4SubmissionTerminated modifiers, Metal4SubmissionPolicy, Metal4Context.run), render pass descriptor copy-at-update in Metal4RenderPassElement, recording-level terminal handlers.

Acceptance evidence (Metal4CoreContractTests, 8 @testable graph tests, API Validation; red first):
- Pipelines compile in setup against the pass formats; unchanged frames reuse (compilationCount 1 over 3 frames); a format change recompiles once.
- Parameter scopes: inner overrides outer, siblings isolated (GPU values verified).
- Descriptor modifiers mutate only a private copy; siblings and the caller descriptor are untouched (pixel + descriptor checks).
- Direct and indirect dispatch, indexed vertex buffers (layout indices 0 and 5), ComputeCommand, EncoderBarrier, pass producer barrier, resource declarations, and result callbacks compose in trees with verified output.
- Policies: commit / commitAndWait; recorded tokens via record(_:system:). Commit notification precedes tree terminal callback.
- Diagnostics: missing context, misplaced dispatch/pipeline, with hints; failed records free their slots.

Moved per decision: public-import tests and legacy migration diagnostics -> #425. The #418 handoff is satisfied by the pass elements producerBarrier parameter (public .barrierAfterPass spelling decided at #425).
Gaps recorded: discarded or encoding-failed recordings do not invoke tree terminal callbacks (they throw synchronously / are caller-discarded); pipeline labels are passed through but not asserted.

Checkpoint: complete. Validation: 88 Metal 4 tests with MTL_DEBUG_LAYER=1; full suite 700 tests; macOS/iOS/visionOS builds; lint clean. Next: #422 headless roots.

- `2026-09-29T20:34:47Z`: Post-close fix in #422: modifiers no longer snapshot inherited environment values (stale parameters on reused, skipped nodes). See #422.

---

## 422: Metal 4 headless roots and offscreen readback are not integrated

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 421
created: 2026-09-29T17:57:29Z
updated: 2026-09-30T16:17:52Z
closed: 2026-09-29T20:34:47Z
+++

Part of #407 / #256.

Missing: candidate Runner, Element.run(), and OffscreenRenderer integration with the shared Metal 4 context rather than separate lifecycle implementations.

Sources: Sources/MetalSprockets/Roots/Runner.swift; Element+Run.swift; FrameRenderer.swift; OffscreenRenderer.swift. References: migration inventory root table and submission design.

Acceptance:
- Repeated Runner calls retain tree/setup caches and use the same context; one-shot run preserves its convenience behavior.
- Queue injection validates device identity. Recording/commit-and-wait behavior follows token/result contracts.
- Offscreen color/depth outputs, custom textures, sizes, pixel formats, CPU readback, and optional GPU timing retain their documented behavior.
- No readback occurs before completion. Resize and attachment changes invalidate the necessary setup without leaking prior resources.
- Tests cover repeated runs, errors, output, teardown, and compatibility with the forthcoming parity features.
- Keep default public-path cutover coordinated through #425.

Verification: candidate root tests, numeric output and golden images; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: internal proof is a prerequisite, not a public-root implementation.
- Remaining: all acceptance criteria.
- Last validation: not run.
- Blockers: #421.
- Next action: connect the headless runner to the context and preserve existing repeated-run tests on the candidate path.

\- `2026-09-29T20:34:47Z`: Implemented candidate headless roots on the shared context (Roots/Metal4Runner.swift): Metal4Runner (one context + one System reused; run commit-and-wait with immediate retirement; submit; runOnce for Element.run parity; injected MTL4 queue with device validation) and Metal4OffscreenRenderer (owned bgra8Unorm_srgb color + depth32Float attachments matching the legacy renderer, resize, Rendering with texture/cgImage/gpuTime).

Acceptance evidence (Metal4HeadlessRootTests, 6 tests, API Validation; red first):
- Golden parity: candidate render matches the existing legacy RedTriangle golden at 1600x1200.
- Repeated renders reuse tree and pipelines (1 compilation for 3 colors); pixels verified each render.
- Resize recreates attachments; earlier renderings keep their textures; zero-size rejected; no residual residency.
- Runner repeated compute runs, error mid-tree frees the slot and recovers, runOnce works.
- Injected queue used; device identity validated in context init.
- Teardown with outstanding gated work: runner deallocates, submitted resources survive until completion, output verified.
- Timing: gpuTime present and non-negative.

Bug found and fixed (affects #421 contracts): accumulating environment modifiers snapshotted inherited values into local writes, so a reused node skipped by selective rebuild pinned stale parameters across frames. Added MSEnvironmentValues.inheritedValue; parameter modifiers now rebuild from the parent during workload and descriptor modifiers during setup, every frame. Regression: runner offsets 10->20->40 through a pipeline-level modifier.

Legacy Runner/OffscreenRenderer/Element.run unchanged; public switch is #425.
Checkpoint: complete. Validation: 18 related tests with MTL_DEBUG_LAYER=1; full suite 706 tests; macOS/iOS/visionOS builds; lint clean. Next: #423 RenderView (interactive evidence needs permission) / #424 video.

---

## 423: RenderView lacks a Metal 4 drawable lifecycle

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 422
created: 2026-09-29T17:57:29Z
updated: 2026-09-30T16:17:52Z
closed: 2026-09-29T20:53:29Z
+++

Part of #407 / #256.

Missing: candidate RenderView/MTKView integration with Metal 4 command submission, drawable residency, presentation, and completion timing.

Sources: Sources/MetalSprocketsUI/RenderView.swift; RenderViewSupport.swift; PlatformAdaptorView.swift; MTKView+Environment.swift. References: RFC root model and SDK-backed migration inventory.

Acceptance:
- The view model owns the shared context and preserves lazy device/queue creation and host teardown behavior.
- Current Metal 4 pass descriptors, drawable wait/signal/present ordering, and drawable residency use the supported SDK path.
- Nil/unavailable drawables do not consume slots permanently or submit invalid work.
- Resize, scale, sample count, formats, pause/resume, overlays, and environment overrides preserve behavior.
- Completion timing reaches UI state on the proper isolation domain; removal with in-flight work retains GPU resources safely.
- Hosting tests and an on-device/window presentation verification record cover repeated frames. Any interactive app launch requires user permission.

Verification: xcb test --raw; xcb build --raw; record authorized manual UI verification separately. Final default-path switch is #425.

Checkpoint:
- Completed: none.
- Remaining: all acceptance criteria.
- Last validation: not run.
- Blockers: #422; interactive presentation evidence will require an authorized run.
- Next action: adapt the view model context/descriptor path and test nil-drawable and resize lifecycle cases.

\- `2026-09-29T20:38:42Z`: Progress (issue left OPEN). Implemented and verified: Metal4Presentable + Metal4DrawablePresentation; context commit ordering wait-for-drawable -> commit notification -> native commit -> signal drawable -> present -> completion event; per-recording layer residency sets; Metal4Runner.submitFrame; Metal4ViewRenderer (main-actor, non-blocking: skips nil drawables, paused views, and full slots without consuming slots; invalidates setup on drawable-size change; delivers GPU time on the main actor; teardown keeps in-flight frames alive).

Evidence (Metal4ViewRendererTests, 5 tests, API Validation, stable x3): exact presentation order; 5 frames into standalone CAMetalLayer drawables with per-frame pixels verified and 1 pipeline compilation; skip paths leave all slots free; resize invalidates setup once and renders at the new size; main-actor timing delivered deterministically; renderer released while a gated frame is in flight, which then completes. Full suite 711 tests (legacy hosting/MTKView tests unchanged and passing); macOS/iOS/visionOS builds; lint clean.

Remaining gaps blocking closure:
1. On-screen presentation evidence: standalone-layer presents are not displayed. Needs an authorized app/window run over repeated frames.
2. MTKView/RenderView wiring (currentMTL4RenderPassDescriptor, view-model ownership): candidates are internal to MetalSprockets, so MetalSprocketsUI cannot adopt them before #425 unless they become package-visible.
Next action: get permission for a window run; decide package visibility now vs wiring at #425.

\- `2026-09-29T20:53:29Z`: Completed with on-screen evidence (user approved package visibility and a window run).

Added: package visibility for the minimal candidate surface (Metal4ViewRenderer + Frame, Metal4Submission, Metal4SubmissionResult, Metal4RenderPipelineElement, Metal4Draw, metal4* modifiers) - nothing public; Metal4MTKViewDriver in MetalSprocketsUI (currentDrawable + currentMTL4RenderPassDescriptor + layer residencySet + drawableSize; missing drawable/descriptor -> skipped frame); in-package dev executable Metal4PresentationHarness (Experiments/Metal4PresentationHarness).

On-screen evidence (M5 Max, macOS 27, Xcode 27 RC, MTL_DEBUG_LAYER=1): real NSWindow with MTKView driven by the candidate path; 600/600 frames presented and completed, 0 skipped, 0 draw errors, 600 GPU timing samples (median 34.7 us), window visible and unoccluded, API Validation enabled with no errors. Retained: Documentation/Metal4-Evidence/presentation-macos.json and presentation-macos-window.png (captured on screen mid-run).

Also from the earlier commit: presentation ordering, layer residency, skip paths, resize invalidation, main-actor timing, teardown with in-flight frames (Metal4ViewRendererTests, 5 tests). Legacy RenderView/hosting tests unchanged and passing; RenderView itself switches at #425.

Checkpoint: complete. Validation: full suite 711 tests; macOS/iOS/visionOS builds; harness builds; lint clean for new files (7 pre-existing Package.swift trailing-comma warnings unchanged). iOS/visionOS on-screen presentation remains release evidence under #435.

---

## 424: Offscreen video export lacks Metal 4 completion integration

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 422
created: 2026-09-29T17:57:29Z
updated: 2026-09-30T16:17:52Z
closed: 2026-09-29T20:56:41Z
+++

Part of #407 / #256.

Missing: candidate OffscreenVideoRenderer integration with the shared Metal 4 lifecycle and completed-frame readback.

Sources: Sources/MetalSprockets/Roots/OffscreenVideoRenderer.swift; Tests/MetalSprocketsTests/OffscreenVideoRendererTests.swift. Reference: migration inventory and submission design.

Acceptance:
- Video rendering uses the shared context and tree driver, not a private legacy command-buffer lifecycle.
- Pixel-buffer copy/append observes GPU completion and preserves frame order, timestamps, configured format/size, and writer back-pressure.
- Encoding/writer failures and cancellation propagate without early resource release or duplicate frames.
- Finalization drains submitted work and writer output safely.
- Tests verify frame content, multi-frame export, back-pressure, error paths, and bounded memory during a sustained export.
- Preserve existing behavior until #425 coordinates the default path.

Verification: video tests with decoded frame assertions; xcb test --raw; xcb build --raw. Keep generated movies outside source control unless they are intentional fixtures.

Checkpoint:
- Completed: legacy back-pressure fix #321, not the Metal 4 port.
- Remaining: all acceptance criteria.
- Last validation: not run.
- Blockers: #422.
- Next action: replace candidate submission/readback ownership while retaining the existing writer back-pressure seam.

\- `2026-09-29T20:56:41Z`: Implemented candidate video export on the shared Metal 4 lifecycle: extracted the writer (AVAssetWriter setup, KVO back-pressure, BGRA pixel-buffer copy, timestamps, finalize, cancel) into internal VideoFrameWriter used by BOTH the legacy OffscreenVideoRenderer (public API unchanged) and the new Metal4OffscreenVideoRenderer (built on Metal4OffscreenRenderer; pixelFormat now configurable there).

Acceptance evidence (Metal4VideoExportTests, 5 tests, API Validation; red first):
- Completion before readback: each frame renders via commit-and-wait before the writer copies it.
- Decoded-frame assertions: all 12 frames decoded at exact timestamps (zero tolerance) with the expected dominant color per index; size and duration verified.
- Back-pressure seam awaited once per frame.
- Encoding failure appends nothing; later frames continue in order (decoded frames 0 and 1 verified).
- Cancellation removes the partial file and rejects further frames.
- Sustained 300 exported frames: zero lingering residency every frame, RSS growth under 32 MiB bound, 330 frames written; finalization succeeds.
- Legacy video tests (valid file, sequential runs, replace existing, back-pressure seam) still pass after the extraction.
- Non-BGRA formats rejected up front (writer reads BGRA bytes).

Checkpoint: complete. Validation: full suite 716 tests; macOS/iOS/visionOS builds; lint clean. Phase #407 remaining: #425 cutover (depends on parity #426-#434).

---

## 425: The public renderer cannot yet switch entirely to Metal 4

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 422, 423, 424, 426, 427, 428, 429, 430, 431, 432, 433, 434
created: 2026-09-29T17:57:29Z
updated: 2026-09-30T16:17:52Z
closed: 2026-09-29T22:53:45Z
+++

Part of #407 / #256. This is the coordinated public-backend cutover gate, after candidate root and feature implementations are verified.

Missing: default routing of all public elements/roots to Metal 4 without silently dropping existing integrations or leaving a supported dual backend.

Sources: package-wide Metal/public root APIs, examples, tests, and .public-api.yaml. References: all rows in Documentation/Metal4-Migration-Inventory.md.

Acceptance:
- Every root selects the shared Metal 4 backend and every existing advertised feature has a verified candidate path.
- Legacy queue/buffer/encoder/descriptor exposure, BlitPass/Blit migration, callbacks, and resource declarations match the approved contracts.
- Every removed/unavailable public entry point has an actionable migration and an explicit disposition. No unapproved feature loss is accepted.
- Existing tests are ported to equivalent assertions, not deleted to make the build green. Candidate-only tests become ordinary supported tests where appropriate.
- Examples build, the public API snapshot is reviewed, and the full package suite passes.
- Remaining unreachable legacy implementation cleanup belongs to #438.

Verification: xcb test --raw; xcb build --raw; API diff and inventory audit. Feature dependencies will be linked to this issue in this planning batch.

Checkpoint:
- Completed: none; production rendering remains legacy.
- Remaining: all acceptance criteria.
- Last validation: not run.
- Blockers: candidate root work and every feature-parity issue.
- Next action: wait for candidate parity, then audit the cutover diff against the inventory before routing public roots.

\- `2026-09-29T18:01:16Z`: Parity dependencies are now explicit: #426–#434. Preserve equivalent assertions when porting the opt-in baseline harness from legacy .none submission to the new token API. Keep archived legacy measurements unchanged. This gate is intentionally after feature candidates, preventing intermediate public cutover from disabling integrations.
\- `2026-09-29T20:25:53Z`: From #421 decision: #425 owns public-import API tests for the core inventory and actionable migration diagnostics for every legacy exposure, since public names switch in place at cutover.
\- `2026-09-29T20:30:11Z`: From #421: decide the public spelling for the pass producer barrier (.barrierAfterPass vs init parameter) and whether discarded/failed recordings report a terminal callback (currently they throw synchronously or are caller-discarded).
\- `2026-09-29T22:53:44Z`: Cutover implemented (user approved doing #425 before the #433/#434 device runs, with immersive ported unverified).

Public names now run on the Metal 4 engine; no dual backend:
- Roots: Runner (context per runner; sync run with deadline; record(_:) -> RecordedSubmission), Element.run, OffscreenRenderer, OffscreenVideoRenderer, RenderView (Metal 4 view model: currentMTL4RenderPassDescriptor, drawable wait/commit/signal/present, layer residency set, slot-aware frame skipping), visionOS ImmersiveRuntime (compositor MTL4 queue, addRenderContext(), Metal 4 endEncoding; present order UNVERIFIED, see #404/#434; simulator reports a capability error).
- Elements: RenderPass, RenderPipeline (base descriptor from renderPipelineDescriptorTransformer keys the compiler cache by value), MeshRenderPipeline, Draw (MTL4 encoder, pipeline/tables/state pre-bound), ComputePass/ComputePipeline/ComputeDispatch, new public ComputeCommand, EncoderBarrier, QueueBarrier, .barrierAfterPass (RFC spelling), parameters -> Metal 4 argument tables, new .vertexValues/.vertexBuffer, depth/stencil/bias, MSAA, descriptor modifiers, visible-function tables, useResource(s) (residency), debugGroup, capture, gpuCounters, MetalFX spatial/temporal, onCommandBufferCompleted(SubmissionResult), new onSubmissionCommitted, YCbCrBillboardRenderPass (retained owners).
- Public types SubmissionResult, Submission (value(), waitUntilCompleted(timeout:)), RecordedSubmission (commit/discard).
- Decision (#421 carry-over): discarded or encoding-failed recordings deliver NO terminal callback; the caller sees the thrown error or its own discard. Documented on onCommandBufferCompleted and tested.

Removed/unavailable with actionable diagnostics: BlitPass, Blit, CommandBufferElement, onCommandBufferScheduled, onCommandBufferCompleted(MTLCommandBuffer), commandBufferDescriptor(+Modifier, env), metalLoggingEnabled(_:), GPUCounterSampler, GPUCounterSampleIndex, legacy commandQueue/commandBuffer modifiers, MTLRenderPassDescriptor/MTLRenderPipelineDescriptor modifier overloads, computePassDescriptor, blitCommandEncoder, Runner(commandQueue: MTLCommandQueue).

Behavior changes (RELEASENOTES Unreleased): values must be BitwiseCopyable; unfiltered parameters bind all declaring stages; samplers need supportArgumentBuffers; capture must wrap passes; fragment counter interval nil; depthBias may wrap passes; size-less threadgroup dispatch uses one SIMD group (legacy 2D default failed API Validation for 1D kernels); unlinked VFT function is an error.

Tests: legacy tests ported to equivalent or stronger assertions (for example color parameter and stage filters now checked by GPU pixel output; RenderView root now asserts the completion result). Tests of removed internals were replaced by behavioral equivalents or covered by Metal4* suites: ParameterValue/collapse/encoder-dispatch internals, CommandBufferDescriptorTests (feature removed), legacy MetalFX tests (Metal4MetalFX* now drive the public MetalFXSpatial/Temporal). Baseline harness ported to the token API with the same per-frame checks; archived measurements untouched.

Validation: full suite 737 tests pass under API Validation (MTL_DEBUG_LAYER=1); macOS/iOS/visionOS builds of library + example app; lint clean; .public-api.yaml regenerated.

Not done here (tracked): device verification #433 (AR) / #404+#434 (Vision Pro); docs/tutorial/DocC migration #437; removing now-duplicate candidate internals (Metal4* names, Metal4ViewRenderer/MTKViewDriver/OffscreenRenderer, candidate tests using them) #438; on-screen RenderView run of the public path (no app launched; #435).

---

## 426: Metal 4 render-state and MSAA parity are unverified

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 422
created: 2026-09-29T17:59:20Z
updated: 2026-09-30T16:17:52Z
closed: 2026-09-29T21:04:31Z
+++

Part of #408 / #256.

Missing: complete render-state behavior on the candidate Metal 4 path.

Sources: Metal/MSAAModifier.swift; DepthStencilKey.swift; DepthBiasModifier.swift; RenderAttachmentFormats.swift; render pass/pipeline descriptor modifiers. Existing tests: GoldenRenderingTests, GoldenPipelineTests, MSAAEffectivenessTests, MSAATests, DepthBiasTests.

Acceptance:
- Clear/load/store, color/depth/stencil attachments, resolve targets, blend state, depth compare/write, depth bias, viewport/scissor, and sample counts retain their behavior.
- Transient MSAA/resolve/depth storage has valid usage, residency, and completion-bound lifetime.
- Resize, format changes, and second/subsequent frames invalidate setup correctly and do not reuse stale targets.
- Existing golden output and numerical edge-coverage assertions pass on the Metal 4 candidate; do not regenerate references to conceal differences.

Verification: targeted image/pixel tests under API Validation; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: legacy baseline and reference images only.
- Remaining: all acceptance criteria.
- Last validation: not run for Metal 4.
- Blockers: #422.
- Next action: run the render-state fixtures against the candidate offscreen root and address each missing state path.

\- `2026-09-29T21:04:31Z`: Implemented render-state/MSAA parity on the candidate path:
- Blending: Metal4Blending on the pipeline configuration, part of the pipeline cache key (MTL4 blendingState per color attachment).
- Depth/stencil: Metal4DepthState (depth compare/write + front/back stencil faces), with MTLDepthStencilState cached on Metal4Context; stencil reference value.
- Depth bias, viewport, scissor: per-draw modifiers written each workload pass. Every Metal4Draw sets depth-stencil, bias, stencil reference, viewport and scissor explicitly (defaults when unset), so state never leaks between sibling draws or frames.
- MSAA: Metal4OffscreenRenderer(sampleCount:) makes private multisample color and depth targets that resolve into the readable texture; unsupported counts throw. Attachment formats and sample count come from the pass descriptor, so resize/format changes rebuild pipelines.

Evidence (Metal4RenderStateTests, 9 tests, API Validation), all against the UNCHANGED legacy references:
- DepthNearOccludesFar (both draw orders), DepthBiasWinsCoplanar, CoplanarNoBias, ParameterColour, AliasedDiagonal, WarmTintDiagonal (function constants).
- NoAlphaBlend / WithAlphaBlend with the legacy exact (.none) comparison.
- Depth compare changed between frames on one renderer: CoplanarNoBias -> CoplanarDepthAlways -> CoplanarNoBias.
- 4x MSAA with resolve: partial-coverage edge pixels >10x the aliased render; a second frame with different geometry renders correctly.
- Viewport/scissor pixel checks prove no leak between sibling draws.
- Stencil on depth32Float_stencil8: replace-mark then equal-test masks the later draw exactly.
- rgba16Float target renders exact out-of-range values (2.5, -1, 0.25, 1).
- Mutation check: removing the depth-stencil/bias encoder calls fails 4 tests.

Checkpoint: complete. Validation: full suite 725 tests; macOS/iOS/visionOS builds; lint clean.

---

## 427: Metal 4 object and mesh pipeline parity is missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 426
created: 2026-09-29T17:59:20Z
updated: 2026-09-30T16:17:52Z
closed: 2026-09-29T21:09:57Z
+++

Part of #408 / #256.

Missing: object/mesh pipeline compilation, stage bindings, dispatch, and output parity on Metal 4.

Sources: Metal/MeshRenderPipeline.swift; FunctionTypes.swift; Parameters.swift; ShaderFunction.swift. Existing tests: MeshRenderPipelineTests.

Acceptance:
- Mesh descriptors compile through MTL4Compiler with object/mesh/fragment provenance, constants, linking, and reflection.
- Argument tables include object/mesh stages with correct sparse sizes, stage filters, value storage, and resource ownership.
- Dispatch dimensions/limits, depth state, attachments, labels, and setup-cache invalidation remain correct.
- Existing mesh golden images and repeated-frame tests pass on supported hardware; unsupported capability is an explicit skip.
- Device/library/constant changes cannot reuse an incompatible pipeline.

Verification: object/mesh GPU output and cache tests with API Validation; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: provenance-bearing ObjectShader/MeshShader wrappers from #403.
- Remaining: Metal 4 pipeline/binding/dispatch integration and output parity.
- Last validation: none for the new backend.
- Blockers: #426 and its headless-root prerequisites.
- Next action: compile the existing mesh fixture through the context compiler and inspect object/mesh reflection.

\- `2026-09-29T21:09:56Z`: Implemented mesh pipelines on the candidate path:
- Metal4PipelineCache.meshRenderPipeline compiles MTL4MeshRenderPipelineDescriptor through the context MTL4Compiler with object (optional)/mesh/fragment function descriptors (ShaderFunction provenance incl. constants), static linking per stage, blending, raster sample count, label and binding reflection. Keyed by full identity (functions, linked, attachment formats, samples, blending, label). Explicit capability error when the device lacks mesh shaders.
- RenderPipeline now carries its programmable stages; draw binding creates and sets argument tables for object/mesh/fragment (or vertex/fragment).
- Fixed a table-size bug found by API Validation: object/mesh reflection includes the payload binding, which was counted as a buffer slot (>31 bind count). Table sizes now count only real argument-table slot types.
- Metal4MeshRenderPipelineElement reads formats/sample count from the pass (shared Metal4PassFormats helper). Depth state/bias/viewport/scissor come from the #426 per-draw state.

Evidence (Metal4MeshPipelineTests, 6 tests, API Validation, suite gated by .enabled(if:) with explicit capability reason), against unchanged legacy references:
- MeshTriangle and MeshTriangleHalfScale (object-stage parameter reaches mesh), with and without depth compare; mesh-only pipeline; combined depth32Float_stencil8 pass.
- 5 repeated frames with changing parameters compile once; a new library with identical source recompiles; a 4x MSAA pass compiles its own pipeline.
- Reflection: stages [object, mesh, fragment], per-stage indices, sparse table sizes, label.
- Stage filter enforced (object-only argument filtered to fragment throws).
Constants identity is shared with #415 (ShaderFunction reference includes constants).

Checkpoint: complete. Validation: full suite 731 tests; macOS/iOS/visionOS builds; lint clean.

---

## 428: Metal 4 visible-function table integration is missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 422, 403
created: 2026-09-29T17:59:20Z
updated: 2026-09-30T16:17:52Z
closed: 2026-09-29T21:16:02Z
+++

Part of #408 / #256.

Missing: element-level visible-function linking/table binding and lifetime on the Metal 4 renderer. #403 implemented provenance and an SDK probe, not this integration.

Sources: Metal/VisibleFunctionTableModifier.swift; ShaderFunction.swift; RenderPipeline.swift; ComputePass.swift. Existing tests: VisibleFunctionTableTests and Metal4ShaderProbeTests.

Acceptance:
- Render vertex/fragment and compute visible functions link through Metal 4 descriptors and resolve handles from the correct pipeline/stage.
- Table resource-ID binding, residency, indirect referenced resources, and in-flight retention are correct.
- Named binding errors, unsupported/wrong/ambiguous stages, and conflicting export names produce diagnostics.
- Distinct named specializations in one pipeline resolve distinct handles and output.
- Existing red/blue golden images, compute output, setup invalidation, and repeated frames pass on the candidate path.

Verification: API-validated image/numeric tests; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: #403 input contract and raw SDK specialization/table proof.
- Remaining: all element integration and lifetime criteria.
- Last validation: no candidate-renderer validation.
- Blockers: #422.
- Next action: port compute table binding first using the retained shader probe as evidence, then render stages.

\- `2026-09-29T21:16:02Z`: Implemented visible-function tables on the candidate path:
- Metal4FunctionTables (per compiled render/compute pipeline) builds tables with MTLRenderPipelineState.makeVisibleFunctionTable(stage:)/compute equivalent and fills them from functionHandle(withName:[stage:]) by export name (specializedName ?? name). Tables are cached per (stage, function list) and reused across frames; they are immutable once filled.
- Metal4Parameters.setFunctionTable / .metal4VisibleFunctionTable(name, stage:, functions:) resolve the table's stage from reflection, bind table.gpuResourceID into that stage's argument table, and retain the table on the recording scope (residency + completion-bound lifetime).
- Render (vertex/fragment, also object/mesh stages) and compute pipeline elements accept linkedFunctions (static linking via MTL4 descriptors, from #415/#427).
- Diagnostics: functionTableNotFound (unknown name or explicit wrong stage), unsupportedFunctionTableStage (for example .kernel on a render pipeline), ambiguousFunctionTable (name in several stages; lists them), unlinkedFunction (table names a function not linked into the pipeline), and a configuration error when two different linked functions share an export name.
- Behavior change vs legacy: an unlinked table function is now an error instead of a logged warning plus an empty slot (#425 should note it in migration docs).

Evidence (Metal4FunctionTableTests, 5 tests, API Validation), against unchanged legacy references:
- VisibleFunctionTableRed (auto and explicit .fragment), VisibleFunctionTableBlue (auto .vertex).
- Compute plus_one / explicit .kernel / times_two across 4 frames on one runner: correct output; 1 pipeline compile, 2 tables built.
- Named specializations transformEleven/transformNineteen of one function resolve distinct handles in one table (numeric output); duplicate export names rejected.
- Table is in the residency set while in flight and removed after retirement; mutation check (dropping retention) fails this test. (GPU output alone did not catch it on unified memory.)
- All five diagnostics asserted by exact case.

Checkpoint: complete. Validation: full suite 736 tests; macOS/iOS/visionOS builds; lint clean.

---

## 429: MetalFX spatial scaling lacks Metal 4 renderer integration

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 422
created: 2026-09-29T17:59:20Z
updated: 2026-09-30T16:17:52Z
closed: 2026-09-29T21:21:28Z
+++

Part of #408 / #256.

Missing: existing spatial scaling through MTL4FXSpatialScaler on the candidate renderer.

Sources: Metal/MetalFXSpatial.swift; Tests/MetalSprocketsTests/MetalFXSpatialTests.swift. Evidence: migration inventory and Metal4SDKProbeTests capability query.

Acceptance:
- Creation uses the compiler-based Metal 4 scaler path and checks supportsMetal4FX rather than assuming OS availability implies device support.
- Input/output dimensions, formats, color processing, usage flags, and resize/recreation behavior preserve the current API contract.
- Scaler resource/fence requirements, external producer/consumer synchronization, residency, and lifetime are explicit.
- Tests verify actual scaled image output and multiple frames, plus capability and configuration errors. Capability queries alone do not complete this issue.
- No new MetalFX effects are added.

Verification: output tests under API Validation; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: SDK factory/encoding availability and M5 Max capability evidence only.
- Remaining: scaler integration and all output/lifetime criteria.
- Last validation: not run for this implementation.
- Blockers: #422.
- Next action: encode one existing spatial-scaling fixture through the candidate context and verify its output.

\- `2026-09-29T21:21:28Z`: Implemented Metal 4 MetalFX spatial scaling on the candidate path (Metal4MetalFXSpatial, Metal4MetalFX.swift):
- Creation: checks MTLFXSpatialScalerDescriptor.supportsMetal4FX(device) (capability error otherwise), then makeSpatialScaler(device:compiler:) with the context's MTL4Compiler. The scaler is cached per node and rebuilt only when formats or dimensions change (same contract as legacy MetalFXSpatial; no new options or effects).
- Validation: input/output usage must include the scaler's colorTextureUsage/outputTextureUsage; output must be private storage. Violations are configuration errors before encoding.
- Encoding: new Metal4RecordingScope.withCommandBuffer hands MetalFX the MTL4CommandBuffer between encoders.
- Synchronization (explicit): MetalFX's stage usage is undocumented, so small compute passes before and after it use queue barriers over all stages (wait for all earlier queue work; block all later queue work). The scaler fence is updated before and waited on after. Producers and consumers in the same submission need no extra barriers.
- Residency/lifetime: scaler and fence retained, input/output retained as allocations for every submission that uses them.

Evidence (Metal4MetalFXSpatialTests, 4 tests, API Validation):
- Produce (render) -> scale -> copy-to-shared in one submission, 3 frames on one runner: red/blue halves at 64->128, swapped colors next frame, then 64->256 resize; colors and seam position verified numerically.
- Mutation check: bypassing the sync passes makes these output tests fail on every run (3-10 failures per run); with sync they pass. So the barriers are needed and effective.
- 4 frames at sizes [64,64,96,96]: scaler built twice; textures resident while recorded and removed after retirement.
- bgra8Unorm input/output renders exact green.
- Shared-storage output and missing shaderRead input usage rejected.

Checkpoint: complete. Validation: full suite 740 tests; macOS/iOS/visionOS builds; lint clean.

---

## 430: MetalFX temporal history lacks Metal 4 renderer integration

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 422
created: 2026-09-29T17:59:20Z
updated: 2026-09-30T16:17:52Z
closed: 2026-09-29T21:28:07Z
+++

Part of #408 / #256.

Missing: existing temporal scaling through MTL4FXTemporalScaler with correct frame history and dependencies.

Sources: Metal/MetalFXTemporal.swift; Tests/MetalSprocketsTests/MetalFXTemporalTests.swift. Reference: migration inventory; temporal remains excluded on visionOS as in the existing product.

Acceptance:
- Supported platforms/devices use the compiler-based Metal 4 scaler and explicit capability diagnostics.
- Color, depth, motion, jitter, reset/history, exposure, dimensions/formats, and current optional inputs retain existing semantics.
- History/resource lifetime survives multiple in-flight submissions and resets correctly on resize or configuration changes.
- Required fences, visibility, residency, and producer/consumer dependencies are handled and documented.
- Multi-frame output tests distinguish valid accumulation from stale history and verify reset behavior.
- No frame interpolation or other new effects are introduced.

Verification: multi-frame numeric/image tests under API Validation; xcb test --raw; xcb build --raw.

Checkpoint:
- Completed: SDK availability and M5 Max capability evidence only.
- Remaining: all implementation/output criteria.
- Last validation: not run.
- Blockers: #422.
- Next action: map each existing scaler input and reset trigger to the Metal 4 counterpart before encoding a temporal sequence.

\- `2026-09-29T21:28:06Z`: Implemented Metal 4 MetalFX temporal scaling on the candidate path (Metal4MetalFXTemporal, Metal4MetalFX.swift), excluded on visionOS like the legacy type:
- Creation: supportsMetal4FX capability check with a specific error, then makeTemporalScaler(device:compiler:) on the context compiler. The scaler (which owns history) is cached per node and rebuilt only when any of the 4 formats or the input/output dimensions change.
- Inputs/semantics preserved: color, depth, motion, output, jitter, per-frame reset (same as legacy MetalFXTemporal; the legacy type sets no exposure/reactive/motion-scale/reversed-depth, so neither does this). A rebuilt scaler's first frame is encoded with reset=true, so a configuration change never mixes history.
- Validation: color/depth/motion/output usage vs scaler requirements; private output storage.
- Synchronization/residency/lifetime: the same explicit queue-barrier + fence wrapping as #429; scaler, fence and all four textures retained per submission.

Evidence (Metal4MetalFXTemporalTests, 5 tests, API Validation). Pixel-checkerboard input is used because uniform input makes the scaler's neighborhood clamp reject all history (probe showed reset and no-reset identical on flat color):
- Accumulation: identical input frames give changing output (history in use).
- Stale vs valid history: after a pattern switch without reset, the first frame differs from a history-free scaler by >0.05 mean, and the output then moves toward the new pattern over frames.
- Reset: the reset frame matches a brand-new scaler's first frame (<0.001); the next frame accumulates again (per-frame flag).
- Jitter changes output.
- Resize: scaler rebuilt (2 creations) and the first frame at the new size matches a fresh scaler (no stale history).
- In flight: three frames committed before any completes produce the same final output as sequential frames; output stays resident until retirement.
- Invalid textures (shared output, motion without shaderRead) rejected.
- Mutation checks: ignoring the user reset fails 1 test; bypassing the sync passes fails 3.

Checkpoint: complete. Validation: full suite 745 tests; macOS/iOS/visionOS builds; lint clean.

---

## 431: GPU counters and frame timing lack Metal 4 semantics

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 423
created: 2026-09-29T17:59:21Z
updated: 2026-09-30T16:17:53Z
closed: 2026-09-29T21:34:58Z
+++

Part of #408 / #256.

Missing: Metal 4 counter/timing integration without pretending legacy stage-sampling intervals map unchanged.

Sources: Metal/GPUCounters.swift; Roots/FrameRenderer.swift; MetalSprocketsUI/FrameTiming.swift and FrameTimingView.swift. Existing tests: GPUCountersTests, FrameTimingTrackerTests.

Acceptance:
- Submission feedback supplies validated optional GPU timing; unavailable timings remain absent, not zero.
- Counter heaps/timestamps and resolution follow supported Metal 4 APIs and device capabilities.
- Preserve existing sample semantics where supported; any changed interval/public API meaning is explicit in diagnostics and migration notes.
- Sampling/resolve allocations use the context resource lifecycle and synchronization.
- Tests cover valid intervals, absent/invalid timestamps, disabled instrumentation, thread-safe UI delivery, and unsupported capabilities with explicit skips.

Verification: supported-device counter tests plus timing/UI tests; xcb test --raw; xcb build --raw. Compare instrumentation overhead separately from baseline runs.

Checkpoint:
- Completed: completion design identifies feedback timings; no counter port exists.
- Remaining: all acceptance criteria.
- Last validation: not run for Metal 4 integration.
- Blockers: #423.
- Next action: map existing public counter intervals to SDK-supported measurements and record any semantic incompatibility before implementation.

\- `2026-09-29T18:09:12Z`: OS 26 floor validation (#420) surfaced FrameTimingView.swift use of UIScreen.main, deprecated in iOS 26. Account for contextual screen/trait access while preserving timing overlay behavior during this port. Generic iOS build succeeds with the warning.
\- `2026-09-29T21:34:57Z`: Implemented Metal 4 counters and frame-timing integration on the candidate path:
- Metal4TimestampSampler: MTL4CounterHeap (.timestamp, 3 entries), CPU-timeline resolveCounterRange after completion, tick conversion via device.queryTimestampFrequency(). Capability: requires Metal 4 family and a nonzero frequency (explicit deviceCababilityFailure otherwise).
- Interval mapping (explicit, recorded in Documentation/Metal4-Migration-Inventory.md):
  - Render: start = timestamp before the vertex stage begins (written before draws), vertex end / pass end = after all draws finish vertex / fragment. sample.vertex = start..vertexEnd.
  - sample.fragment is ALWAYS nil: Metal 4 has no start-of-fragment sample, so no interval is invented.
  - Compute: encoder start..end.
  - Zero (invalidated/unwritten) or reversed timestamps give nil intervals, never zero.
- .metal4GPUCounters(label:handler) samples the first render/compute pass beneath it (pass elements claim the request; later passes are ignored). Heaps are pooled: a lease returns the heap after the committed recording's terminal handler runs, or when a discarded recording drops its handlers (discard fires no callbacks, so the lease deinit is what prevents a leak; test caught this). Heaps are invalidated before reuse and retained for in-flight lifetime.
- Submission feedback timing (#412) remains optional (nil, never zero) and Metal4ViewRenderer delivers it on the main actor (#423). FrameTimingTracker tests are unchanged and passing.
- iOS UIScreen.main deprecation handled: FrameTimingView reads maximumFramesPerSecond from the foreground-active connected UIWindowScene's screen (fallback unchanged). iOS build has no deprecation warning.

Evidence (Metal4GPUCountersTests, 5 tests, API Validation, stable over 3 reruns):
- Render pass: one labeled sample, end>start, 0<duration<=submission GPU duration, vertex interval present and inside the pass, fragment nil.
- Compute pass: positive duration, no vertex/fragment.
- 4 sequential frames reuse one heap; two concurrently recorded submissions use two heaps; 6 distinct samples.
- Discarded recording: no sample and no heap leak (next frame reuses the same heap). Tree without a pass: nothing reported.
- interval(): zero/reversed -> nil; 1 ms of ticks -> 0.001 s.

Instrumentation overhead vs baseline is left to #436 (performance comparison), as the issue asks for a separate comparison.

Checkpoint: complete. Validation: full suite 750 tests; macOS/iOS/visionOS builds; lint clean.

---

## 432: Capture logging and debug groups lack Metal 4 parity

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 423
created: 2026-09-29T17:59:21Z
updated: 2026-09-30T16:17:53Z
closed: 2026-09-29T21:59:24Z
+++

Part of #408 / #256.

Missing: existing diagnostics and capture behavior on Metal 4 roots/encoders.

Sources: Metal/CaptureModifier.swift; DebugGroupModifier.swift; CommandBufferDescriptorModifier.swift; MetalSprocketsSupport/CommandBufferLogging.swift; RenderView capture integration. Existing tests: CaptureModifierTests, DebugGroupTests, LoggingGateTests.

Acceptance:
- Device/queue capture targets work with Metal 4 queues, output URLs, and root submission boundaries.
- Disabled/nested capture and thrown workloads balance capture/group scopes without stopping a capture owned elsewhere.
- Shader logging uses Metal 4 command-buffer options/logState and preserves logging gates/labels.
- Pass/command labels and debug groups remain visible in a representative trace.
- Tests cover lifecycle behavior; capture evidence verifies real output rather than only descriptor construction.

Verification: xcb test --raw; xcb build --raw; capture using the GPU-capture skill and inspect using the GPU-debug skill. Keep trace artifacts out of source control unless explicitly retained as fixtures.

Checkpoint:
- Completed: SDK Metal 4 capture factory and logging-option evidence only.
- Remaining: integration and trace verification.
- Last validation: not run.
- Blockers: #423.
- Next action: port queue capture ownership and debug-group unwind tests before taking a representative trace.

\- `2026-09-29T21:59:23Z`: Implemented capture/logging/debug diagnostics on the candidate path (Metal4Diagnostics.swift):
- Capture (.metal4Capture): device or queue target. For the queue target, the MTL4CommandQueue itself is the capture object. Output URL required for .gpuTraceDocument (configuration error). Disabled, unsupported-destination and already-capturing cases are no-ops that never stop a capture owned elsewhere. The capture boundary is the root submission: a session object stops the capture from the terminal handler after completion, or when a discarded/thrown recording drops it, so thrown workloads still end the capture.
- Behavior change: on Metal 4 .capture() must wrap whole passes; inside an open pass it is a configuration error (see finding 1). Legacy allowed this placement; #425 must handle it for roots that wrap content in their own pass (Metal4OffscreenRenderer does).
- Debug groups (.metal4DebugGroup): on the open render/compute encoder, else on the MTL4CommandBuffer around whole passes. Pops run during unwinding, so groups stay balanced.
- Labels: Metal4RenderPassElement/ComputePassElement(label:) set encoder labels; pipeline labels already flowed from #415.
- Shader logging: Metal4Context(shaderLogging:) installs an MTLLogState through MTL4CommandBufferOptions on every command buffer. The default follows the legacy process gate (SystemEnvironment.metalLoggingEnabled). The legacy per-subtree metalLoggingEnabled cannot map because a log state covers a whole command buffer (documented).

Evidence:
- Metal4DebugGroupTests (2), Metal4ShaderLoggingTests (1), Metal4CaptureTests (6 incl. 2 targets), API Validation. A shader os_log message reaches the handler; nested groups on command buffer, render and compute encoders pass validation; thrown workloads unwind and the next frame renders; the capture tests cover disabled, unsupported, inside-a-pass rejection, missing URL, capture owned elsewhere, and thrown workload.
- Real traces (MTL_CAPTURE_ENABLED=1) for both targets, inspected with gpudebug. They show the command-buffer group 'Captured frame' > encoder 'Captured pass' > encoder group 'Captured draw' > draw0 with pipeline 'Capture pipeline', and balanced pops. Details are in Documentation/Metal4-Evidence/capture-macos.md; the traces are not kept in source control.

Findings (Xcode 27 RC, recorded in the evidence doc):
1. Starting a capture while a render encoder is open, then drawing and stopping, SIGSEGVs in GPUTools (GTTraceDispatch_createArgumentTableStateMap during stopCapture). I bisected it with ~12 probes: draw state, reflection, stop thread/timing and pipeline age are not the trigger; encoder-open start is. I could not reproduce it in raw Metal, so I'm not sure what makes the framework path different; my guess is a GPUTools bug, but that is unverified.
2. A capture scope from makeCaptureScope(commandQueue:) for an MTL4CommandQueue crashes as captureObject (unrecognized selector traceStream).
3. Any MTLLogState in-process makes captures fail (legacy has the same interaction); the logging suite is disabled when MTL_CAPTURE_ENABLED=1.

Checkpoint: complete. Validation: full suite 759 tests; the capture-enabled run passes 9 tests; macOS/iOS/visionOS builds; lint clean.

---

## 433: ARKit textures and YCbCr rendering lack Metal 4 lifetime coverage

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 423
created: 2026-09-29T17:59:21Z
updated: 2026-09-30T16:17:53Z
closed: 2026-09-29T23:23:36Z
+++

Part of #408 / #256.

Missing: external camera texture ownership and YCbCr pipeline binding on the candidate Metal 4 path.

Sources: MetalSprocketsUI/iOS/ARKitSessionModifier.swift; YCbCrBillboardRenderPass.swift; MetalSprocketsUIShaders. Existing tests: YCbCrBillboardRenderPassTests.

Acceptance:
- CVPixelBuffer/CVMetalTexture owners remain alive through final GPU use, not merely until a new AR frame arrives.
- Y/CbCr texture bindings, sampler/constants, usage, residency, and producer/consumer synchronization are correct.
- Synthetic camera-plane fixtures verify color conversion and shader-loading/device behavior through the candidate renderer.
- Session start/stop, view teardown, and overlapping frames retain proper isolation and resource lifetime.
- An authorized supported-iOS-device run verifies actual AR session output; record permission/hardware blockers explicitly.

Verification: synthetic image/lifetime tests, xcb test --raw, xcb build --raw, xcb build --destination ios, and a recorded authorized AR device check.

Checkpoint:
- Completed: existing legacy fixtures only.
- Remaining: all Metal 4 integration and device criteria.
- Last validation: not run.
- Blockers: #423; authorized AR device verification required for closure.
- Next action: use synthetic YCbCr fixtures to validate bindings and retained external owners before a live camera session.

\- `2026-09-29T18:09:12Z`: OS 26 floor validation (#420) surfaced the existing ARKitSessionModifier.swift use of UIWindowScene.interfaceOrientation, deprecated in iOS 26. Account for the effectiveGeometry orientation API while preserving camera/display transform behavior during this feature port. Generic iOS build succeeds with the warning; runtime orientation correctness remains unverified.
\- `2026-09-29T22:07:01Z`: Progress (issue stays open; the authorized AR device run is still required):
- Metal4YCbCrBillboard (MetalSprocketsUI, package): the candidate of YCbCrBillboardRenderPass on the Metal 4 renderer. Vertex data goes through scratch storage (new Metal4Parameters.setVertexValues / .metal4VertexValues, the setVertexBytes counterpart). Y/CbCr textures and the sampler bind by name through argument tables; the sampler is cached per device with supportArgumentBuffers (required for resource-ID binding). Depth is .always with no write, as before. External owners are retained per submission via the new .metal4RetainOwners.
- ARFrameData.textureOwners (package): the CVMetalTextures behind the planes, so renderers keep them until GPU use ends, not only until the next AR frame replaces the modifier's @State.
- iOS deprecation: ARKitSessionModifier now reads orientation from UIWindowScene.effectiveGeometry.interfaceOrientation; the iOS build has no warning. Runtime orientation behavior is NOT verified (needs the device run).

Evidence (Metal4YCbCrBillboardTests, 4 tests, API Validation):
- Mandrill fixture: the candidate output matches the legacy billboard within 1/255 per channel.
- Known planes Y=0.5, Cb=0.5, Cr=0.75 give RGB (217,82,128) per the shader's BT.601 matrix.
- Camera-style planes from an IOSurface 420f CVPixelBuffer through CVMetalTextureCache convert correctly.
- Overlapping frames: two in-flight submissions with different planes keep separate output. Each frame's owners are released only after that submission's terminal event. Mutation check: dropping owner retention fails on every run.

Remaining for closure: an authorized AR session run on a supported iOS device (paired iPhone 17 Pro Max / iPad mini are available but not launched without permission). It should verify live camera output, orientation/display transform, session start/stop and view teardown.

Validation: full suite 763 tests; macOS/iOS/visionOS builds; lint clean.

- `2026-09-29T23:23:35Z`: Device evidence: the user ran the example app on a physical iPhone after the #425 cutover; AR mode (ARKit camera feed through YCbCrBillboardRenderPass on the Metal 4 path, cube on top) works. The report is a user observation; no captured logs or screenshots are retained. The synthetic parity, retained-owner lifetime and orientation work are in 3165464a; the public path is from 5b41cd92.

---

## 434: Immersive rendering lacks a Metal 4 compositor integration

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4, area:visionos
depends: 404, 426
created: 2026-09-29T17:59:21Z
updated: 2026-09-30T16:18:02Z
closed: 2026-09-29T23:53:17Z
+++

Part of #408 / #256. Existing #404 establishes the device-backed presentation sequence; this issue integrates that sequence into the product.

Sources: MetalSprocketsUI/VisionOS/ImmersiveRuntime.swift; ImmersiveRenderPass.swift; ImmersiveRenderContent.swift. References: migration inventory and #404 evidence.

Acceptance:
- Metal 4 compositor configuration and the compositor-provided queue feed the shared renderer context.
- Render-context creation, encoder finalization, drawable presentation, and frame timing follow the verified sequence, not contradictory inherited header wording.
- Layered/stereo views, viewports/amplification, stencil/depth, device anchors, and current immersive content behavior remain correct.
- Drawable/residency/external-owner lifetimes survive in-flight work, pauses, and teardown.
- Device tests show both views and frame progression without validation errors; simulator API absence is documented, not treated as equivalent execution coverage.
- No new immersion or hover-effect features are bundled.

Verification: xcb build --destination vision; relevant tests through xcb; supported-device stereo/presentation evidence. Do not claim parity from a simulator run.

Checkpoint:
- Completed: none; current ImmersiveRuntime uses a legacy queue/buffer path.
- Remaining: all acceptance criteria.
- Last validation: not run.
- Blockers: #404 device evidence and #426 render-state parity.
- Next action: use the verified #404 sequence to connect the compositor-owned queue to the candidate context.

- `2026-09-29T22:16:18Z`: Dependency-blocked: #404 has no device evidence yet (device testing deferred by the user). Not attempted.
- `2026-09-29T23:53:17Z`: Device-verified by the user on Apple Vision Pro: immersive cube renders correctly in both eyes (stereo amplification, reverse-Z depth), no clipping, no crashes, open/dismiss worked. Fixes made during the device run: pipeline-free RenderCommand for the compositor stencil mask (legacy used a pipeline-less Draw); stencil reference now per-draw via .stencilReferenceValue; compositor-ended command buffer tracked (markCommandBufferEndedByOwner) so endRecording/discard don't end it twice and nothing can encode after the immersive pass; Draw no longer forces full-texture viewport/scissor (clipped foveated/amplified targets), only sets them when asked or to undo an earlier override, with the rate map's logical size as default. Evidence is user observation, no captures retained. Not specifically exercised: progressive immersion style mask. Unrelated log noise: legacy _MTLCommandBuffer 'background execution not permitted' errors (not from our MTL4 path; origin unverified).

---

## 435: Metal 4 platform and device release evidence is missing

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 425
created: 2026-09-29T18:00:26Z
updated: 2026-09-30T16:17:53Z
closed: 2026-09-30T00:53:47Z
+++

Part of #409 / #256.

Missing: release-level evidence across supported macOS/iOS/visionOS hardware and the agreed OS 26 minimums.

Sources: Package.swift; Example targets; .github/workflows; platform test configuration. References: RFC verification requirements, #404/#434 immersive evidence, and the baseline coverage limitations.

Acceptance:
- Package/tests and examples build for supported destinations using documented SDKs and deployment targets.
- Supported-device runs cover presentation, core GPU output, and every advertised capability; OS 27 execution is not substituted for all OS 26 runtime evidence.
- API Validation and representative GPU captures show no unexplained lifetime/binding/synchronization errors.
- Capability-based skips are explicit, with a matrix identifying which device actually exercised each feature.
- CI configuration runs the appropriate macOS tests and iOS/platform build checks, with toolchain/plugin requirements documented.
- Existing unrelated baseline failures/skips are identified separately from port regressions.

Verification: xcb test --raw; xcb build for macOS, ios, and vision destinations; authorized device runs and captures. Store a concise revision/OS/SDK/device/command/result matrix in repository documentation.

Checkpoint:
- Completed: pre-port macOS baseline only.
- Remaining: all release-level evidence.
- Last validation: none for the integrated backend.
- Blockers: #425 and access/permission for required device runs.
- Next action: enumerate the advertised feature/device matrix before running the final integrated renderer.

- `2026-09-29T20:53:29Z`: From #423: macOS on-screen candidate presentation evidence recorded (Documentation/Metal4-Evidence). iOS and visionOS on-screen presentation still required here.
- `2026-09-30T00:37:10Z`: Evidence matrix added: Documentation/Metal4-Release-Evidence.md (Mac tests under API Validation, 3-platform builds, user device runs on Mac/iPhone/Vision Pro, capture, performance). Remaining, blocking: no OS 26 runtime evidence (all devices/simulators here are OS 27); CI not exercised (#443 Xcode pin, #444 GPU-less runners). Stays open.
- `2026-09-30T00:53:47Z`: Closed by user decision: accepted with the evidence in Documentation/Metal4-Release-Evidence.md. Known gaps: no OS 26 runtime runs (all devices are on OS 27); CI not exercised, tracked in #443/#444.

---

## 436: Metal 4 performance and memory regressions are unmeasured

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 425, 399
created: 2026-09-29T18:00:26Z
updated: 2026-09-30T16:17:53Z
closed: 2026-09-30T00:36:16Z
+++

Part of #409 / #256.

Missing: reproducible comparison of the integrated Metal 4 renderer with the retained legacy baseline.

References: Documentation/Metal4-Baseline.md; Documentation/Metal4-Baseline/release-*.json; Tests/MetalSprocketsTests/Metal4BaselineTests.swift.

Acceptance:
- Preserve baseline workloads, output validation, sample counts, configuration, and timing definitions; document unavoidable instrumentation differences explicitly.
- Record repeated Release runs with CPU encoding, total CPU frame processing, GPU execution, initial setup/compilation, and sustained memory/allocator/residency measurements.
- Separate cold/warm compilation and API Validation/instrumentation effects. Do not compare test-suite duration with GPU/encoding timings.
- Compare medians/tails and bounded memory behavior against baseline; explain or fix material regressions before release.
- No optimization-only follow-on features are introduced to change the benchmark workload or hide a regression.

Verification: xcb test -c Release with the opt-in benchmark/filter; retained machine-readable results and a comparison summary; xcb test --raw; xcb build --raw after any fixes.

Checkpoint:
- Completed: three legacy Release runs and measurement harness from #399.
- Remaining: Metal 4 measurements and comparison.
- Last validation: no integrated Metal 4 benchmark run.
- Blockers: #425.
- Next action: verify the migrated harness measures equivalent work before collecting comparison runs.

\- `2026-09-30T00:25:08Z`: Measured (3 Release runs, same harness/workloads/sample counts, MTL_DEBUG_LAYER=0; results in Documentation/Metal4-Baseline/metal4-release-*.json, comparison in Documentation/Metal4-Baseline.md).

Found and fixed a material regression: the first Metal 4 runs were 47-60% slower per CPU frame (update phase 348-441 us). The cause was five per-frame environment modifiers around every recording. Replaced with one Metal4RecordingRoot node.

After the fix, versus legacy medians: CPU frame compute 143-147 us (legacy 251-254, ~43% faster), render 226-232 (legacy 305-309, ~25% faster); encoding compute +5-15%, render ~-10%; GPU medians at parity. Metal allocations constant; resident memory steps up 16-96 KiB and plateaus over 10k frames.

Still open: render GPU p95 26.1-26.3 us versus legacy 12.0-14.5 us (median at parity, looks bimodal), cause unknown. Also, first-frame setup is ~1.6-2x slower warm, and 37 ms/15 ms on the first run after a build. Next: profile the GPU tail (per-frame argument-table creation, residency set commit, or feedback timing granularity) before release.

- `2026-09-30T00:28:53Z`: GPU tail investigation: hypothesis 'residency-set churn (add+commit per frame, remove+commit at retirement)' REJECTED. With removals disabled experimentally, render GPU stayed median 9.7 us / p95 25.9 us (unchanged); experiment reverted. Remaining candidates: (1) timing source: Metal 4 commit-feedback gpuStart/EndTime vs legacy MTLCommandBuffer times may differ in scope or granularity; (2) real per-frame GPU work (argument-table/residency submission). Next step: time the render pass itself with counter-heap timestamps (.gpuCounters) and compare its distribution with the feedback times; or take an Instruments Metal System Trace. Issue stays open for this item only.
- `2026-09-30T00:31:46Z`: GPU tail probe (temporary test, removed): render pass timed with counter-heap timestamps (.gpuCounters) matches commit-feedback times to 0.1 us at every quantile, so the tail is real pass GPU time, not a timing artifact. The same pass as a hand-written raw Metal 4 loop (no MetalSprockets): p50 7.5 / p95 8.9-9.0 / p99 9.5-9.9 us. MetalSprockets in the same process: run A bimodal p50 10.7 / p95 25.8 us; runs B and C p50 8.5 / p95 10.7-10.8 / p99 14.1-14.3 us. So the 25 us mode is intermittent (probably GPU clock/power state or scheduling, not verified), while there is a steady ~1 us median / ~2 us p95 GPU overhead over raw Metal 4 (likely argument-table binding). The benchmark harness reproduced the 26 us p95 in 4 of 4 runs, so it's an interaction with that harness's cadence/order, not yet explained.
- `2026-09-30T00:36:16Z`: Accepted by user: GPU performance as measured. Follow-ups filed: #441 (render GPU p95 tail), #442 (first-frame setup). CPU regression fixed in 29d5b5ba.

---

## 437: Metal 4 migration documentation and examples are incomplete

+++
status: closed
priority: high
kind: documentation
labels: subtask, effort:m, area:metal4
depends: 425
created: 2026-09-29T18:00:26Z
updated: 2026-09-30T16:17:53Z
closed: 2026-09-30T00:12:40Z
+++

Part of #409 / #256.

Missing: final user-facing migration instructions and examples for the implemented Metal 4 surface.

Sources: README.md; RELEASENOTES.md; Sources/MetalSprockets/MetalSprockets.docc; MetalSprocketsUI.docc; Example; .public-api.yaml. References: migration inventory and approved design documents.

Acceptance:
- A complete guide covers OS/device support, shader inputs, queue/encoder/descriptor changes, token/submission ownership, callback meaning/isolation, BlitPass replacement, parameters/indexed buffers, residency, and barriers.
- Before/after examples use real compiled APIs and actual Swift labels; no speculative renames or unfinished placeholders.
- Tutorials, architecture/FAQ/getting-started pages, UI examples, and feature examples agree with the final implementation.
- Every public API break has an explicit migration or approved disposition, including custom shader/loader conformers.
- The API snapshot uses the documented tool/toolchain and CI comparison is understood; generated-format churn is not mistaken for semantic breaks.
- Examples and documentation snippets are validated; hardware-only behavior links to recorded evidence rather than claiming simulator parity.

Verification: xcb build --raw and relevant example destinations; xcb test --raw for compiled snippets/tests; documentation/link checks without unnecessary compilation for prose-only edits.

Checkpoint:
- Completed: RFC, baseline/inventory, design documents, and shader-input migration notes only.
- Remaining: final backend migration guide and full documentation/example sweep.
- Last validation: not run for the final surface.
- Blockers: #425.
- Next action: derive a complete before/after checklist from the final public API diff and migration inventory.

- `2026-09-29T23:56:05Z`: Added Documentation/Porting-to-Metal4.md: a short porting guide (requirements, Draw closures, parameters, compute/copies, barriers and residency, submission/callbacks table, descriptors, behavior changes, checklist). DocC, tutorials and README snippets still need updating.
- `2026-09-30T00:12:39Z`: Docs updated for Metal 4: DocC tutorials 1-4 (vertex data via .vertexValues, uniforms via .parameter by name, drawPrimitives(primitiveType:)), GettingStarted, MetalSprockets.md, Architecture (environment types; command-buffer diagram now MTL4 render/compute encoders, ComputeCommand, barriers, callbacks), Comparison (MetalSprockets side), README particles example (.vertexBuffer), MetalSprockets-Diagram, Comparison/RedTriangle_After.swift, stale doc comments (FrameUniforms, FrameTiming gpuTime, MSAA example). Raw-Metal 'before' sides in Comparison and the diagram intentionally stay as plain Metal. Porting guide (Documentation/Porting-to-Metal4.md) and RELEASENOTES cover every public break and the resource/synchronization contracts. Validation: library and example app build on mac/iOS/visionOS; 739 tests pass (one intermittent failure seen, filed as #440). The markdown/DocC code snippets are prose and are NOT compiled; they were checked by hand against the current API. DocC symbol links were not built.

---

## 438: Obsolete legacy backend code remains after Metal 4 cutover

+++
status: closed
priority: high
kind: task
labels: subtask, effort:m, area:metal4
depends: 435, 436, 437
created: 2026-09-29T18:00:26Z
updated: 2026-09-30T16:17:53Z
closed: 2026-09-30T00:50:33Z
+++

Part of #409 / #256. This is the final cleanup/closure gate, not permission to remove unported features.

Missing: removal of unreachable legacy rendering paths and temporary staging scaffolding after parity and release evidence exist.

Sources: package-wide Metal submission/encoder paths, dependency helpers, tests, examples, and RFC/status documentation.

Acceptance:
- Remove obsolete legacy submission/encoding implementations and temporary candidate routing only after replacement coverage is established.
- Keep Metal types still used by Metal 4, shader metadata inspection, and intentional unavailable migration diagnostics; a textual MTLFunction match is not legacy-backend evidence.
- Retain equivalent GPU-output assertions, golden references, and archived baseline measurements. Do not delete failing tests to achieve a clean suite.
- Confirm all supported roots and advertised features use Metal 4, with no accidental runtime fallback or hidden legacy helper submission.
- Re-run package/example/platform checks, review final API/docs, and record the release commit/revision evidence.
- Update #256/RFC to completed only when every child is closed or has an explicitly approved disposition.

Verification: legacy-path inventory/search audit; xcb test --raw; xcb build --raw and supported platform checks. Documentation-only status edits need no extra compilation.

Checkpoint:
- Completed: none.
- Remaining: all cleanup/closure criteria.
- Last validation: not run.
- Blockers: #435, #436, #437.
- Next action: after release gates pass, identify unreachable staging/legacy paths against the original migration inventory.

- `2026-09-30T00:42:56Z`: Step 1 (staging roots): audit of legacy submission/encoding (makeCommandQueue/makeCommandBuffer/legacy encoders/MTLCommandBuffer) finds only intentional unavailable stubs and Metal 4 calls. Removed dead staging roots: Metal4OffscreenVideoRenderer (its BGRA guard, cancel, and test hooks merged into public OffscreenVideoRenderer; its 5 export tests now target the public root and pass), Metal4ViewRenderer + Metal4MTKViewDriver + Experiments/Metal4PresentationHarness target (unused by RenderView). Coverage kept: presentation order test moved to Metal4PresentationTests; pixel-per-frame with single compile, and full-slot skip + recovery, ported to RenderViewViewModelTests against the real RenderView path; teardown lifetime already in Metal4HeadlessRootTests. OffscreenVideoRenderer.render/finalize are now nonisolated(nonsending), matching the other roots. 737 tests pass under MTL_DEBUG_LAYER (4/4 full runs; one intermittent golden failure logged on #440); mac/ios/vision builds ok.
- `2026-09-30T00:50:20Z`: Step 2 (candidate API): removed the parallel candidate element surface that duplicated the public API: Metal4RenderPipelineElement, Metal4MeshRenderPipelineElement, Metal4RenderPassElement, Metal4ComputePassElement, Metal4ComputePipelineElement, Metal4Dispatch, Metal4Draw, Metal4ComputeCommand, the descriptor-modifier plumbing, Metal4Blending (dead after removal; public blending uses the base descriptor), and the metal4Parameter/VertexBuffer/VertexValues/DebugGroup/Capture/GPUCounters/DepthBias/DepthCompare/RenderPassDescriptorModifier/VisibleFunctionTable modifiers. 11 test files ported to the public API (mechanical perl pass, then hand fixes); golden and numeric assertions unchanged. Metal4OffscreenRenderer moved to the test target as TestOffscreenRenderer; the two engine-level elements used only by the integrated proof became private to that test. Kept on purpose (no public equivalent): metal4Viewport/Scissor/DepthStencil/RetainOwners/UseResources/onMetal4SubmissionTerminated (package helpers used by tests and the YCbCr billboard). 737 tests pass under MTL_DEBUG_LAYER; mac/ios/vision builds ok; public API snapshot unchanged; lint clean.
- `2026-09-30T00:50:33Z`: Final: legacy audit clean (only intentional unavailable stubs reference legacy Metal types); staging roots, harness, and candidate API removed; no runtime fallback exists (every root records through Metal4Context). Disposition of internal engine names: Metal4Context, Metal4SlotPool, Metal4Parameters, Metal4Runner, etc. keep the Metal4 prefix. They are internal/package engine types, not staging duplicates; renaming them is churn with no behavior change. Probe tests (SDK/shader/capture probes, baseline harness) are kept as OS-update regression signals. RFC status updated. Release evidence: Documentation/Metal4-Release-Evidence.md (#435 remains open for OS 26 and CI).

---

## 439: Shader logging has no public API on Metal 4

+++
status: closed
priority: high
kind: bug
labels: area:metal4, area:api
created: 2026-09-30T00:05:16Z
updated: 2026-09-30T16:17:57Z
closed: 2026-09-30T00:09:10Z
+++

The Metal 4 cutover (#425) made `.metalLoggingEnabled(_:)` and `commandBufferDescriptor` unavailable. The only remaining control is the `MS_METAL_LOGGING=1` environment variable. That variable is not an API. Apps can no longer turn shader logging on or off in code, and they cannot send log messages to their own handler.

Constraint: on Metal 4 the log state attaches through `MTL4CommandBufferOptions` when the root begins the command buffer. That happens before traversal. So the setting must belong to a root, not to a subtree.

Proposed API:
- `Runner(device:commandQueue:shaderLogging:)`, `OffscreenRenderer(…, shaderLogging:)` and `OffscreenVideoRenderer` accept an option: off, the MetalSprockets logger, or a custom `@Sendable (String) -> Void` handler. The internal `Metal4ShaderLogging` already implements this.
- `RenderView` gets a SwiftUI modifier `.metalShaderLogging(_:)`.
- `MS_METAL_LOGGING=1` stays as the default when no option is given.
- Update the `.metalLoggingEnabled(_:)` unavailable message, `RELEASENOTES.md` and `Documentation/Porting-to-Metal4.md`. These currently name the environment variable as the replacement.

Acceptance: a shader `os_log` message reaches a custom handler through each root. Logging is off by default. The shader-logging tests pass without depending on the environment variable.

- `2026-09-30T00:09:10Z`: Fixed. Public ShaderLogging value: .disabled, .logger (MetalSprockets logger), .handler(bufferSize:_:) for a custom @Sendable handler, and .processDefault (MS_METAL_LOGGING=1 -> .logger, else .disabled). Roots take shaderLogging: (Runner, both OffscreenRenderer inits, OffscreenVideoRenderer), defaulting to .processDefault. RenderView: SwiftUI .metalShaderLogging(_:), applied when the view's Metal 4 context is created on its first frame. Unavailable messages for .metalLoggingEnabled(_:) and command-buffer descriptors, RELEASENOTES and the porting guide now point to the API. Test: a shader os_log message reaches a custom handler through Runner and OffscreenRenderer; .disabled and the default (without MS_METAL_LOGGING) install no log state. RenderView's modifier is wired but not device-tested. 739 tests pass under API Validation; mac/iOS/visionOS build; API snapshot updated; lint clean.

---

## 440: Intermittent GPU output mismatches in the full test suite

+++
status: closed
priority: medium
kind: bug
labels: area:metal4
created: 2026-09-30T00:12:31Z
updated: 2026-09-30T16:17:54Z
closed: 2026-09-30T02:34:21Z
+++

Seen once after the Metal 4 cutover (during #437 doc work; only comments had changed): `floatingPointTargetsRecompileAndRenderExactValues` read the clear color [0, 0, 0, 1] instead of the drawn [2.5, -1, 0.25, 1] at pixel (4, 4). The test took 2.12 s instead of the usual ~12 ms.

Not reproduced: 5 of 5 isolated runs and 2 more full-suite runs passed.

Facts: `Metal4OffscreenRenderer.render` throws unless the submission completed, so the frame completed without the draw showing. The draw is a full-screen triangle into an 8x8 rgba16Float target.

Unknown cause. Possibilities to check: the color texture's storage mode and CPU visibility in `getBytes`; residency of the vertex buffer under parallel load; slot reuse. Next step: run the full suite in a loop with MTL_DEBUG_LAYER=1 to reproduce, then dump the submission result and the texture state on failure. The test uses candidate elements that #438 will port to the public API.

Do not delete or disable the test.

\- `2026-09-30T00:41:48Z`: Second instance, a different test: testRenderPipelineDescriptorTransformerWithAlphaBlending (golden image isMatch false) failed once in a full MTL_DEBUG_LAYER run during #438, then passed 3/3 filtered and 4/4 full runs. Both failures are GPU-output checks under full parallel load, so a shared cause is likely (not verified). Retitle scope: intermittent GPU output mismatches in the full suite.
\- `2026-09-30T01:46:06Z`: New instance (after the test port): Metal4YCbCrBillboardTests.ownersLiveUntilEveryOverlappingSubmissionRetires failed in run 3 of a 20-run loop (without MTL_DEBUG_LAYER; loop then stopped). Event order was [released 0, terminated 0, terminated 1, released 1]: owner 0 was released before submission 0's termination callback. This is not the golden-image pattern of the earlier two failures. Two readings, not yet distinguished: (a) a real lifetime bug where retained owners drop before GPU completion; (b) the termination callback is delivered asynchronously after retirement, so the test's ordering assumption is too strict. Next: check whether owner release happens at retirement (after completion event) and how the terminated callback is scheduled.
\- `2026-09-30T02:18:12Z`: Reproduced on another machine: Buildkite build #6 (agent shelob, commit 4b8017e5, MTL_DEBUG_LAYER=1). Metal4EncodingTests.drawsBindPipelineAndSupportIndexedGPUAddresses: both draws read back as the clear color [0, 0, 0, 255] instead of red/green, and the test took 1.74 s (normally milliseconds). Same signature as the first instance (floatingPointTargets: clear color read back, 2.1 s). Pattern so far: 2 of 4 failures are 'draw output missing + ~2 s duration', suggesting the work was delayed or dropped rather than mis-rendered; the golden mismatch and the YCbCr owner-ordering failure may or may not share the cause. Not machine-specific.
\- `2026-09-30T02:22:47Z`: Correction: the ~2 s durations are not a signal. Under the parallel full suite the median test takes ~1.6 s (p90 2.2 s); the failing tests' passing runs take 1.5-2.2 s too.

Thread Sanitizer (swift test --sanitize=thread): 74 reports, all one pair: Metal4SubmissionCompletion.init (storing the lock) vs resolve() read on the MTLSharedEvent listener thread. Probably a false positive (the object is fully built before the listener is registered, and the handoff goes through uninstrumented IOSurface/libdispatch); not proven. TSan's slowdown reproduces #440 much more often (3 failures in one run).

Found and fixed (1 of the failure types): the YCbCr owner-ordering failure is a real, deterministic ordering bug. resolve() released owners BEFORE running terminal handlers, so a terminated handler could observe its owners already gone; the test saw it whenever frame 0's GPU work finished after frame 1 had replaced frame 0's element in the tree. Red-first test Metal4SubmissionCompletionTests.terminalHandlersRunBeforeOwnersAreReleased (no GPU). Fix: release owners after waiters and handlers. GPU safety was never affected (owners were still released only after completion).

Still open: the 'draw output missing, outcome .completed' failures (floatingPointTargets, drawsBindPipeline, blending goldens).

\- `2026-09-30T02:34:21Z`: Root cause found and fixed (the 'draw output missing' failures).

Evidence: temporarily instrumented Metal4EncodingTests.drawsBindPipelineAndSupportIndexedGPUAddresses and looped the full suite; it failed on run 6 with: outcome .completed; a control compute dispatch in the same command buffer wrote correctly [100..103]; position buffer in the residency set; pixels unchanged after 200 ms (so completion was not early); but the position buffer's CPU contents were corrupted: first 16 bytes = 2.3694278e-38 = 0x01010101. The draws ran on overwritten vertices.

Cause: Metal4DiagnosticsTests.groupsNestOnEncodersAndCommandBuffers encoded ComputeCommand { fill(buffer: device.makeBuffer(length: 16), range: 0..<16, value: 1) } with the buffer created inline and never declared (useResource). It was freed right after encoding while the GPU fill was pending; the fill then wrote 16 bytes of 0x01 into whatever buffer reused that address in another concurrently running test. That explains the missing-draw and golden-mismatch failures (small vertex buffers), across machines, and only under the parallel full suite. This was a test bug; the library contract (raw encoder closures must declare resources) was correct. Audited every other raw closure in Tests/Sources/Example: all declare their resources.

Fix: create the buffer outside and declare it with .useResource.

Verification: 30 consecutive full-suite runs (alternating MTL_DEBUG_LAYER=1) with the fix: 0 failing runs (previously about 1 in 5-6). Plus the separate owner-ordering bug fixed in ab64c89b. Final: 738 tests pass under MTL_DEBUG_LAYER=1 with -warnings-as-errors.

Noted, not acted on: TSan reports a probable false positive in Metal4SubmissionCompletion (init vs MTLSharedEvent listener thread); API Validation did not flag the freed-buffer fill.

---

## 441: Investigate intermittent 26 us render GPU p95 on Metal 4

+++
status: closed
priority: low
kind: none
created: 2026-09-30T00:36:16Z
updated: 2026-09-30T03:19:01Z
closed: 2026-09-30T03:19:01Z
+++

From #436. The Metal4BaselineTests render workload has a GPU p95 of 26.1-26.3 us (legacy 12.0-14.5); the median is at parity. The distribution is bimodal (~9 us and ~25 us modes). Pass timestamps match commit feedback, so this is real GPU time. It is not residency-set churn (tested). A standalone probe hit the 25 us mode in 1 of 3 runs; raw Metal 4 with no MetalSprockets code had a p95 of ~9 us. Next step: an Instruments Metal System Trace of the benchmark. Also: a steady ~1-2 us GPU overhead over raw Metal 4, probably from argument-table binding.

- `2026-09-30T03:19:01Z`: Closed by user decision: not worth pursuing. Tail is ~16 us above legacy at p95 against a 16.7 ms frame; median at parity. Findings kept above if it resurfaces (real pass GPU time; not residency churn; intermittent; ~1-2 us overhead vs raw Metal 4).

---

## 442: Metal 4 first-frame setup slower than legacy

+++
status: closed
priority: low
kind: none
created: 2026-09-30T00:36:16Z
updated: 2026-09-30T03:25:01Z
closed: 2026-09-30T03:25:01Z
+++

From #436. With warm compiler caches, initial setup is compute 1.0-1.2 ms (legacy 0.65) and render 0.39-0.42 ms (legacy 0.24). The first run after a build took 37 ms / 15 ms. Check pipeline compilation through MTL4Compiler and whether a binary archive or pipeline data sets would help.

- `2026-09-30T03:25:01Z`: Closed by user decision: not orders of magnitude worse. Warm setup is sub-millisecond; cold first-run compile (37 ms compute / 15 ms render in the benchmark) is the only notable cost. If it matters later: profile compile vs reflection vs our setup first; options are Metal 4 pipeline data sets/binary archives, or an explicit precompile API.

---

## 443: CI still pins Xcode 26.4; Metal 4 port only built with Xcode 27

+++
status: closed
priority: high
kind: task
labels: effort:s, area:ci
created: 2026-09-30T00:37:10Z
updated: 2026-10-05T22:36:42Z
closed: 2026-10-05T22:36:42Z
+++

From #435. .github/workflows/swift.yml and docc.yml use Xcode 26.4. The Metal 4 port was only built and tested with Xcode 27.0 (no Xcode 26 installed locally). Either confirm that Xcode 26.4 builds the package and example (all three platforms, -warnings-as-errors), or move CI to Xcode 27 and document the toolchain requirement. Verify by pushing a branch or running with a local Xcode 26.4.

- `2026-09-30T00:54:37Z`: CI moved to Xcode 27.0 (swift.yml, docc.yml); README, release notes and evidence doc updated. Not verified on GitHub: requires a push. If setup-xcode can't find '27.0' on macos-26 runners, check the runner image's installed Xcode list.
- `2026-09-30T01:00:35Z`: Reopened: first CI run failed; macos-26 image only has Xcode 26.0.1-26.6. Switched Xcode jobs to runs-on macos-27 (availability unverified until pushed).
- `2026-09-30T01:03:59Z`: macos-27 label has no hosted runner (job stayed queued). Switched to macos-26 + Xcode 26.6, the newest hosted Xcode. The port has never been built with Xcode 26; the next run will show whether it compiles.
- `2026-09-30T01:12:59Z`: Run 36653335857 (Xcode 26.6): library, example (mac/iOS/visionOS) and swiftlint pass. Failures: 4 test warnings under -warnings-as-errors (deprecated renderPipelineDescriptorModifier; 3 redundant #require), fixed; api-check snapshot mismatch caused by tool/Xcode differences (see #445), snapshot replaced with CI's own output.
- `2026-10-05T22:36:42Z`: Last straggler fixed: docc.yml moved from Xcode 26.4 to 26.6, matching swift.yml/xcode.yml (macos-26 hosted runners top out at 26.6; run 36653335857 verified the build there). README/RELEASENOTES already document the toolchain. The docc job itself is unverified until the next push.

---

## 444: Tests fail without a Metal 4 GPU (CI runners)

+++
status: closed
priority: high
kind: none
created: 2026-09-30T00:37:10Z
updated: 2026-09-30T01:36:03Z
closed: 2026-09-30T01:36:03Z
+++

From #435. Only the Metal4* suites are guarded with supportsFamily(.metal4). Suites ported from legacy (golden rendering, compute, parameters, etc.) now run on Metal 4 unguarded. If GitHub macos-26 runners (paravirtual GPU) lack Metal 4, 'swift test' in CI will fail. Check what the runner's device reports; if needed, add an explicit capability trait to GPU suites so they skip with a reason, and keep a GPU-less subset running.

- `2026-09-30T01:36:03Z`: Confirmed on CI run 36654924171: runner GPU is 'Apple Paravirtual device' without Metal 4; unguarded tests failed and RenderView's queue orFatalError crashed the test process. Fix: shared .requiresMetal4 trait (Tests/MetalSprocketsTests/Support/RequiresMetal4.swift), applied per test to 157 GPU tests (mechanical perl pass by body pattern, plus 12 misses found by simulation) and RenderViewHostingTests as a whole suite; 17 inline Metal 4 suite guards replaced with the trait, and the trait added beside 5 capability-specific guards. CPU-only tests still run on CI. Verified by a temporary local simulation (library + trait treating the device as non-Metal-4, reverted before commit): 737 pass, 0 failures, 0 crashes. Real GPU: 737 pass, none skipped, clean -warnings-as-errors build. CI verification pending push.

---

## 445: Public API snapshot can't be regenerated locally to match CI

+++
status: closed
priority: medium
kind: none
created: 2026-09-30T01:12:59Z
updated: 2026-09-30T02:10:12Z
closed: 2026-09-30T02:10:12Z
+++

CI (api-check) runs crates.io swift-api-tool 0.2.0 under Xcode 26.6. Locally: swift-api-tool 0.2.0 is built from ~/Shared/Projects/Scratch/swift-api-tool and emits doc: fields; Xcode 27 also prints existential types differently (MTLTexture vs any MTLTexture). Either difference alone makes 'swift-api-tool . -o .public-api.yaml' produce a snapshot CI rejects. The committed snapshot was rebuilt from the CI log of run 36653335857. Options: generate the snapshot in CI and upload it as an artifact on failure; or pin both the tool build and Xcode in a documented local command.

- `2026-09-30T02:01:20Z`: Buildkite build #4 (shelob, agent Xcode newer than CI's 26.6, crates.io swift-api-tool 0.2.0): api-check step differs from the committed snapshot by 321 lines. About half are the 'any P' vs 'P' spelling; the rest are View extension members listed in a different group/order. GitHub's api-check (Xcode 26.6) passed on the same commit. Buildkite's step is soft_fail, so it is informational until this issue is resolved.
- `2026-09-30T02:10:12Z`: Duplicate of #391; details copied there.

---

## 446: Release notes don't mention GPUCounterSampleIndex removal

+++
status: closed
priority: low
kind: task
labels: docs, area:metal4
created: 2026-09-30T04:33:40Z
updated: 2026-09-30T16:17:54Z
closed: 2026-09-30T05:07:15Z
+++

RELEASENOTES.md lists GPUCounterSampler as removed on Metal 4 but not GPUCounterSampleIndex, which is also now an unavailable stub (Sources/MetalSprockets/Metal/GPUCounters.swift:70). Add it next to GPUCounterSampler, with the replacement: .gpuCounters(label:_:) delivering GPUCounterSample. Note that the per-stage fragment interval it used to address has no Metal 4 equivalent (GPUCounterSample.fragment is always nil).

- `2026-09-30T05:07:15Z`: Fixed as part of #450: RELEASENOTES.md now lists GPUCounterSampleIndex with GPUCounterSampler and the .gpuCounters(label:_:) replacement.

---

## 447: Verify and document custom counter-heap timestamps from raw encoder closures

+++
status: open
priority: low
kind: task
labels: area:metal4, area:timing, effort:m
created: 2026-09-30T04:33:40Z
updated: 2026-09-30T16:18:18Z
+++

Timing inside a pass (per draw or per dispatch) has no built-in API on Metal 4. In principle a caller can create an MTL4CounterHeap, call writeTimestamp(granularity:counterHeap:index:) (or the render encoder's after-stage variant) inside RenderCommand, ComputeCommand or Draw, and resolve the heap after .onCommandBufferCompleted. This is untested through MetalSprockets.

Done when: a test records and resolves timestamps this way for a render and a compute pass under MTL_DEBUG_LAYER=1; it is known whether the heap needs a residency or lifetime declaration; and Documentation/Porting-to-Metal4.md has a short example. If this route does not work, say why here.

---

## 448: Decide whether to expose GPU timestamp heaps or a timestamp modifier publicly

+++
status: open
priority: low
kind: enhancement
labels: area:metal4, area:api, area:timing, effort:s
depends: 447
created: 2026-09-30T04:33:40Z
updated: 2026-09-30T16:18:18Z
+++

GPUCounterSampler and GPUCounterSampleIndex gave callers direct control of counter sampling. On Metal 4 the only public route is .gpuCounters(label:_:), one sample per pass; the counter heap inside Metal4TimestampSampler is internal. Possible APIs: a .timestamp(into:index:) modifier, or access to the heap behind .gpuCounters. Decide after the do-it-yourself route is verified (see the counter-heap documentation issue); if that route is enough, close this.

- `2026-09-30T04:33:46Z`: Depends on #447.

---

## 449: Measure the cost of leaving .gpuCounters on every frame

+++
status: closed
priority: low
kind: task
labels: area:metal4, area:timing, effort:s
created: 2026-09-30T04:33:40Z
updated: 2026-10-06T01:06:19Z
closed: 2026-10-06T01:06:19Z
+++

.gpuCounters(label:_:) creates or reuses a counter heap and resolves timestamps for every pass on every frame. Its overhead has not been measured, so it is unknown whether it is safe to leave on in a shipping app or only for profiling. Measure CPU frame time and GPU time with and without it in the Metal4BaselineTests workloads (Release, MTL_DEBUG_LAYER=0), and document the result in the modifier's doc comment.

- `2026-10-06T01:06:19Z`: Measured (Apple M5 Max, macOS 27.0.1, Release, MTL_DEBUG_LAYER=0; 5,000 frames per variant, interleaved 500-frame blocks; medians). Compute: CPU 89 -> 102 us/frame (+13 us), GPU 1.96 -> 1.96 us. Render 512x512 single draw: CPU 137 -> 152 us (+16 us), GPU 7.96 -> 7.58 us (noise). So ~15 us CPU per pass per frame, no measurable GPU cost: fine to leave on. Single run on one machine. Re-run: xcb test -c Release -e METALSPROCKETS_GPU_COUNTERS_OUTPUT=/tmp/out.json -e MTL_DEBUG_LAYER=0 -- --filter recordGPUCountersOverhead. Doc comment not updated.

---

## 450: Remove Metal 4 migration stubs

+++
status: closed
priority: low
kind: task
labels: area:metal4, area:api
created: 2026-09-30T04:35:18Z
updated: 2026-09-30T16:17:58Z
closed: 2026-09-30T05:07:15Z
+++

The Metal 4 port left 23 @available(*, unavailable, message:) stubs whose only job is to turn old calls into compile errors with a migration hint, plus one @available(*, deprecated, renamed:) forwarder. They are dead code: bodies are placeholders (EmptyElement(), empty types, unreachable). They clutter autocomplete and the API snapshot diff. Decision: remove them before Metal 4 ships; no transition release.

Stubs (8 files): BlitPass, Blit, CommandBufferElement, GPUCounterSampler, GPUCounterSampleIndex; .commandBuffer, .commandQueue, .commandBufferDescriptor, .commandBufferDescriptorModifier, .computePassDescriptor, .metalLoggingEnabled, .onCommandBufferScheduled, the MTLCommandBuffer .onCommandBufferCompleted, MTLRenderPassDescriptor/MTLRenderPipelineDescriptor overloads, MTLFunction linkedFunctions/visibleFunctionTable overloads, Runner(commandQueue: MTLCommandQueue), the MTLFunction shader init; MSEnvironmentValues.blitCommandEncoder, commandBufferDescriptor, computePassDescriptor. Deprecated: renderPipelineDescriptorModifier(_:) (renamed renderPipelineDescriptorTransformer).

Find them with: rg '@available\(\*, (unavailable|deprecated)' Sources

Done when: the declarations are deleted (and files that become empty), callers in Tests/Example/docs use the replacements, the API snapshot is regenerated with Scripts/api-snapshot.sh, RELEASENOTES.md's 'removed with migration diagnostics' wording says they are removed outright, and Documentation/Porting-to-Metal4.md remains the migration reference (it maps each old API to its replacement).

- `2026-09-30T05:07:15Z`: Done. Removed all 23 unavailable stubs and the deprecated renderPipelineDescriptorModifier(_:) (155 lines). Deleted BlitPass.swift and CommandBufferDescriptorModifier.swift (stubs only); renamed CommandBufferElement.swift to SubmissionCallbacks.swift (it keeps onSubmissionCommitted/onCommandBufferCompleted). Nothing in Tests or Example used them. RELEASENOTES now says the APIs are removed outright and lists each with its replacement (adds GPUCounterSampleIndex, closes the gap in #446); Porting-to-Metal4.md says removed APIs are unknown names and gained a 'Shaders and GPU timing' table plus rows for the removed modifiers and environment values. Historical design docs (Metal4-*-Design.md, inventory, baseline) left as written. API snapshot: only renderPipelineDescriptorModifier disappears (the snapshot never listed unavailable declarations); regenerated with Scripts/api-snapshot.sh. Verification: 738 tests pass with MTL_DEBUG_LAYER=1 and -warnings-as-errors; mac/ios/vision builds ok; lint clean; snapshot --check ok.

---

## 451: No way to encode MetalPerformanceShaders work from elements on Metal 4

+++
status: closed
priority: medium
kind: enhancement
labels: area:metal4, effort:l
created: 2026-09-30T15:50:35Z
updated: 2026-09-30T17:15:08Z
closed: 2026-09-30T17:15:08Z
+++

On the metal4 branch, elements only get an `MTL4CommandBuffer` (`environmentValues.commandBuffer`). MPS kernels (for example `MPSImageGaussianBlur.encode(commandBuffer:sourceTexture:destinationTexture:)`) only accept a Metal 3 `MTLCommandBuffer`, so an element can no longer encode MPS work.

An element also cannot run MPS on its own Metal 3 queue with correct ordering: the element runs while the MTL4 submission is being recorded, before commit, so MPS work would run before earlier passes in the same submission have produced its inputs. Ordering it would need events that split the submission around the MPS work, and the root owns commit.

Impact: MetalSprocketsAddOns `GaussianBlurPipeline` wrapped `MPSImageGaussianBlur` and had to be rewritten as a custom compute kernel on its metal4 branch. Any other MPS-based element hits the same wall.

Expected: some supported way to interleave Metal 3 / MPS work with a Metal 4 submission from inside the element tree, or documentation that MPS is unsupported.

- `2026-09-30T16:29:31Z`: Drafted RFCs/0004-metal3-interop.md (options: document unsupported / split submission around Metal 3 work / ship compute replacements). Porting guide now documents MPS as unsupported. Left open pending a decision on option B.
- `2026-09-30T17:13:45Z`: Correction: MPSNDArray kernels have encode(withMTL4CommandEncoder:...) on OS 27 and work inside ComputeCommand (MPSInteropTests, clean under MTL_DEBUG_LAYER=1). MPSGraph runs on MTL4CommandQueue but commits itself. Only MPS image kernels (MPSUnaryImageKernel etc.) lack a Metal 4 path. Guide and RFC 0004 updated.
- `2026-09-30T17:15:08Z`: Resolved by documentation: NDArray kernels supported via ComputeCommand, image kernels unsupported (port to compute), MPSGraph outside the tree. RFC 0004 remains a draft for image-kernel interop if needed.

---

## 452: Acceleration structures cannot be bound as shader parameters on Metal 4

+++
status: closed
priority: medium
kind: enhancement
labels: area:metal4, effort:m, area:api
created: 2026-09-30T16:05:00Z
updated: 2026-09-30T16:28:12Z
closed: 2026-09-30T16:28:12Z
+++

The parameter modifiers (`.parameter(_:buffer:)`, `texture:`, `samplerState:`, `value:`) only produce buffer, texture, sampler and bytes entries. When the shader argument is an `instance_acceleration_structure` or `primitive_acceleration_structure`, binding fails with a kind mismatch error. The Metal 4 encoders have no `setAccelerationStructure`, so there is no other way to bind one from a `ComputeDispatch` or `Draw`.

Impact: MetalSprocketsAddOns `RayTracedShadowComputePass` had to move the acceleration structure into its parameter struct as an `MTLResourceID` and change the kernel signature.

- `2026-09-30T16:28:12Z`: Added .parameter(_:functionTypes:accelerationStructure:) and a single-stage variant. Binds instance or primitive acceleration structures via the argument table and keeps them resident. Test: ComputePassTests.accelerationStructureBindsAsAParameter (also clean under MTL_DEBUG_LAYER=1).

---

## 453: No public indexed draw for MTKMesh or index buffers on Metal 4

+++
status: closed
priority: medium
kind: enhancement
labels: area:metal4, effort:m, area:api
created: 2026-09-30T16:05:00Z
updated: 2026-09-30T16:26:37Z
closed: 2026-09-30T16:26:37Z
+++

Metal 4 `drawIndexedPrimitives` takes a GPU address and a length, not an `MTLBuffer`. MetalSprockets has an internal `drawIndexed` that validates the range and retains the index buffer, but nothing public. MetalSupport helpers (`setVertexBuffers(of:)`, `draw(_ mesh:)`) only extend `MTLRenderCommandEncoder`.

Each client must compute `gpuAddress + offset` and index lengths by hand, and must remember `.useResource` on the index buffer. Forgetting it lets the GPU read freed memory.

Impact: MetalSprocketsAddOns added its own `vertexBuffers(of:)` element modifier and an `MTL4RenderCommandEncoder.draw(_ mesh:)`. Other dependents will need the same.

- `2026-09-30T16:18:19Z`: Related: #456 (porting guide should cover drawIndexedPrimitives GPU address + .useResource). If a public indexed draw lands, document it there.
- `2026-09-30T16:26:37Z`: Added Draw(primitiveType:indexBuffer:indexType:indexCount:indexBufferOffset:instanceCount:), Draw(mesh:instanceCount:) and .vertexBuffers(of:). Index buffers are validated and kept resident automatically. Tests: Metal4RenderStateTests.indexedDrawFromAnIndexBuffer, meshDrawRendersAnMTKMesh.

---

## 454: No public way to mark a parameter binding optional

+++
status: closed
priority: low
kind: enhancement
labels: area:metal4, effort:s, area:api
created: 2026-09-30T16:05:00Z
updated: 2026-09-30T16:25:31Z
closed: 2026-09-30T16:25:31Z
+++

`Metal4Parameters` supports `isOptional` internally, but the public `.parameter` modifiers always create required entries. If a pipeline variant does not declare the argument, the draw throws "Parameter X is not a binding of any stage the filter allows in this pipeline".

Repro: a pipeline that switches fragment shader by a flag, where only one fragment shader declares `fonts`. Apply `.parameter("fonts", functionType: .fragment, buffer:)` unconditionally; the other variant throws.

Impact: MetalSprocketsAddOns `SlugTextRenderPipeline` (wireframe mode) had to split its element tree to apply the parameter conditionally.

- `2026-09-30T16:25:31Z`: will not fix. Parameters that no stage declares keep throwing, so misspelled names are caught. For pipeline variants, apply the parameter conditionally in the element builder (if/else) instead.

---

## 455: Cull mode, fill mode and amplification leak between draws in a pass

+++
status: closed
priority: medium
kind: bug
labels: area:metal4, effort:s
created: 2026-09-30T16:05:00Z
updated: 2026-09-30T16:21:25Z
closed: 2026-09-30T16:21:25Z
+++

`Draw` resets depth/stencil state, depth bias, stencil reference, viewport and scissor for every draw, so nothing leaks between siblings. It does not reset cull mode, triangle fill mode, front-facing winding, or vertex amplification count. A `Draw` closure that calls `encoder.setTriangleFillMode(.lines)` makes every later draw in the same pass render as wireframe.

Repro:
1. In one RenderPass, add a Draw that calls `setTriangleFillMode(.lines)`, then a second Draw that sets nothing.
2. The second draw renders as wireframe.

Expected: each draw starts from default state, like depth bias and viewport. Actual: state from an earlier sibling persists.

Affected in MetalSprocketsAddOns: WireframeRenderPipeline, EdgeLinesRenderPipeline, GraphicsContext3D (debug wireframe), SlugTextRenderPipeline (wireframe, amplification, viewports).

- `2026-09-30T16:21:25Z`: Draw now resets cull mode, fill mode, winding and amplification count per draw. Regression test: Metal4RenderStateTests.cullAndFillModeDoNotLeakToSiblings.

---

## 456: Porting-to-Metal4.md misses several API changes

+++
status: closed
priority: low
kind: documentation
labels: area:metal4, effort:s
created: 2026-09-30T16:05:00Z
updated: 2026-09-30T16:28:52Z
closed: 2026-09-30T16:28:52Z
+++

Found while porting MetalSprocketsAddOns. Not covered in Documentation/Porting-to-Metal4.md:

- `drawMeshThreadgroups(_:threadsPerObjectThreadgroup:threadsPerMeshThreadgroup:)` is now `drawMeshThreadgroups(threadgroupsPerGrid:...)`.
- The Swift overlay for vertex amplification is `setVertexAmplificationCount(_ viewMappings: [MTLVertexAmplificationViewMapping])`; the old `(count, viewMappings: &array)` form does not compile.
- Texture copies in a `ComputeCommand` use `copy(sourceTexture:...destinationTexture:...)`, not `copy(from:...to:...)`.
- Generic value types from other modules (for example GeometryLite3D `Packed3<Float>`) cannot be passed to `.vertexValues` or `.parameter(values:)`, because `BitwiseCopyable` cannot be added from outside the declaring module.
- `drawIndexedPrimitives` takes a GPU address and length; the index buffer must be declared with `.useResource`.
- `MTL4RenderPipelineColorAttachmentDescriptor` uses `blendingState = .enabled`, not `isBlendingEnabled` (the guide mentions this only for the transformer).
- MetalSupport encoder helpers (`setVertexBuffers(of:)`, `draw(_ mesh:)`, `setVertexUnsafeBytes`, `withDebugGroup`) no longer apply.

- `2026-09-30T16:18:19Z`: Related: #453 (public indexed draw). The drawIndexedPrimitives bullet should point at that API if it lands.
- `2026-09-30T16:28:52Z`: Porting guide now covers drawMeshThreadgroups rename, amplification overlay, indexed/mesh draws (#453), MetalSupport helper replacements, cross-module BitwiseCopyable, acceleration structure parameters (#452), texture copy labels, blendingState, and per-Draw rasterizer resets (#455). Also fixed a stale .environment(\.cullMode) example in Architecture.md.

---

## 457: Investigate optional-value parameter overloads (nil skips the binding)

+++
status: open
priority: low
kind: enhancement
labels: area:api, area:metal4, effort:s, deferred
created: 2026-09-30T16:32:51Z
updated: 2026-10-06T06:28:54Z
+++

Follow-up to #454 (closed will not-fix; the isOptional flag was reverted).

Idea, following SwiftUI: let .parameter take an optional value, where nil means "no binding" and skips the missing-binding check. A non-nil value keeps the strict check, so a misspelled name still throws.

    .parameter("fonts", functionType: .fragment, buffer: isWireframe ? nil : fonts)

This lets one element tree feed pipeline variants without splitting the tree, when the caller knows which variant is active. Precedent: useResource(_: (any MTLResource)?) and useComputeResources(_: [...]?).

Open questions:
- Textures already take MTLTexture?, where nil clears the slot but still requires the binding. Argument tables are zero-initialized, so skipping gives the same GPU state; only the missing-name error changes.
- Values: Optional<T> is itself BitwiseCopyable, so .parameter("x", value: Float?) compiles today and binds the raw optional bytes. An optional-value overload must win over the generic one, or values should be left out.
- Scope: buffer, sampler and acceleration structure (and texture semantics), maybe not values.

Done when: decide yes/no; if yes, add the overloads, a test for nil-skips and non-nil-still-throws, and update the API snapshot.

---

## 458: Cannot bind a texture array shader argument by name

+++
status: closed
priority: medium
kind: bug
labels: effort:m, area:metal4, area:api
created: 2026-09-30T17:23:38Z
updated: 2026-09-30T17:33:35Z
closed: 2026-09-30T17:33:35Z
+++

A kernel argument declared as `array<texture2d<float>, N> textures [[texture(0)]]` cannot be filled with `.parameter`. `Metal4Parameters` only binds one texture at `binding.index`, and there is no parameter overload that takes `[MTLTexture]`. The other N-1 slots stay empty (zero-initialized), and API Validation reports them as unset.

Found while porting SolarSystem (a Metal 4 ray tracer) to the `metal4` branch. The kernel samples up to 20 planet textures by index.

Workaround used: move the array into an argument buffer struct (`struct BodyTextures { array<texture2d<float>, 20> items; }`), bind it with `.parameter("textures", values: [MTLResourceID])`, and declare the textures with `.useComputeResources(_:usage:)`.

Expected: a way to bind an array of textures (and probably buffers/samplers) to an array argument by name, using the reflected array length.

- `2026-09-30T17:26:49Z`: Confirmed: Metal4Parameters binds each named arg to a single binding.index; array texture args only fill slot 0. Also Metal4PipelineBindings.Binding drops arrayLength and tableSizes reserves only index+1, so arrays are undersized. Fix: thread arrayLength through reflection + add .texture([MTLTexture]) overload writing index..<index+N. Related to #457, #459 (metal4 port).
- `2026-09-30T17:33:35Z`: Fixed: added parameter(_:textures:) binding an array texture argument across consecutive slots; reflection now threads arrayLength and sizes the table for it.

---

## 459: No public way to reuse per-frame GPU resources after a submission finishes

+++
status: closed
priority: medium
kind: enhancement
labels: effort:l, area:metal4, area:api
created: 2026-09-30T17:23:38Z
updated: 2026-09-30T17:33:35Z
closed: 2026-09-30T17:33:35Z
+++

A frame that rebuilds an instance acceleration structure needs its own instance-descriptor buffer, build scratch buffer and destination acceleration structure. These cannot be overwritten while an earlier frame that uses them is still on the GPU.

In a hand-written Metal 4 renderer this is a ring of N frame resources guarded by the commit feedback handler. With MetalSprockets the app cannot tell when a submission has finished:

- `onMetal4SubmissionTerminated(_:)` is `package`, not public.
- `.onCommandBufferCompleted` does not run for discarded or failed recordings, so a pool driven by it can leak entries.
- The runner slot count and slot index are not visible, so the app cannot size or index a matching ring.
- `.parameter(_:values:)` scratch storage handles small constant data, but not allocations that Metal needs as real resources (acceleration structures, AS build scratch, instance buffers).

Found while porting SolarSystem to the `metal4` branch. Workaround used: allocate a new instance buffer, scratch buffer and acceleration structure every frame and let `.useComputeResources` keep them alive until the submission ends. This works but allocates GPU memory every frame.

Expected: either a public "submission terminated" callback that always fires (completed, failed or discarded), or a per-slot transient resource API (for example, a pool keyed by the recording slot).

- `2026-09-30T17:26:50Z`: Confirmed: onMetal4SubmissionTerminated lives in a 'package extension' (Metal4CoreElements.swift:145), not public. Context has capacity/availableSlotCount/onSubmissionTerminated internally but none exposed, and slot index is not surfaced. Needs a public always-fires terminal callback and/or a slot-keyed transient resource pool. Related to #458 (metal4 port).
- `2026-09-30T17:33:35Z`: Fixed: added public onSubmissionFinished { } that fires once on any termination including discard, so per-frame GPU resources can be recycled without leaking.

---

## 460: metal4 reintroduces the BitwiseCopyable constraint on parameter values, which breaks Release builds that pass C header structs

+++
status: closed
priority: high
kind: bug
labels: metal4
created: 2026-09-30T18:02:54Z
updated: 2026-09-30T18:05:44Z
closed: 2026-09-30T18:05:44Z
+++

On the metal4 branch, `.parameter(_:value:)`, `.parameter(_:values:)` and `.vertexValues(_:index:)` require `Value: BitwiseCopyable` (Parameters.swift, backed by Metal4Parameters.set and Metal4ScratchArena.allocate). main reverted the same constraint in 343df503 ("Revert BitwiseCopyable constraint on parameter() (#347)") because it broke callers passing C/Metal header structs. metal4 brings it back.

It now breaks a downstream Release build:

1. MetalSprocketsAddOns (metal4 branch) passes C structs from its shader headers (`LightingArgumentBuffer`, `BlinnPhongMaterialArgumentBuffer`) to `.parameter(_:value:)` through a generic helper constrained `where Value.ArgumentBuffer: BitwiseCopyable`.
2. Debug builds and `swift test` work.
3. A Release build of MetalSprocketsAddOnsExamples (Xcode 27, macOS) fails when importing the MetalSprocketsAddOns module:

```
MetalSprocketsAddOns.swiftmodule/arm64-apple-macos.swiftmodule:1:1: Conformance of LightingArgumentBuffer to BitwiseCopyable not found in referenced module MetalSprocketsAddOnsShaders
MetalSprocketsAddOns.swiftmodule/arm64-apple-macos.swiftmodule:1:1: Conformance of BlinnPhongMaterialArgumentBuffer to BitwiseCopyable not found in referenced module MetalSprocketsAddOnsShaders
```

The same error appeared in a Debug test build when the constraint was on a public protocol associated type (`associatedtype ArgumentBuffer: BitwiseCopyable`). The C structs are imported through a clang module, and the implicit BitwiseCopyable conformance recorded in the Swift module is not found again on import.

Also affected: generic value types from other modules (for example GeometryLite3D `Packed3<Float>`) cannot be passed at all, because BitwiseCopyable cannot be added from outside the declaring module.

Related: #347 (replace isPOD with BitwiseCopyable), which was reopened after the revert on main.

Expected: parameter APIs accept C header structs in all build configurations, as on main.

- `2026-09-30T18:05:39Z`: Relaxed the BitwiseCopyable constraint on parameter(_:value:)/(_:values:) and vertexValues(_:index:) back to unconstrained generics with runtime POD asserts (matching main's #347 revert). Internal set/scratch/allocate generics also unconstrained. C/Metal header structs imported through a clang module now bind in all build configs. Added regression test 'POD structs without a BitwiseCopyable conformance bind as single values'.

---

## 461: missingEnvironment(keyPath) error messages lose the property name in Release builds

+++
status: closed
priority: low
kind: bug
labels: effort:s, area:api
created: 2026-09-30T18:27:58Z
updated: 2026-10-05T23:19:33Z
closed: 2026-10-05T23:19:33Z
+++

MetalSprocketsError.missingEnvironment(_:PartialKeyPath) interpolates the KeyPath into a String (Support.swift:7). In Debug this renders as \MSEnvironmentValues.device, but in Release KeyPath interpolation degrades to <computed 0x... (Optional<MTLDevice>)>, so the property name is lost from user-facing error messages (and the FAQ examples). Surfaced when the BK matrix started running release tests (UseResourceTests.testMissingEnvironmentKeyPath, relaxed to a case-insensitive check). Consider deriving a stable name instead of relying on KeyPath reflection.

- `2026-10-05T23:19:34Z`: Call sites now pass plain property names ("renderCommandEncoder" etc.) instead of key paths; the PartialKeyPath overload is deprecated. Test: Draw outside a RenderPass reports 'Missing environment value: renderCommandEncoder' (failed before; passes in Debug and Release).

---

## 462: Redundant encoder state set before every Draw

+++
status: closed
priority: low
kind: task
labels: area:metal4
created: 2026-09-30T18:34:11Z
updated: 2026-09-30T18:52:37Z
closed: 2026-09-30T18:52:37Z
+++

With MTL_DEBUG_LAYER=1, most render demos in MetalSprocketsExamples log thousands of 'Redundant call to ...' performance warnings per second: setCullMode, setTriangleFillMode, setVertexAmplificationCount, setStencilReferenceValue, setDepthStencilState, setDepthBias, setRenderPipelineState (and setComputePipelineState on compute). Cause: each Draw resets cull/fill/winding/amplification (#455), and pipeline and depth-stencil state are re-bound even when unchanged. Track the current encoder state per pass and skip sets that do not change it. Besides the cost, the flood hides real validation messages. Worst demos: Wireframe, Debug Shader, Trivial Mesh, Spinning Cube, Shadow Map.

---

## 463: No isolated way to update @MSState when GPU work completes

+++
status: closed
priority: medium
kind: enhancement
labels: area:metal4, area:concurrency
created: 2026-09-30T18:34:11Z
updated: 2026-09-30T18:57:15Z
closed: 2026-09-30T18:57:15Z
+++

onCommandBufferCompleted is now @escaping @Sendable, so it cannot capture an Element's self to write @MSState (compile error: capture of non-Sendable self). Ports that swapped ping-pong textures or set a 'baked' flag on completion (GameOfLife, Gargantua, StamFluid in MetalSprocketsExamples) moved to onSubmissionCommitted. That works for GPU ordering only because queue barriers order later frames. It is wrong for CPU-written buffers still in flight (StamFluid source textures) and for failed or discarded submissions. Consider a completion callback that runs on the owning isolation, or a Sendable way to write MSState from completion (see #392, #364).

---

## 464: SubmissionResult has no kernel timing

+++
status: closed
priority: low
kind: enhancement
labels: area:metal4
created: 2026-09-30T18:34:11Z
updated: 2026-09-30T18:52:37Z
closed: 2026-09-30T18:52:37Z
+++

Metal 3 code read kernelStartTime/kernelEndTime from MTLCommandBuffer. SubmissionResult only has gpuStartTime, gpuEndTime and gpuDuration, so MetalSprocketsExamples' TriangleDemo dropped its Kernel Time readout. Expose kernel timing if Metal 4 has an equivalent, or say in Porting-to-Metal4.md that it is gone.

---

## 465: Argument tables are created every frame

+++
status: closed
priority: low
kind: enhancement
labels: area:metal4
created: 2026-10-02T04:35:17Z
updated: 2026-10-02T04:59:10Z
closed: 2026-10-02T04:59:10Z
+++

Metal4Parameters.makeTables creates MTL4ArgumentTable instances during each recording instead of reusing retired tables.

Evidence: /Users/schwa/Desktop/SolarSystem.gputrace contains six newArgumentTableWithDescriptor calls at api29–api34 in one captured frame. The capture establishes these allocations for that frame; repeated-frame behavior also follows from the recording path in Sources/MetalSprockets/Metal/Metal4Parameters.swift.

## Proposed fix (per user)

Keep argument-table reuse an automatic implementation detail, separate from residency ownership in #466. Ordinary clients should not need manual table management.

- Pool tables by compatible descriptor configuration within the appropriate device/context ownership boundary.
- Lease tables during recording. Do not share a mutable leased table with another recording or submission that may still use it.
- Recycle tables only after submission completion, or when an unsubmitted recording is discarded or fails.
- Ensure reused tables have valid bindings for their next use; stale bindings must not leak between recordings.

## Validation

Test descriptor compatibility, overlapping submissions, completion recycling, recording failure/discard, and stale-binding prevention. Verify allocations stabilize after warm-up for a steady workload, while allowing growth for increased concurrency or new descriptor configurations. Repeat the SolarSystem capture to confirm steady-state table creation is eliminated.

- `2026-10-02T04:48:38Z`: Implemented slot-owned argument-table pools keyed by exact buffer/texture/sampler counts. Each binding call leases a distinct table; a slot resets its pool only after safe retirement or discard. Reused tables clear all bindings, and submission resources still retain tables independently of context lifetime. Added five tests for compatibility, bounded reuse, discard/failure, event-gated in-flight isolation, and GPU-visible clearing of omitted buffers and shortened texture arrays. Package and example builds, full test suite, and changed-file SwiftLint pass. SolarSystem recapture remains pending: its package manifest references the remote metal4 branch and needs a local dependency override to exercise these uncommitted changes. No implementation commit yet.
- `2026-10-02T04:59:10Z`: Fixed with slot-owned argument-table pooling. Builds, full tests, and lint passed. User approved shipping on test coverage without the SolarSystem recapture.

---

## 466: Residency management needs persistent automatic ownership and manual control

+++
status: closed
priority: medium
kind: enhancement
labels: area:metal4, area:api
created: 2026-10-02T04:35:31Z
updated: 2026-10-02T05:27:12Z
closed: 2026-10-02T05:27:12Z
+++

Metal4ResidencyTracker reference-counts allocations bound by submissions. When the previous submission retires before the next acquires them, allocations are removed and then added again, even for persistent resources.

Evidence: /Users/schwa/Desktop/SolarSystem.gputrace contains one captured frame with 25 removeAllocation calls (api2–api26), a residency commit (api27), 25 addAllocation calls, and another residency commit (api60). This demonstrates churn in the captured frame, not its frequency across frames. Coverage by the application-owned residency set still needs verification.

## Proposed fix (per user)

Separate resource lifetime, residency ownership, and submission retention. Automatic management should work by default, with explicit manual control when needed.

- Base persistent residency on resource collections with explicit ownership. Framework-owned resources remain resident for their owning lifetime or collection membership, rather than only while submissions are in flight.
- Require an explicit lifetime signal for removal: the residency set itself retains allocations, so allocation deallocation cannot supply that signal.
- Keep transient resources submission-scoped. Externally supplied raw Metal resources also remain submission-scoped unless explicitly registered for persistent residency.
- Allow a whole context to use client-managed residency, and allow individual resources or collections to opt out of automatic tracking.
- Support client-owned residency sets through both RenderView and Runner, including mixed automatic and manual resources without duplicate tracking.
- Preserve in-flight lifetime safety independently of residency policy. Removing collection membership must not invalidate resources still used by submitted work.
- Do not use keep-for-N-frames heuristics.

Exact collection APIs and ownership signals remain to be designed against existing resource wrappers.

## Validation

Verify persistent resources avoid remove/add churn between serial submissions. Verify transient retirement, explicit unregister, owner teardown, overlapping submissions, discarded recordings, and mixed/manual residency in RenderView and Runner. Confirm manual mode preserves in-flight retention. Repeat the SolarSystem capture to compare calls; do not infer CPU performance gains from call counts alone.

Relevant code: Sources/MetalSprockets/Metal/Metal4ResidencyTracker.swift, Metal4Context.swift, and Metal4RecordingScope.swift. Argument-table reuse is tracked separately in #465.

\- `2026-10-02T05:23:40Z`: Implemented both planned steps, uncommitted. Added ResourceCollection with idempotent registration, recording membership snapshots, deferred unregister, heap coverage, and teardown cleanup. Added ResidencyConfiguration to Runner and RenderView for automatic, manual, and mixed operation with client-owned Metal residency sets. Residency opt-out preserves declared-resource retention. Raw sets require the client to keep their membership valid until all uses retire; this contract is documented in Documentation/Porting-to-Metal4.md.

Framework-owned scratch buffers, MSAA color/depth targets, generated offscreen/video targets, cached visible-function tables, and immersive stencil targets now use persistent collections. Replaced external textures fall back to submission-scoped tracking. No frame-count retention heuristic.

Validation: full macOS test suite, 13 new regression tests, changed-file SwiftLint, macOS example build, iOS device example build, and visionOS device package build passed. Tests cover serial reuse, overlapping recordings, failure/discard, unregister/reregister, owner teardown, manual retention, external sets, heaps, GPU completion, timeout retention, MSAA replacement, and RenderView configuration changes. visionOS simulator build remains blocked by missing Metal 4 compiler descriptor types in unchanged ShaderFunction.swift; tracked separately in #467. The device build reports an existing isolated-conformance warning in ImmersiveRuntime.waitUntilRunning.

SolarSystem recapture remains pending because its manifest uses the remote package. #466 remains open pending review and capture validation or explicit acceptance of test-only validation.

- `2026-10-02T05:27:12Z`: Full test suite passed again. User approved commit and push based on passing tests, without requiring SolarSystem recapture. Simulator build limitation remains tracked in #467.

---

## 467: visionOS simulator build fails on Metal 4 compiler descriptor types

+++
status: closed
priority: low
kind: bug
labels: effort:s, area:metal4
created: 2026-10-02T05:22:16Z
updated: 2026-10-05T23:14:22Z
closed: 2026-10-05T23:14:22Z
+++

With Xcode 27.0 RC (27A266a), a visionOS simulator package build fails in unchanged Sources/MetalSprockets/Metal/ShaderFunction.swift:67–77:

cannot find type 'MTL4FunctionDescriptor' in scope
cannot find 'MTL4LibraryFunctionDescriptor' in scope
cannot find 'MTL4SpecializedFunctionDescriptor' in scope

Repro: xcb build MetalSprocketsUI -- --triple arm64-apple-xros26.0-simulator --sdk /Applications/Xcode-27.0.0-Release.Candidate.app/Contents/Developer/Platforms/XRSimulator.platform/Developer/SDKs/XRSimulator.sdk

The corresponding visionOS device build succeeds. Discovered during #466 validation. The new residency collection code guards its device-only machine-learning pipeline type; the remaining failure is outside that change.

- `2026-10-05T22:29:40Z`: Related: #473 (umbrella: no Metal 4 in Simulator) and #478 (iOS Simulator build).
- `2026-10-05T23:14:22Z`: Duplicate of #473. Same root cause: the Simulator SDKs ship no Metal 4.

---

## 468: Metal 4 lifecycle abstractions introduce a second conceptual model

+++
status: closed
priority: high
kind: enhancement
labels: area:metal4, area:api
created: 2026-10-02T05:28:25Z
updated: 2026-10-02T06:02:07Z
closed: 2026-10-02T06:02:07Z
+++

The Metal 4 backend introduces slots, generation-checked leases, recording scopes, and recorded-submission objects over command buffers, command allocators, and queues. These concepts require understanding a library-specific lifecycle alongside the Metal lifecycle.

Metal4SlotPool and Metal4Context are internal, but RecordedSubmission is public and exposes commit/discard semantics. Recording is Metal terminology; a separate recorded-submission object is a MetalSprockets abstraction. Renaming slots or replacing them with another recording wrapper would not address the concern.

Expected: the SwiftUI-style element API composes Metal operations without imposing an unnecessary parallel object model. Ownership and safety machinery should have a concrete justification and remain implementation details where possible. Existing GPU lifetime safety, completion/error delivery, residency, and resource retention must remain correct.

Context: reassessment of the design implemented in #410 and #411, not a request to restore those completed tasks.

- `2026-10-02T06:02:07Z`: Removed RecordedSubmission, Runner.record, Metal4SlotPool, generation leases, the separate recording identifier, and Metal4SubmissionPolicy. Runner.submit now encodes and commits as one operation; Runner.run also waits. Command buffers, allocators, scratch storage, and argument tables have direct internal ownership and are reused only after successful completion plus feedback. The internal encoding scope remains only for resource retention and encoder unwinding, not deferred ownership or slot management. Updated callers, tests, migration notes, and API snapshot. Validation: 763 tests pass; macOS/iOS/visionOS example builds pass; SwiftLint clean; API snapshot check passes; 41 targeted lifecycle tests pass with Metal API Validation. Null-buffer validation test failure tracked separately.

---

## 469: Hidden Metal 4 recording capacity determines observable API behavior

+++
status: closed
priority: high
kind: enhancement
labels: area:metal4, area:api
created: 2026-10-02T05:28:26Z
updated: 2026-10-02T06:02:07Z
closed: 2026-10-02T06:02:07Z
+++

Metal4Context defaults to three internal slots. Recorded but unsubmitted work and submitted work retain pool capacity. When no slot is available, Metal4SlotPool reports: "No Metal 4 recording slot is available. Discard unsubmitted work or retire completed submissions before recording again."

This couples resource reuse to execution policy. Callers can encounter an implementation-specific capacity limit and slot terminology that are not expressed by the declarative element tree. Multiple resource sets can support CPU/GPU overlap, but a fixed slot pool is a library choice rather than a Metal 4 concept.

Expected: buffering limits and backpressure have a clear execution contract, distinct from internal resource recycling. Normal capacity handling should not require knowledge of slots or leases. The contract must distinguish in-flight work that can complete from unsubmitted work that cannot be freed merely by waiting, while preserving bounded memory and safe GPU resource lifetimes.

Related: #410 introduced the current pool; #411 introduced retained recorded submissions.

- `2026-10-02T06:02:08Z`: Added explicit maximumInFlightSubmissions configuration to Runner, RenderView, and ImmersiveRenderContent (positive, default 3). Runner waits for earlier submissions at the limit; RenderView skips frames without blocking; immersive rendering asynchronously awaits capacity. Resource reuse is lazy and independent of indexed capacity or leases; no capacityExceeded error or outstanding unsubmitted tokens remain. Tests cover sustained submission beyond the limit, overlapping command buffers, timeout before new encoding, cancellation, dynamic limit reduction, view frame skipping/recovery, residency, and safe resource reuse. 763 tests pass and 41 targeted tests pass with Metal API Validation; all three platform builds pass.

---

## 470: Argument-table reuse test aborts under Metal API Validation on a null buffer binding

+++
status: closed
priority: medium
kind: bug
labels: area:metal4, area:tests
created: 2026-10-02T06:02:06Z
updated: 2026-10-02T06:27:41Z
closed: 2026-10-02T06:27:41Z
+++

Metal4ArgumentTablePoolTests.completed submissions reuse tables with cleared optional bindings intentionally leaves buffer index 2 null on alternating frames. The normal test run passes, but Metal API Validation aborts the process before the shader can check for nullptr.

Repro: env MTL_DEBUG_LAYER=1 xcb test --raw -- --filter Metal4ArgumentTablePoolTests

Assertion: Compute Function(inspect): Buffer binding at index 2 for optional cannot be null.

Expected: the argument-table reuse suite can verify cleared bindings with Metal API Validation enabled without aborting the test process.

Observed on macOS with Xcode 27 during verification of #468 and #469. The shader and null-binding scenario predate that refactor. The remaining 41 lifecycle/residency tests passed with validation enabled when this test was excluded.

- `2026-10-02T06:27:41Z`: Replaced the invalid null-buffer dispatch with alternating valid buffers (42 and 7), retaining GPU readback checks, argument-table identity reuse, and clearing of omitted texture-array entries. The test no longer attempts to read a missing required buffer. Verified: all 5 argument-table tests and all 42 targeted lifecycle/residency tests pass with MTL_DEBUG_LAYER=1, without exclusions; full suite passes 763 tests; macOS example build passes; SwiftLint clean.

---

## 471: Random tile-shaped corruption in a RenderView frame with a slow fragment shader

+++
status: open
priority: medium
kind: bug
labels: area:metal4, effort:l, deferred
created: 2026-10-02T15:19:38Z
updated: 2026-10-07T14:23:11Z
+++

SolarSystem (~/Shared/Projects/Scratch/SolarSystem) shows random rectangular pink or garbage blocks in RenderView output. The blocks change every frame with a still camera and nothing else changing. Sometimes the whole frame goes pink for one frame. They cluster on the Moon's lit side near the terminator. In Surface camera mode the whole screen can be garbage.

Frame structure: render pass 1 draws into a pooled rgba16Float HDR texture (cleared) with instanced impostor quads. Pass 2 is the view's render pass: a full-screen tone map that reads the HDR texture, then Slug text pipelines. QueueBarrier(after: .fragment, before: .fragment) at the start of pass 2. The HDR texture returns to its pool from onSubmissionFinished and is registered in a ResourceCollection. Per-frame uniforms, body array and draw list are bound with .parameter(value:) and .parameter(values:), which use scratch storage.

Evidence:
- The shaders use no frame index or random input, so per-frame variation means timing, not shader maths.
- The fragment shader ray-marches a heightmap (up to about 450 texture-sampling steps per pixel). Disabling that march mostly stops the corruption. Vertical exaggeration has no effect, because the step count does not depend on it. A slower GPU frame widens the window for a timing bug.
- Toggling overlay pipelines on or off (pipeline set change) triggers one to two bad frames.
- Offscreen rendering (Runner.run, one frame at a time) has never shown it. An 8-frame test that toggles the overlays is clean.
- API and shader validation report nothing. The barrier is visible in an Xcode GPU capture (pass 1 -> Barrier Fragment -> pass 2).
- It reproduced before #465 and #466 landed and after; both are now in use.

Looks fine on reading: scratch arenas and argument tables are reused only through retireCompletedSubmissions(), gated on completion.isRetiredSuccessfully. Not yet checked: whether isRetiredSuccessfully can become true before the GPU finishes, and whether anything handed out by a recording slot (scratch, argument tables, allocator) can be reused while an earlier submission is in flight.

Suggested next steps: a RenderView stress test with a deliberately slow fragment shader over many frames, checking for frame-to-frame variation; and a debug option to force one submission in flight to separate cross-frame races from everything else.

- `2026-10-05T23:14:53Z`: Closing as invalid for now. Reopen if the tile-shaped corruption reproduces again.
- `2026-10-06T21:27:26Z`: Reopening: pink/garbage output in RenderView is reported again, now also in MetalSprocketsGLTF's GLTFViewer (Metal 4). Workaround found by the user: set the MTKView's framebufferOnly to false (RenderView: .metalFramebufferOnly(false)), so the drawable's texture has usage beyond render target; with that the pink output goes away. GLTFViewer now has a 'Framebuffer Only' toggle in its Display tab for A/B testing (MetalSprocketsGLTF 191f1610). Guess, unverified: framebufferOnly drawables can use a different memory/compression (lossless or framebuffer-only) path, so this may be an interaction between Metal 4 drawable textures and how they are written or resolved (MSAA resolve, store actions, or reads of the drawable), rather than the fragment shader timing suspected above. Next: reproduce with framebufferOnly true vs false in the same app, with and without MSAA, and check a GPU capture for the drawable's usage and store/resolve actions.
- `2026-10-07T14:23:11Z`: Deferring for now.

---

## 472: Draw resets rasterizer state unconditionally, flooding API validation with redundant-call warnings

+++
status: open
priority: low
kind: bug
labels: area:metal4, effort:s, deferred
created: 2026-10-02T15:54:58Z
updated: 2026-10-06T06:28:54Z
+++

Draw.swift (around line 75) calls setCullMode(.none), setTriangleFillMode(.fill), setFrontFacing(.clockwise) and setVertexAmplificationCount(1) before every draw, so state set inside one Draw closure does not leak to the next.

Because the resets are unconditional, Metal API validation reports 'Redundant call to setCullMode / setTriangleFillMode / setVertexAmplificationCount' three times per draw, every frame (seen in SolarSystem with validation on). The real warnings get lost in the noise.

Fix: track the encoder's rasterizer state on the pass and only reset values that differ from the defaults, as applyDrawState already does for depth/stencil state and as viewportOverridden/scissorOverridden do for viewport and scissor. A Draw closure that changes the state directly is not visible to the pass, so either mark the state dirty after any Draw closure runs, or offer rasterizer modifiers (.cullMode, .fillMode, .frontFacing) that the pass tracks.

\- `2026-10-06T00:59:56Z`: Investigated. A Draw closure gets the raw MTL4RenderCommandEncoder and can call setCullMode etc. directly; the pass cannot observe that, so the unconditional reset is the only thing preventing leaks to sibling draws. Wrapping the encoder in a recording proxy is impractical (huge protocol surface).

Option A: rasterizer modifiers (.cullMode, .triangleFillMode, .frontFacing, .vertexAmplificationCount), tracked by the pass like applyDrawState; set only on change; drop the unconditional reset.
  + No redundant-call validation noise; declarative, matches depth/stencil modifiers.
  - Behaviour change: state set directly in a Draw closure leaks to later draws in the pass. Needs docs + migration of existing closures.

Option B: keep the reset, but skip it on the first draw of each pass (encoder starts at defaults).
  + No API or behaviour change; small.
  - Only removes noise for 1 draw per pass; multi-draw passes still warn.

Option C: modifiers as in A, but keep resetting after any Draw whose closure ran (pass marks rasterizer state dirty).
  + Leak protection kept.
  - Every Draw has a closure, so this resets every time: no reduction in noise. Not useful unless Draw grows a closure-free form.

Option D: leave as is; document that the warnings are expected.
  + Zero cost.
  - Real validation warnings stay buried.

Recommendation: A (possibly with B as a stopgap). Needs a decision on the leak behaviour change.

---

## 473: No Metal 4 support in Simulator

+++
status: open
priority: medium
kind: task
labels: effort:m, area:metal4, deferred
created: 2026-10-02T16:32:33Z
updated: 2026-10-06T06:28:54Z
+++

Metal 4 APIs are unavailable in the iOS/visionOS Simulator. Code paths relying on Metal 4 fail or can't be exercised there; need a fallback or to document/guard the limitation.

- `2026-10-05T22:29:40Z`: Umbrella for simulator support. Concrete build failures: #467 (visionOS Simulator), #478 (iOS Simulator).
- `2026-10-05T23:14:22Z`: Consolidated #467 (visionOS Simulator) and #478 (iOS Simulator) here as duplicates. The Simulator SDKs' MTL4*.h headers are empty stubs, so nearly all of the Metal layer fails to compile, not just the counter APIs. Decision needed: (a) document 'device/macOS only' in README + release notes, or (b) compile-only Simulator stub where elements throw 'Metal 4 unavailable' at runtime.

---

## 474: Public element modifier to attach a ResourceCollection (persistent residency)

+++
status: closed
priority: medium
kind: feature
labels: metal4, residency
created: 2026-10-02T20:15:52Z
updated: 2026-10-02T20:18:10Z
closed: 2026-10-02T20:18:10Z
+++

Elements cannot attach a persistent `ResourceCollection` or `MTLResidencySet` from inside the element tree. The only public entry point is `ResidencyConfiguration` at the root (`RenderView`, `Runner`, `OffscreenRenderer`).

Because of this, long-lived buffers go through the automatic `ResidencyTracker`. It reference-counts each allocation per submission. When frames retire before the next commit, the count drops to 0 and the allocation is removed, then added again on the next frame. A GPU trace of MetalSprocketsGaussianSplats shows about 15 `removeAllocation` calls + `commit`, then the same ~15 `addAllocation` calls + `commit`, on every frame. The buffers include Splats, SHCoefficients, CloudData and all the GPUSort scratch buffers.

Inside the framework, `MSAAModifier` and the function-table path already avoid this with `scope.useResourceCollection(_:)`. But `ScopeModifier` and `RecordingScope` are internal, so library code outside the framework (for example the splat pipelines) cannot do the same.

Proposed: add a public modifier, roughly:

```swift
public extension Element {
    func useResourceCollection(_ collection: ResourceCollection) -> some Element {
        ScopeModifier(content: self) { try $0.useResourceCollection(collection) }
    }
}
```

Maybe also add `useResidencySet(_:)` for externally owned sets.

Done when a pipeline element can register its persistent buffers in its own `ResourceCollection`, attach it with the modifier, and the per-frame add/remove churn is gone from the trace. Callers must not need any root-level `ResidencyConfiguration` wiring.

---

## 475: MSState initial values are evaluated on every element rebuild

+++
status: open
priority: medium
kind: enhancement
labels: area:metal4, area:performance, effort:s, needs-decision
created: 2026-10-02T22:35:16Z
updated: 2026-10-07T14:28:22Z
+++

MSState.init(wrappedValue:) (Core/State.swift:50) takes Value, not @autoclosure () -> Value. A default like '@MSState var mesh: MTKMesh = .teapot()', or an assignment to an @MSState in init, runs every time the element struct is rebuilt. That is usually every frame. The persisted StateBox wins and the new value is discarded, but the allocation still happens. In MetalSprocketsExamples this builds a teapot MTKMesh, a sphere, a 2048x2048 texture and a sampler every frame in BouncingTeapots, and MetalCanvas allocated 16 MB of buffers per frame (MetalSprocketsExamples #438). Proposal: add init(wrappedValue: @autoclosure @escaping () -> Value) and evaluate it only when no persisted state exists, like SwiftUI State. Assignments in init are harder to fix; at least document that they run every rebuild.

- `2026-10-02T22:35:30Z`: Prior art: https://github.com/pointfreeco/swiftui-lazy-state, a lazily initialized @State for SwiftUI. Its API and behavior are a good model for a lazy @MSState.
- `2026-10-05T22:42:35Z`: Tried the proposed init(wrappedValue: @autoclosure @escaping () -> Value) with a lazy StateBox (pending initializer evaluated on first read, outside the lock; snapshot shows '<not yet evaluated>'). Lazy evaluation works: a test counting evaluations across 5 rebuilds went 5 -> 1. Punting: an autoclosure-only init(wrappedValue:) breaks assigning the property in an initializer (e.g. OnChange: self.hasInitialized = false fails with 'used before being initialized'), which is a public source break for users who do the same. Keeping both init(wrappedValue: Value) and the autoclosure overload is ambiguous at every '@MSState var x = ...' site. Decision needed: (a) autoclosure-only, accept the source break and migrate in-init assignments to _x = MSState(wrappedValue:); or (b) keep init(wrappedValue:) as is and add a separate lazy API, e.g. @MSState(lazy: .teapot()) var mesh: MTKMesh. Either is ~1h once chosen; the StateBox change and test are ready to redo.
- `2026-10-07T14:25:00Z`: Auto-fixer punt: the StateBox lazy change + test are ready, but shipping requires choosing a public API shape: (a) autoclosure-only init(wrappedValue:) \u2014 fixes it cleanly but is a source break for users who assign @MSState in an initializer; or (b) additive, non-breaking @MSState(lazy: .teapot()). This is a maintainer API decision, not inferable from code. Recommend (b) (non-breaking, ~1h to land). Tell me which and I'll implement.

---

## 476: Argument tables are rebuilt and fully re-bound for every draw on every frame

+++
status: open
priority: high
kind: enhancement
labels: area:metal4, area:performance, effort:l, needs-decision
created: 2026-10-03T00:16:32Z
updated: 2026-10-07T14:28:22Z
+++

Potential performance issue, not measured.

On the Metal 4 path, every draw gets fresh argument tables on every frame, and every parameter is bound again, even when the pipeline and its parameters have not changed since the last frame.

Seen in Metal4Parameters.makeTables: for each stage it calls scope.argumentTable(sizes:label:), then binds every entry, function table, and vertex buffer.

Impact is probably small for scenes with few draws. For example, SolarSystem has 2 to 8 draws per frame. It could matter for scenes with many draws or many parameters per draw.

Unknown:
- The real CPU cost per draw. It has not been profiled.
- Whether reusing tables across draws or frames is safe while the GPU is still using an earlier submission.

Found while debugging SolarSystem #36.

- `2026-10-05T22:35:19Z`: Looked at ArgumentTablePool/ParameterSet.makeTables. Tables are already pooled per recording slot (#465); the remaining per-draw cost is clearing slots plus setAddress/setTexture calls. Punting: skipping re-binds needs per-slot change tracking, value:/values: get new scratch addresses every frame (so they must be re-bound regardless), and cross-frame reuse safety is entangled with the unexplained in-flight race in #471. The only profile so far (#479, GLTFViewer) showed reconciliation, not binding, as the hot spot; that is now reduced (#479, #480). Unblocker: a Time Profiler capture after #479/#480 showing makeTables/acquire as significant, or a decision to drop this to Low until then.
- `2026-10-07T14:24:29Z`: Auto-fixer punt: no actionable code change without evidence. Per the prior analysis, tables are already pooled (#465) and the remaining re-binds are required because value:/values: get fresh scratch addresses each frame; cross-frame reuse safety is entangled with #471 (now deferred). Unblocker: a Time Profiler capture showing makeTables/acquire as a real hot spot, or a decision to drop this to Low until then.

---

## 477: Content inside .debugGroup can be reused from an earlier frame

+++
status: closed
priority: high
kind: bug
labels: area:metal4, effort:s
created: 2026-10-03T00:29:21Z
updated: 2026-10-05T22:30:50Z
closed: 2026-10-05T22:30:50Z
+++

Metal4DebugGroupModifier is Equatable, and its == compares only `label`. It ignores `content`:

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.label == rhs.label
    }

TreeReconciler treats an element that compares equal to the previous frame's element as unchanged. If the node is not dirty, it splices in the previous subtree "wholesale: no body evaluation, no child walk". So an element inside `.debugGroup(...)` can keep an earlier frame's version even when its parameters changed, for example a different texture, buffer, or `value:`/`values:` data.

Seen in SolarSystem (PinkReproView, SolarSystem #36):
- Two render passes per frame: bodies into a pooled HDR texture, then a tone map into the drawable. Each pipeline is wrapped in `.debugGroup`. 3 frames in flight.
- Result: every other frame is black. Every submission completes without error.
- Removing the two `.debugGroup` modifiers stops the flicker. Nothing else changes.
- The flicker stays when the fragment shader returns a constant colour.

Not verified directly: which stale binding is used. The conclusion comes from the code path above and the before/after result.

Possibly related: SolarSystem #36, random pink tile-shaped garbage, also uses `.debugGroup` around every pipeline. Not yet confirmed.

Expected: content inside `.debugGroup` updates when its parameters change.
Actual: content inside `.debugGroup` can be reused from an earlier frame.

- `2026-10-03T00:30:51Z`: DepthBiasModifier has the same pattern. It wraps content, but == compares only depthBias, slopeScale and clamp. Used by MetalSprocketsAddOns GridShader and ShadowMapRenderPipeline. Removing the debugGroups did NOT fix SolarSystem #36 (pink tiles), so #36 has a different cause. This issue is confirmed only for the flicker in PinkReproView.
- `2026-10-05T22:30:51Z`: Already fixed in wnusnwlx (0.2.0): removed the custom Equatable conformances from DebugGroupModifier and DepthBiasModifier so reconciliation compares content. Regression tests: ModifierContentReconciliationTests. Full suite passes.

---

## 478: MetalSprockets does not compile for the iOS Simulator

+++
status: closed
priority: medium
kind: bug
labels: ios, simulator, effort:s, area:metal4
created: 2026-10-05T16:00:32Z
updated: 2026-10-05T23:14:22Z
closed: 2026-10-05T23:14:22Z
+++

Building any app that depends on MetalSprockets 0.2.0 for the iOS Simulator fails. The Metal 4 counter APIs are not in the simulator SDK:

```
MetalSprockets/Metal/GPUTimestampSampling.swift:24:23: cannot find type 'MTL4CounterHeap' in scope
MetalSprockets/Metal/GPUTimestampSampling.swift:34:38: type 'MTLGPUFamily' has no member 'metal4'
MetalSprockets/Metal/GPUTimestampSampling.swift:37:32: value of type 'any MTLDevice' has no member 'queryTimestampFrequency'
MetalSprockets/Metal/GPUTimestampSampling.swift:52:26: cannot find 'MTL4CounterHeapDescriptor' in scope
MetalSprockets/Metal/GPUTimestampSampling.swift:55:31: value of type 'any MTLDevice' has no member 'makeCounterHeap'
```

macOS and iOS device builds succeed. Found via MetalSprocketsGLTF's GLTFViewer demo (Xcode 27.0, iPhone 18 Pro Max simulator, iOS 27.0). Unclear whether simulator support is intended for 0.2.0; if not, it isn't documented.

- `2026-10-05T22:29:41Z`: Related: #473 (umbrella) and #467 (visionOS Simulator).
- `2026-10-05T22:40:35Z`: Reproduced with Xcode 27.0 RC (iphonesimulator27.0 SDK): the failure is not limited to the counter APIs. The simulator SDK's MTL4*.h headers are empty stubs (e.g. MTL4CommandBuffer.h declares nothing), so MTL4CommandBuffer, MTL4ArgumentTable, MTL4CommandAllocator, MTL4VisibilityOptions, MTL4ComputeCommandEncoder, etc. are all missing; errors span ArgumentTablePool, CommandResources, BarrierElements, ComputeDispatch and more. Guarding GPUTimestampSampling alone would just surface the next 100 errors. Punting: supporting the simulator means compiling out (or stubbing) essentially the whole Metal layer behind #if !targetEnvironment(simulator), which is the #473 decision. Unblocker: decide between (a) documenting 'device/macOS only, no Simulator' in README + release notes, or (b) a compile-only simulator stub where elements throw 'Metal 4 unavailable' at runtime.
- `2026-10-05T23:14:22Z`: Duplicate of #473. Same root cause: the Simulator SDKs ship no Metal 4 (MTL4 headers are empty stubs). Details in this issue's earlier comment.

---

## 479: Reconciliation compares whole subtrees by reflection at every container node

+++
status: closed
priority: high
kind: bug
labels: area:performance, area:metal4, effort:l
created: 2026-10-05T22:25:14Z
updated: 2026-10-05T22:32:36Z
closed: 2026-10-05T22:32:36Z
+++

System.shouldUpdateNode calls isEqual(node.element, element) for every node. For non-Equatable elements, isEqualStructurally (Support/isEqual.swift) uses Mirror to compare every stored property, including a container's content, which is its entire subtree. Every container node (RenderPass, RenderPipeline, ForEach, Group, each ParameterModifier) does this again for its own subtree, so the cost grows roughly quadratically with tree depth, and each step is reflection plus Any casts.

Evidence: a Time Profiler capture of the MetalSprocketsGLTF GLTFViewer demo (Release; ABeautifulGame chess scene) spends about 74% of main-thread time in isEqualStructurally / isEqualStoredProperty under TreeReconciler.processElement. Self time is mostly Swift runtime reflection: swift_conformsToProtocol, tryCast, metadata demangling, Mirror. The scene has about 28 draws, each wrapped in a chain of about 45 nested .parameter modifiers. The GPU needs only about 1.4 ms per frame. Trace: /Users/schwa/Desktop/Chess.trace (GPU trace: /Users/schwa/Desktop/Chess.gputrace). See MetalSprocketsGLTF #69.

- `2026-10-05T22:29:41Z`: Related: #480 (each .parameter adds a nesting level, which makes this worse).
- `2026-10-05T22:32:36Z`: isEqualStructurally now compares stored Element fields last, so a cheap differing field (e.g. ParameterModifier's apply closure) short-circuits before walking the subtree; and the reconciler computes isEqual once per node instead of twice (shouldUpdateNode removed). ReconciliationCostTests: a 20-deep closure-modifier chain compares its leaf once per update (was many times). Remaining: containers whose non-content fields are all equal still compare content; not re-profiled in GLTFViewer.

---

## 480: No way to bind several parameters with one modifier

+++
status: closed
priority: high
kind: enhancement
labels: area:api, area:performance, area:metal4, effort:m
created: 2026-10-05T22:25:14Z
updated: 2026-10-05T22:35:00Z
closed: 2026-10-05T22:35:00Z
+++

Each .parameter(...) call adds one modifier element. A draw that binds a full PBR material (about 15 textures, 15 samplers and several buffers in MetalSprocketsGLTF) becomes a chain of about 45 nested modifiers per draw. Every one of them is an element to rebuild and reconcile each frame. The deep nesting also makes structural-equality reconciliation expensive (see the reconciliation issue filed alongside this one). There is no public modifier that takes a set of bindings at once, for example a ParameterSet or a dictionary of named values.

- `2026-10-05T22:29:42Z`: Related: #479 (reconciliation cost grows with nesting depth).
- `2026-10-05T22:35:01Z`: Added public ShaderParameters and Element.parameters { $0.set(...) }: one ParameterModifier for any number of bindings, with set overloads matching .parameter labels. Inner modifiers still override. Tests: ShaderParametersTests.

---

## 481: Residency set removes and re-adds the same allocations every frame

+++
status: closed
priority: low
kind: bug
labels: effort:s
created: 2026-10-06T19:20:22Z
updated: 2026-10-06T19:40:39Z
closed: 2026-10-06T19:40:39Z
+++

When a frame's previous submission has already completed (the usual case for a light scene at display rate), every frame removes all of its allocations from the context residency set, commits, re-adds the same allocations and commits again. Seen in a GPU capture of MetalSprocketsGLTF's GLTFViewer: per frame, removeAllocation x6 (environment maps, BRDF lookup, transmission targets), commit, MTL4CommandAllocator reset, addAllocation x6 (the same textures), commit.

Cause: MetalContext.submit calls retireCompletedSubmissions() before residency.acquire(...) (MetalContext.swift ~160-234). Retiring releases the previous frame's allocations; ResidencyTracker.release drops each to zero uses, removes it and commits; acquire then adds them back and commits. The set is correct, but a steady scene makes 2 residency commits and 2N add/remove calls per frame instead of none.

Cost: unmeasured on the CPU. #436 (2026-09-30) tested this churn as a cause of GPU frame time and rejected it (no GPU change with removals disabled); CPU time and the commits themselves were not measured. Apple's residency-set guidance is to avoid frequent commits.

Possible fixes: acquire the new frame's allocations before retiring completed submissions; or defer removals (collect zero-use allocations and remove only those not re-acquired by the next submit, committing once); or keep a small grace period. Acceptance: a steady scene rendered repeatedly makes no residency-set changes or commits after the first frame (testable by counting calls in ResidencyTracker); allocations still leave the set once no live submission uses them.

- `2026-10-06T19:40:39Z`: Fixed by deferring residency release so a steady scene makes no residency-set churn.

---

## 482: Immersive runtime presents frames before world tracking runs

+++
status: closed
priority: low
kind: bug
labels: area:visionos, effort:s
created: 2026-10-07T01:37:37Z
updated: 2026-10-07T14:27:13Z
closed: 2026-10-07T14:27:13Z
+++

On device, the first frames after opening an immersive space (ImmersiveRenderContent) log, once per frame: 'ar_world_tracking_provider_query_device_anchor_at_timestamp: The device_anchor can only be queried when the world tracking provider is running.' followed by 'Presenting a drawable without a device anchor. This drawable won't be presented.' Seen from MetalSprocketsGLTF's GLTFViewer on Vision Pro (visionOS 27). The runtime queries the device anchor and encodes/presents before the WorldTrackingProvider reaches .running; those frames are wasted and the log is noisy. Wanted: skip rendering (or wait) until world tracking is running, and only present drawables that have a device anchor.

- `2026-10-07T14:27:13Z`: Fixed: renderFrame now skips frames until worldTracking.state == .running, and bails (frame.endSubmission) when queryDeviceAnchor returns nil instead of presenting an anchorless drawable. Eliminates the per-frame 'device_anchor can only be queried when world tracking is running' and 'presenting a drawable without a device anchor' logs on device startup. No unit test: this is visionOS device-only code (#if os(visionOS), simulator throws, requires a live WorldTrackingProvider), not reachable from the macOS unit suite. Verified by compiling for visionOS device (xcb build --destination vision).

---

## 483: Unify RenderView modifiers and Runner/OffscreenRenderer config

+++
status: open
priority: low
kind: enhancement
labels: effort:m, area:api
created: 2026-10-07T01:51:42Z
updated: 2026-10-07T14:14:55Z
+++

RenderView configures its Metal context through SwiftUI view modifiers backed by EnvironmentValues (`.device`, `.commandQueue`, `.shaderStore`, `.metalShaderLogging`, `.renderViewLogFrame`, `.renderViewFatalErrorOnError`). Runner and OffscreenRenderer configure the same underlying context through init parameters (device, commandQueue, shaderLogging, residency, maximumInFlightSubmissions; plus size/colorUsage/depthUsage/clearDepth for OffscreenRenderer).

These are two parallel configuration APIs for the same MetalContext knobs. We should unify.

Two sketched options:

1. Chainable modifier methods on the structs (cheap, no SwiftUI). Keep a minimal init and add copy-returning methods so you get the modifier feel:

    let renderer = try OffscreenRenderer(size: size)
        .shaderLogging(.off)
        .commandQueue(queue)

   Mirrors the ergonomics but stays a parallel API.

2. Shared config struct (deeper, preferred). Introduce one non-SwiftUI configuration value in the core MetalSprockets module (e.g. MetalContextConfiguration: device, commandQueue, shaderLogging, shaderStore, residency, diagnostics). Runner and OffscreenRenderer take it directly; RenderView\u2019s SwiftUI modifiers populate the same struct from the environment at setup time.

Constraint: the EnvironmentValues keys live in MetalSprocketsUI and import SwiftUI, while Runner/OffscreenRenderer live in MetalSprockets (no SwiftUI dependency). The modifiers themselves cannot be literally shared across modules \u2014 only the config value can. The modifiers stay as thin SwiftUI wrappers that feed the shared struct.

Next step: decide between option 1 and option 2 before implementing.

---

## 484: Priority inversion in MetalContext.waitForResult

+++
status: closed
priority: medium
kind: bug
created: 2026-10-07T15:12:15Z
updated: 2026-10-07T16:08:06Z
closed: 2026-10-07T16:08:06Z
+++

Xcode runtime/thread warning on the semaphore wait in `MetalContext.waitForResult(_:timeout:)` (Sources/MetalSprockets/Metal/MetalContext.swift):

> Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions.

The function blocks a UI-interactive caller on a `DispatchSemaphore` that is signaled from a lower-QoS (Default) thread via `submission.onTerminated`, creating a priority inversion.

Investigate ways to avoid it, e.g. raising the QoS of the completion/notification path, or restructuring so the high-QoS caller doesn't block on a lower-QoS worker.

- `2026-10-07T16:08:06Z`: Fixed: completion callbacks now delivered on a user-interactive queue.

---
