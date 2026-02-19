## 11: Address Type Safety
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

The elephant in room here is that UV is not as type safe as it should be.

With SwiftUI you can make up almost any combination of View and pass it as content to another view and you will get runnable (albeit maybe bad…) UI.

With UV you can't do that - you can make an utter nonsense element graph that is meaningless - that will compile but will either not do anything or crash (due to elements not being set up the way they need).

The same kind of thing exists in SwiftUI where views like TableView _expect_ TableRows/TableColumns.

We need to try and copy this.

This may mean we need _more_element builder types (in the same way I think SwiftUI has TableRowBuilder etc)

*Imported from #3*

---

## 13: Improve ParameterValues
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

It would be nice if `ParameterValues` had better constructors so that we know 2nd parameter of `.buffer(…, …)` is an offset in the buffer and to get rid of the `T` generic parameter.

Make make this a struct… that takes closures that will call `MTLXXXCommandEncoder.setXXXX` appropriately.

*Imported from #5*

---

## 19: Merge ComputePass.compute() & OffscreenRenderer into one thing
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

*Imported from #11*

---

## 20: Break OffscreenRenderer into renderer & render session
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

*Imported from #12*

---

## 22: ElementModifier is not a true Element.
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

*Imported from #14*

---

## 25: OffscreenRenderer should be more configurable
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

*Imported from #17*

---

## 31: Make shaders/kernels modifiers
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

By default a vertex and fragment shader should be a modifier instead of a parameter

Right now we have `RenderPipeline(vertexShader, fragmentShader)` - it would be better to do `RenderPipeline().vertexShader(xxx).fragementShader(xxx)` where the shaders get stored in the environment.

This allows shaders to be propagated through environment and override if needed? (maybe - is this actually a useful thing?)

WE can also provide an init method on RenderPipeline that works the same as before.

Also make this change on compute shaders.

*Imported from #23*

---

## 32: Re-visit MainActor usage through UV
status: open
priority: none
kind: none
labels: concurrency, effort:l
created: 2026-02-19

*Imported from #24*

---

## 33: Provide a nice way to get FPS programmatically
status: open
priority: none
kind: none
labels: effort:s
created: 2026-02-19

*Imported from #25*

---

## 34: Investigate flickering of Metal FPU counter
status: open
priority: none
kind: none
labels: effort:m
created: 2026-02-19

*Imported from #26*

---

## 38: Rename CommandBufferElement
status: open
priority: none
kind: none
labels: effort:s
created: 2026-02-19

In file Sources/Ultraviolence/CommandBufferElement.swift
https://github.com/schwa/Ultraviolence/blob/ebd49f199dbed51331e10ecaf7f9602f391f1d94/Sources/Ultraviolence/CommandBufferElement.swift#L4

*Imported from #30*

---

## 42: Do we need DynamicProperty?
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

```
// TODO: SwiftUI.Environment adopts DynamicProperty.
```

In file Sources/Ultraviolence/Core/UVEnvironmentValues.swift
https://github.com/schwa/Ultraviolence/blob/ebd49f199dbed51331e10ecaf7f9602f391f1d94/Sources/Ultraviolence/Core/UVEnvironmentValues.swift#L76

*Imported from #34*

---

## 44: Compute the correct threadsPerThreadgroup
status: open
priority: none
kind: none
labels: effort:m
created: 2026-02-19

In file Sources/UltraviolenceExamples/CheckerboardKernel.swift
https://github.com/schwa/Ultraviolence/blob/ebd49f199dbed51331e10ecaf7f9602f391f1d94/Sources/UltraviolenceExamples/CheckerboardKernel.swift#L23

*Imported from #35*

---

## 46: Make MTLTexture.toCGImage() robust
status: open
priority: none
kind: none
labels: effort:s
created: 2026-02-19

```
        // TODO: Hack
```

In file Sources/UltraviolenceSupport/MetalSupport.swift
https://github.com/schwa/Ultraviolence/blob/ebd49f199dbed51331e10ecaf7f9602f391f1d94/Sources/UltraviolenceSupport/MetalSupport.swift#L650

*Imported from #38*

---

## 48: Add labels to everything
status: open
priority: none
kind: none
labels: effort:s
created: 2026-02-19

*Imported from #40*

---

## 49: Revisit MTLCaptureManager
status: open
priority: none
kind: none
labels: effort:m
created: 2026-02-19

*Imported from #41*

---

## 50: Provide a hook for GPU counters
status: open
priority: none
kind: none
labels: effort:m
created: 2026-02-19

*Imported from #42*

---

## 51: Sanitize all debug groups and resource labels
status: open
priority: none
kind: none
labels: effort:s
created: 2026-02-19

*Imported from #43*

---

## 53: add disabled() modifier
status: open
priority: none
kind: none
labels: effort:s
created: 2026-02-19

This is akin to .hidden() in SwiftUI.

*Imported from #45*

---

## 54: Put parameters into one RenderPass object instead of having a bunch of nested ParameterRenderPasss
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

Put parameters into one RenderPass object instead of having a bunch of nested `ParameterRenderPass`

This simple render pass becomes this giant stack of nested passes:

```
              let compute = try Compute(logging: true) {
                ComputePipeline(computeKernel: kernel) {
                    ComputeDispatch(threads: .init(width: count, height: 1, depth: 1), threadsPerThreadgroup: .init(width: 1_024, height: 1, depth: 1))
                    .parameter("src", buffer: inputBuffer)
                    .parameter("dst", buffer: outputBuffer)
                }
            }
```


```
Compute<ComputePipeline<ParameterRenderPass<ParameterRenderPass<ComputeDispatch, ()>, ()>>> [Env: 3]
  ComputePipeline<ParameterRenderPass<ParameterRenderPass<ComputeDispatch, ()>, ()>> [Env: 5]
    ParameterRenderPass<ParameterRenderPass<ComputeDispatch, ()>, ()> [Env: 5]
      ParameterRenderPass<ComputeDispatch, ()> [Env: 5]
        ComputeDispatch [Env: 5]
```

*Imported from #46*

---

## 55: Handle MTLCreateSystemDefaultDevice() everywhere
status: open
priority: none
kind: none
labels: effort:s
created: 2026-02-19

*Imported from #47*

---

## 59: Shader Graph
status: open
priority: none
kind: none
labels: effort:xl
created: 2026-02-19

*Imported from #51*

---

## 61: Make API match SwiftUI shader API a little better (parameter vs argument etc)
status: open
priority: none
kind: none
labels: effort:m
created: 2026-02-19

*Imported from #53*

---

## 62: Need some kind of `setNeedsUpdate`
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

*Imported from #54*

---

## 67: Formalize element Input and Output
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

It's confusing what parts of the Metal stack core elements are responsible for.

We can formalize this with an extension on Node that allows us to take input from environment and add output to it.

We can use parameter packs to get/set the environment keys we need to read/write.

*Imported from #59*

---

## 70: Improve Attachment flow
status: open
priority: none
kind: none
labels: effort:l
created: 2026-02-19

We need a nice clean way to allow the user to customise attachments incl (but not limited to) color, depth, stencil etc.

*Imported from #62*

---

## 73: Fix all SwiftLint disable comments
status: open
priority: none
kind: none
created: 2026-02-19

*Imported from #65*

---

## 76: Decide what to do with https://github.com/schwa/Compute
status: open
priority: low
kind: none
labels: effort:m, priority:low
created: 2026-02-19

*Imported from #68*

---

## 77: Rethink ACL of UltraviolenceSupport
status: open
priority: none
kind: none
labels: effort:m
created: 2026-02-19

*Imported from #69*

---

## 79: Async shader compilation.
status: open
priority: none
kind: none
labels: effort:xl, concurrency
created: 2026-02-19

*Imported from #71*

---

## 81: Clean up all Metal extension code - especially stuff on buffers etc to make sure it's not being stupid.
status: open
priority: none
kind: none
labels: effort:m
created: 2026-02-19

*Imported from #73*

---

## 82: Emit OS logging POIs for each frame
status: open
priority: none
kind: none
labels: effort:s
created: 2026-02-19

/*
    var poi = OSSignposter(subsystem: “…”, category: .pointsOfInterest)
    let id = poi.makeSignpostID()
    let state = poi.beginInterval(#function, id: id, “\(value)”)
    poi.endInterval(#function, state)
    */




*Imported from #74*

---

## 86: Clean up shader function lookup in ShaderLibrary
status: open
priority: none
kind: none
labels: effort:m, source:todo
created: 2026-02-19

Found in Sources/Ultraviolence/ShaderLibrary.swift at line 47

*Imported from #78*

---

## 89: Users cannot modify the environment here. This is a problem.
status: open
priority: none
kind: none
labels: effort:l, source:todo
created: 2026-02-19

Found in Sources/Ultraviolence/CommandBufferElement.swift at line 20

*Imported from #81*

---

## 90: There isn't an opportunity to modify the descriptor here.
status: open
priority: none
kind: none
labels: effort:l, source:todo
created: 2026-02-19

Found in Sources/Ultraviolence/CommandBufferElement.swift at line 25

*Imported from #82*

---

## 91: is this actually necessary? Elements just use an environment?
status: open
priority: none
kind: none
labels: effort:m, source:todo
created: 2026-02-19

Found in Sources/Ultraviolence/RenderPipelineDescriptorModifier.swift at line 4

*Imported from #83*

---

## 95: This is copying everything from the render pass descriptor. But really we should be getting this entirely from the enviroment.
status: open
priority: none
kind: none
labels: effort:l, source:todo
created: 2026-02-19

Found in Sources/Ultraviolence/RenderPipeline.swift at line 41

*Imported from #87*

---

## 102: Also it could take a SwiftUI environment(). Also SRGB?
status: open
priority: none
kind: none
labels: effort:m, source:todo
created: 2026-02-19

Found in Sources/UltraviolenceUI/Parameter+SwiftUI.swift at line 4

*Imported from #94*

---

## 104: ViewAdaptor should be internal but is currently used externally
status: open
priority: none
kind: none
labels: source:todo, blocked
created: 2026-02-19

Found in Sources/UltraviolenceUI/ViewAdaptor.swift at line 4

*Imported from #96*

---

## 106: This is messy and needs organisation and possibly deprecation of unused elements.
status: open
priority: none
kind: none
labels: effort:m, source:todo
created: 2026-02-19

Found in Sources/Ultraviolence/UVEnvironmentValues+Implementation.swift at line 6

*Imported from #98*

---

## 112: Reduce MTLTexture descriptor usage flags to only necessary ones
status: open
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19

Found in Sources/UltraviolenceSupport/MetalSupport.swift at line 758

*Imported from #104*

---

## 113: Fix hardcoded texture loading in MetalSupport
status: open
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19

Found in Sources/UltraviolenceSupport/MetalSupport.swift at line 767

*Imported from #105*

---

## 119: Fix same parameter name with both shaders.
status: open
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Support/Transforms.swift at line 26

*Imported from #111*

---

## 122: Remove duplicate projection implementations
status: open
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Support/Projection.swift at line 39

*Imported from #114*

---

## 126: Make generic for any VectorArithmetic and add a transform closure for axis handling?
status: open
priority: none
kind: none
labels: effort:m, source:todo
created: 2026-02-19

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Interaction/DraggableValueViewModifier.swift at line 20

*Imported from #118*

---

## 127: DragGestures' predictions are mostly junk. Refactor to this to keep own prediction logic.
status: open
priority: none
kind: none
labels: effort:m, source:todo
created: 2026-02-19

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Interaction/DraggableValueViewModifier.swift at line 69

*Imported from #119*

---

## 128: Remove offscreen-specific texture setup from general rendering code
status: open
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/ExampleElements/MixedExample.swift at line 29

*Imported from #120*

---

## 129: Flesh out Packed3 implementation
status: open
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19

Packed3 should work identically to SIMD3. We need to flesh it out with more operators etc.

*Imported from #121*

---

## 137: Add unit tests for `ElementBuilder.buildEither`.
status: open
priority: none
kind: none
labels: effort:s, source:todo, testing
created: 2026-02-19

Found in Sources/Ultraviolence/Core/ElementBuilder.swift at line 22

*Imported from #129*

---

## 138: Dangerous `@unchecked Sendable` usage in SplatCloud and SplatIndices
status: open
priority: none
kind: none
labels: effort:s, concurrency, source:todo
created: 2026-02-19

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

---

## 142: OffscreenRenderer creates own command buffer without giving us a chance to intercept
status: open
priority: none
kind: none
labels: effort:l, source:todo
created: 2026-02-19

Found in Tests/UltraviolenceTests/RenderTests.swift at line 60

*Imported from #134*

---

## 145: Get code coverage to 80%
status: open
priority: none
kind: none
labels: effort:xl, testing
created: 2026-02-19

*Imported from #137*

---

## 146: Get code coverage to 100%
status: open
priority: none
kind: none
labels: effort:xl, testing
created: 2026-02-19

*Imported from #138*

---

## 147: Generate docc and host on swift packages
status: open
priority: none
kind: documentation
labels: documentation, effort:xl
created: 2026-02-19

*Imported from #139*

---

## 148: Header docs
status: open
priority: none
kind: documentation
labels: documentation, effort:xl
created: 2026-02-19

*Imported from #140*

---

## 149: Tutorials
status: open
priority: none
kind: documentation
labels: documentation, effort:xl
created: 2026-02-19

*Imported from #141*

---

## 150: Screencast
status: open
priority: low
kind: documentation
labels: documentation, priority:low, effort:xl
created: 2026-02-19

*Imported from #142*

---

## 152: Add onWorkloadExit modifier for all Elements
status: open
priority: none
kind: none
labels: effort:s, source:todo
created: 2026-02-19

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
status: open
priority: none
kind: enhancement
labels: enhancement, demo
created: 2026-02-19

## Summary
Port the barrel distortion post-processing effect to demonstrate image distortion capabilities in Ultraviolence.

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

---

## 170: Replace custom MDLVertexDescriptor to MTLVertexDescriptor conversion with MTKMetalVertexDescriptorFromModelIO
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

Currently in MetalSupport.swift, we have a custom convenience initializer that converts MDLVertexDescriptor to MTLVertexDescriptor. MetalKit provides MTKMetalVertexDescriptorFromModelIO() for this exact purpose. We should replace our custom implementation with the official API.

Found in Sources/UltraviolenceSupport/MetalSupport.swift

The custom implementation manually iterates through attributes and layouts, converting formats and copying offsets. This should be replaced with a call to MTKMetalVertexDescriptorFromModelIO().

*Imported from #162*

---

## 171: Might as well make vertex descriptor a parameter to Render
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

*Imported from #163*

---

## 172: Might as well make vertex descriptor a parameter to RenderPipeline
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

*Imported from #164*

---

## 174: Parent chain in UVEnvironmentValues.Storage may be unnecessary
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

## Current State
After fixing #68, we now always create fresh Storage instances for each node to prevent cycles. This raises the question of whether the parent chain is still necessary.

## Observations
1. Each node now gets its own fresh UVEnvironmentValues with its own Storage instance
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
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

*Imported from #169*

---

## 180: Fix swiftlint warnings (again)
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

*Imported from #172*

---

## 184: Bring back modifiers
status: open
priority: none
kind: feature
labels: feature
created: 2026-02-19

*Imported from #176*

---

## 186: Investigate reducing closure usage in modifiers
status: open
priority: none
kind: none
labels: effort:m
created: 2026-02-19

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

---

## 187: Add id modifier for explicit identity
status: open
priority: none
kind: none
labels: effort:m
created: 2026-02-19

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
status: open
priority: none
kind: none
created: 2026-02-19

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

---

## 194: Do we need activeNodeStack or just activeNode
status: open
priority: none
kind: none
created: 2026-02-19

*Imported from #186*

---

## 196: Optimize: Unused bindings cause unnecessary child rebuilds
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

## Problem

When a binding is passed to a child element but not actually used in the child's body, the child still rebuilds when the parent's state changes. This is an unnecessary performance penalty.

## Root Cause

The issue is in how `UVBinding` equality works:
- Each `UVBinding` has a UUID that's created when initialized
- When the parent rebuilds its body due to state change, it creates a new child element instance with the binding
- Even though the binding points to the same underlying `StateBox`, the `UVBinding` comparison sees them as different because of different UUIDs
- This causes the system to think the child element has changed and needs rebuilding

## Test Case

```swift
// MARK: - Unused Binding Test

struct UnusedBindingParent: Element {
    @UVState var value = 0
    
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
    @UVBinding var value: Int
    
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

Modify `UVBinding` equality to compare based on the underlying state source rather than a UUID:
1. Add a `sourceIdentifier` property to track the underlying StateBox
2. Update StateBox to pass its ObjectIdentifier when creating bindings  
3. Fix equality comparison to compare sourceIdentifiers instead of UUIDs

This would ensure that bindings pointing to the same state source are considered equal, preventing unnecessary rebuilds.

## Impact

This is a performance optimization - the current behavior is functionally correct but causes unnecessary work.

*Imported from #188*

---

## 197: Optimize: Elements without parameters rebuild unnecessarily
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

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
    @UVState var counter = 0
    
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

---

## 200: Get unit test coverage to 60%
status: open
priority: none
kind: none
created: 2026-02-19

*Imported from #192*

---

## 202: Batteries included
status: open
priority: none
kind: feature
labels: feature
created: 2026-02-19

Create a target of standard shaders and pipelines that user can immediately use. 

Flat shaders. Basic PBR. MetalFX. Etc etc. 

*Imported from #194*

---

## 209: Use IDs in System StructuralIdentifier for ForEach
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

In ForEach.swift:24, there's a TODO noting that we're not using IDs in the System StructuralIdentifier yet. This should be implemented to properly track ForEach elements.

File: Sources/Ultraviolence/Core/ForEach.swift:24

*Imported from #201*

---

## 210: Handle errors in StateBox getter/setter
status: open
priority: none
kind: bug
labels: bug
created: 2026-02-19

StateBox has TODO comments about error handling in the getter and setter methods. Need to determine proper error handling strategy.

Files: 
- Sources/Ultraviolence/Core/StateBox.swift:57
- Sources/Ultraviolence/Core/StateBox.swift:62

*Imported from #202*

---

## 212: Pass Node as parameter to EnvironmentReader
status: open
priority: none
kind: none
created: 2026-02-19

EnvironmentReader should ideally be passed a Node as a parameter as noted in the TODO.

File: Sources/Ultraviolence/Core/EnvironmentReader.swift:18

*Imported from #204*

---

## 213: Make System properties private
status: open
priority: none
kind: none
created: 2026-02-19

System class has properties that need to become private as noted in the TODO.

File: Sources/Ultraviolence/Core/System.swift:4

*Imported from #205*

---

## 214: Call cleanup/onDisappear for removed nodes
status: open
priority: none
kind: none
created: 2026-02-19

System could call cleanup/onDisappear when nodes are removed. Currently just notes they're gone.

File: Sources/Ultraviolence/Core/System.swift:121

*Imported from #206*

---

## 216: Rename Element+SystemExtensions file
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

The Element+SystemExtensions file needs to be renamed to better reflect its purpose.

File: Sources/Ultraviolence/Core/Element+SystemExtensions.swift:2

*Imported from #208*

---

## 217: Clarify purpose of AnyBodylessElement extensions
status: open
priority: none
kind: none
created: 2026-02-19

There are extensions in AnyBodylessElement whose purpose is unclear. Need to investigate and document or remove.

File: Sources/Ultraviolence/Core/AnyBodylessElement.swift:32

*Imported from #209*

---

## 218: Fix dangerous tree walking in Element+Dump
status: open
priority: none
kind: bug
labels: bug
created: 2026-02-19

Walking the tree in Element+Dump can modify state which is dangerous. Elements like EnvironmentReader can break things. Need to only walk the System tree instead.

Files:
- Sources/Ultraviolence/Core/Element+Dump.swift:1
- Sources/Ultraviolence/Core/Element+Dump.swift:2

*Imported from #210*

---

## 219: Evaluate if AnyElement is still needed
status: open
priority: none
kind: none
created: 2026-02-19

Need to determine if AnyElement is still needed in the codebase.

File: Sources/Ultraviolence/Core/AnyElement.swift:1

*Imported from #211*

---

## 222: More labels.
status: open
priority: none
kind: none
labels: effort:s
created: 2026-02-19

We've explicit labels to computepass and friends. Add them to more places. Use them in more places.

*Imported from #214*

---

## 223: Clean up System.update
status: open
priority: high
kind: none
labels: effort:m, priority:high
created: 2026-02-19

*Imported from #215*

---

## 233: Bring back DebugLabelModifier
status: open
priority: none
kind: none
created: 2026-02-19

*Imported from #225*

---

## 235: Separate SetupElement and WorkloadElement protocols instead of monolithic BodylessElement
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

## Problem

Currently, `BodylessElement` is a monolithic protocol that includes both setup and workload methods, plus the new `requiresSetup` method. This leads to:

1. **Empty placeholder methods everywhere** - Most elements only use either setup OR workload methods, not both
2. **Unclear intent** - It's not obvious from the type system which elements need which phases
3. **Manual `requiresSetup` overrides** - We have to manually return `false` for workload-only elements
4. **Single protocol with multiple responsibilities** - Violates single responsibility principle

## Proposed Solution

Split `BodylessElement` into two focused protocols:

```swift
protocol SetupElement {
    func setupEnter(_ node: Node) throws
    func setupExit(_ node: Node) throws
}

protocol WorkloadElement {
    func workloadEnter(_ node: Node) throws
    func workloadExit(_ node: Node) throws
}
```

## Benefits

1. **Clear intent** - Elements explicitly declare which phases they participate in
2. **No empty methods** - Only implement what you actually use
3. **Automatic setup detection**:
   - Elements conforming to `SetupElement` → need setup when changed
   - Elements only conforming to `WorkloadElement` → never need setup
   - Elements conforming to both → need setup when changed
4. **Type safety** - Compiler ensures you implement the right methods
5. **Simpler mental model** - "This element does setup" vs "This element does workload"

## Implementation Examples

- **Setup only**: `RenderPipeline`, `ComputePipeline` → conform to `SetupElement`
- **Workload only**: `Draw`, `Blit`, `ComputeDispatch`, `ParameterElementModifier` → conform to `WorkloadElement`
- **Both**: Elements that truly need both phases conform to both protocols

## System Changes

The System would check protocol conformance to determine behavior:

```swift
// Determine if changes require setup
let requiresSetup = element is SetupElement

// Process phases
if let setupElement = element as? SetupElement {
    try setupElement.setupEnter(node)
}
if let workloadElement = element as? WorkloadElement {
    try workloadElement.workloadEnter(node)
}
```

## Related Issues

This is a follow-up to #231 which identified the needsSetup propagation issue. The current workaround with `requiresSetup` method would be replaced by this cleaner protocol-based approach.

*Imported from #227*

---

## 236: Pipeline elements need proper requiresSetup implementation for shader constants
status: open
priority: none
kind: bug
labels: bug
created: 2026-02-19

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
status: open
priority: medium
kind: enhancement
labels: enhancement, priority:medium
created: 2026-02-19

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

---

## 239: value vs values is very subtle.
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

func parameter(_ name: String, functionType: MTLFunctionType? = nil, values: [some Any])func parameter(_ name: String, functionType: MTLFunctionType? = nil, value: some Any)

At the very least we should improve the asserts.

*Imported from #231*

---

## 240: Get rid of UltraviolenceSupport
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

Not really needed now that we broke out geometrylite3d.

Can be turned into batteries included (#202)

*Imported from #232*

---

## 243: Cleanup MTLCreateSystemDefaultDevice() again.
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

*Imported from #235*

---

## 245: Make sure all argument buffers are using useResources() correct.
status: open
priority: none
kind: bug
labels: bug
created: 2026-02-19

*Imported from #237*

---

## 246: Assert when same shader compiled multiple times
status: open
priority: none
kind: enhancement
labels: enhancement, priority:urgent
created: 2026-02-19

*Imported from #238*

---

## 247: Solve shader compilation issue
status: open
priority: none
kind: bug
labels: bug
created: 2026-02-19

We still haven't solved the shader compilation problem.

Maybe we just need a best practice.

Maybe we need to make shaders elements

*Imported from #239*

---

## 248: Framework should detect or warn when Element body returns 'any Element' instead of 'some Element'
status: open
priority: none
kind: bug
labels: bug
created: 2026-02-19

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
status: open
priority: none
kind: none
created: 2026-02-19

*Imported from #247*

---

## 256: Metal 4
status: open
priority: none
kind: none
created: 2026-02-19

*Imported from #248*

---

## 259: Look at unifying transform/amplification/uniforms
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

*Imported from #251*

---

## 260: Rename renderPipelineDescriptorModifier -> renderPipelineDescriptorTransfomer
status: open
priority: none
kind: enhancement
labels: enhancement
created: 2026-02-19

*Imported from #251*

---

## 268: device.supportsFunctionPointers
status: open
priority: none
kind: none
created: 2026-02-19

*Imported from #260*

---

## 269: Merge RenderView with environment (ProcessInfo) logic
status: open
priority: none
kind: none
created: 2026-02-19

Found in Sources/UltraviolenceUI/RenderView.swift:195

The RenderView currently has separate logic for environment and ProcessInfo that should be merged into a unified approach.

*Imported from #261*

---

## 274: Make sampleCount and colorPixelFormat parameters on RenderView
status: open
priority: none
kind: none
created: 2026-02-19

Found in Sources/UltraviolenceUI/MTKView+Environment.swift:41 and :45

These settings are so important they should be parameters on RenderView instead of environment values.

*Imported from #266*

---

## 280: Make sure all .environment values have helper functions (if appropriate)
status: open
priority: none
kind: none
created: 2026-02-19

*Imported from #272*

---

## 282: Implement .transformEnvironment()
status: open
priority: none
kind: none
created: 2026-02-19

*Imported from #274*

---

## 287: Add @Observation support
status: open
priority: none
kind: none
created: 2026-02-19

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

