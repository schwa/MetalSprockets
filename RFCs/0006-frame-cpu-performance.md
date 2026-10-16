# RFC 0006 — Per-frame CPU performance

**Status:** Draft
**Author:** schwa
**Date:** 2026-10-16
**Tracking issue:** #486
**Related issues:** #490, #495, #496, #497, #498, #501, #500, #476, #475, #389, #390

## Summary

MetalSprockets spends too much CPU time per draw element per frame. At 1000 draws, a frame takes about 60 ms of CPU in
Release and about 110 ms in Debug. The GPU takes under 0.5 ms. The cost is in the framework, mostly in the update
(reconciliation) phase, and most of it is Swift runtime work: reflection, dynamic casts, metadata lookups, and copies.

This RFC collects the measurements, the profile, and all candidate fixes in one place, and proposes an order of work.

## Motivation

- A client scene graph (#486) dropped to about 6 fps with about 180 non-instanced draws.
- The Example app's Render demo runs at 12 fps in Release and 7 fps in Debug with 1000 cubes.
- Release is only about 1.7x faster than Debug. The optimizer cannot remove most of the cost.
- Debug builds should also be acceptably fast. Xcode builds Swift packages with the app's configuration, so a Debug app
  gets a Debug MetalSprockets. The fix has to reduce work, not depend on the optimizer.

## Goals

- CPU cost per draw is well under 0.1 ms in Release (target to be set, see Open questions).
- Debug builds are usable at the same scene sizes, not only Release.
- Cost stays linear in draw count, and does not grow with tree depth.
- No regression in correctness: node identity, state, setup, and change detection behave as today.

## Non-goals

- GPU-side performance. The GPU is not the bottleneck in any measurement here.
- Automatic instancing (#500). That is a separate, speculative feature.
- Changing the public element model to something other than a SwiftUI-style value tree.

## Measurements

Machine: Apple M5 Max, macOS 27.0.1, Xcode 27 RC. Times are medians in milliseconds unless noted.

### Tooling

- `Experiments/ReconciliationBenchmark`: headless benchmark with per-phase CPU timings (`OffscreenRenderer.Rendering.cpuPhaseTimings`, #488).
  - `--scenario cubes` (default): the Example Render demo. One `Draw` per cube in a
    `ForEach(Array(x.enumerated()), id: \.offset)`, each with `.vertexValues` and two `.parameter` modifiers.
  - `--scenario draws`: the #486 repro. Two passes, deeper modifier stack, `AnyElement`, nested `ForEach`/`Group`.
- `Scripts/profile-benchmark.sh`: builds the benchmark, records it with the Time Profiler (`xctrace`), and prints the hottest
  functions within a phase (`--within System.update`, `processWorkload`, `processSetup`).
- `FrameTimingView` (`.cpuPhases`, `.gpuTimings`) in the Example app shows the same phases live.
- Phases are signposted (`Update`, `Setup`, `Workload`) under Points of Interest.

### Phases

- **content**: the caller builds the element tree.
- **update**: reconcile the new tree against the previous frame's nodes.
- **setup**: setup work for nodes that need it.
- **workload**: encode GPU commands.

### Baseline: cubes scenario, Release (#487)

| cubes | content | update | setup | workload | CPU | GPU | µs/draw |
|---|---|---|---|---|---|---|---|
| 100 | 0.01 | 5.23 | 0.17 | 0.61 | 6.03 | 0.09 | 60.3 |
| 500 | 0.02 | 25.42 | 0.81 | 2.98 | 29.22 | 0.25 | 58.4 |
| 1000 | 0.03 | 51.68 | 1.65 | 5.90 | 59.26 | 0.47 | 59.3 |
| 2000 | 0.04 | 105.61 | 3.38 | 11.94 | 120.97 | 0.30 | 60.5 |

### Baseline: cubes scenario, Debug, 1000 cubes

| content | update | setup | workload | CPU | µs/draw |
|---|---|---|---|---|---|
| 0.32 | 87.13 | 3.86 | 17.38 | 108.69 | 108.7 |

The Example app (RenderView, 1000 cubes) shows similar numbers: Release update 62.7 ms, workload 13.8 ms; Debug update
109.2 ms, workload 26.3 ms.

### Baseline: draws scenario (#486 repro), Release

`count` is draws per pass; there are two passes.

| count | draws | update | setup | workload | CPU | µs/draw |
|---|---|---|---|---|---|---|
| 10 | 20 | 5.04 | 0.14 | 0.37 | 5.55 | 277 |
| 100 | 200 | 47.07 | 1.19 | 3.32 | 51.59 | 258 |
| 400 | 800 | 184.58 | 4.50 | 12.81 | 201.91 | 252 |

### Findings

- Cost is linear in draw count.
- Building the element tree (content) is negligible. The cost is in the framework.
- Update is about 87% of CPU time. Workload is about 10%. Setup is about 3%.
- A deeper modifier stack per draw (draws scenario) costs about 4x more per draw than the cube scenario.
- Setup runs every frame even when the tree structure does not change (about 4 ms Debug, 1.7 ms Release at 1000 cubes).
  Not investigated.

### Profile (#489)

Release, cubes scenario, 1000 cubes, 60 frames. Percentages are inclusive shares of samples within each phase, and
overlap.

**Update**

| Share | Where | Issue |
|---|---|---|
| ~38% | `isEqual` / `isEqualStructurally`: `Mirror` (~15%), `swift_dynamicCast` (~18%), `swift_getTypeByMangledName` (~12%), conformance lookups (~11%) | #495 |
| ~25% | `StructuralIdentifier` `==` (~15%) and `hash` (~10%); `Hasher._combine` is the top self symbol | #497 |
| ~21% | `Element.visitDynamicProperties` / `configureNode`: `Mirror` on every node | #496 |
| ~10–15% self | `memmove`, `Atom` copies, retain/release, malloc/free | #497, #501 |

**Workload**

| Share | Where | Issue |
|---|---|---|
| ~35% | `Draw.workloadEnter`, of which ~27% is `swift_dynamicCast` (environment values stored as `Any`) | #498 |
| ~17% | `MSEnvironmentValues.recomputeEffectiveValues`: each `ParameterModifier` write copies and merges dictionaries | #498 |
| ~17% | `ParameterSet.makeTables`: argument tables per draw | #476 |

**Setup**

| Share | Where | Issue |
|---|---|---|
| ~20% | `MSEnvironmentValues.recomputeEffectiveValues` via `inheritEnvironmentFromActiveParent` | #498 |

`ForEach` itself is not a significant cost (#490). It is the source of most nodes, so it is a good place to optimize (#501).

## Code observations

From reading the code. Not measured individually.

- `isEqualStructurally` (`Support/isEqual.swift`) builds two `Mirror`s per comparison, builds `Array(zip(...))`, compares
  every field label, and runs `is any Element` on every field. Labels and element-ness depend only on the type.
- Elements that hold a closure never compare equal. `Draw` and `ParameterModifier` hold closures, so every comparison
  for them does the full reflection work and then returns false.
- `visitDynamicProperties` (`Core/Element+SystemExtensions.swift`) reflects every node every frame. Most nodes (`Draw`,
  modifiers) have no dynamic properties.
- `StructuralIdentifier` is the full array of atoms from the root. `appending` copies the parent's array. `System.nodes`
  is keyed by it, so each lookup hashes and compares the whole path.
- `ForEach` wraps each child in `IdentifiedElement` and boxes its ID in `AnyElementID` (`AnyHashable`). Every
  descendant's identifier hashes that box again. IDs are read through a key-path closure.
- `MSEnvironmentValues` keeps `values`, `inheritedValues`, and `effectiveValues` dictionaries of `Any`, and recomputes
  `effectiveValues` by merging on every write and inherit.

## Proposed direction

Work in layers, measure each step with the benchmark, and keep reflection as a fallback.

1. **Hand-written fast paths for the library's own elements.** The hot types are ours: `Draw`, `ParameterModifier`,
   `ForEach`, `RenderPipeline`, other modifiers. An internal protocol can say "no dynamic properties", "how to compare",
   or "never equal (holds a closure)". No public API change.
2. **Per-type caching of reflection results** for all other elements: whether a type has dynamic properties, which
   fields are child elements, field labels, conformance results. Reflect once per type, not every frame.
3. **Cheaper identity** (#497): node lookup that does not depend on depth.
4. **Cheaper environment** (#498): no whole-dictionary copies per write; fewer dynamic casts per read.
5. **`ForEach` specialisation** (#501): type-level work once per `ForEach`, per-`ForEach` child tables, positional
   matching when IDs are unchanged.
6. **Optional macro** for user elements to remove reflection completely when they opt in.

Order: 1 and 2 first (largest share, lowest risk; #496 is likely the easiest single change), then 3 and 5, then 4.

## Shit thrown at the wall

Every idea raised so far, unfiltered. Some conflict. None are verified.

### Equality and change detection (#495)

- Hand-written comparison for built-in elements.
- Cache per type: "no stored fields, always equal", "holds a closure, never equal", which fields are elements, labels.
- Skip label comparison when the types match.
- Skip `Array(zip(...))`; walk both `Mirror.children` together.
- Compare plain-data fields (`_isPOD`) with a byte compare instead of casting to `Equatable`.
- Cache `Equatable` conformance per field type instead of casting each frame.
- A macro (`@Element` or similar) that generates the comparison for user types.
- Let elements declare a cheap version/identity value to compare instead of their fields.
- Do not compare at all for element types that always rebuild (closures), and say so in their type.

### Dynamic properties (#496)

- Cache per type whether there are any dynamic properties; skip `Mirror` when there are none.
- Cache the field labels or offsets of dynamic properties per type.
- Generate the list with a macro (`@MSState` and friends are visible as attributes).
- Register dynamic properties at init instead of discovering them by reflection.

### Identity and node lookup (#497)

- Intern identifiers: map each path to a small integer once; key `System.nodes` by that.
- Store a precomputed hash in `StructuralIdentifier`.
- Parent pointer plus local atom instead of a full path.
- `InlineArray` for short paths.
- Per-parent child tables, so lookup is one small hash from the parent.
- Avoid `AnyHashable` for common ID types such as `Int`; box once per child, not per descendant.
- `borrowing` / `consuming` on hot paths to cut hidden copies and retain/release.
- `Span` to walk atoms without copying arrays.
- `StructuralIdentifier` cannot be `~Copyable` while it is a `Dictionary` key.

### Environment (#498)

- `TreeDictionary` (persistent hash tree, swift-collections) for cheap copies with structural sharing.
- Do not recompute `effectiveValues` on every write; resolve lazily or by parent chain.
- Give each `@MSEntry` key a static index and store values in typed slots, not `Any`.
- Write `parameterSet` once per draw instead of once per `ParameterModifier`.
- Separate hot per-draw values (parameters, depth state) from the general environment.

### ForEach (#501, #490)

- Type-level work once per `ForEach` (all children have the same type).
- Per-`ForEach` table from item ID to node.
- Positional matching when IDs and order are unchanged from the previous frame.
- Reuse a child subtree without calling `content` when its item is equal to last frame's (`Equatable` data). Needs a
  contract that `content` depends only on the item.
- Avoid materialising `Array(x.enumerated())` in callers; offer an index-based `ForEach`.
- Automatic instancing of identical draws (#500, separate).

### Workload and encoding (#476, #498)

- Do not rebuild and re-bind argument tables for every draw when nothing changed (#476).
- Cache resolved pipeline/parameter layouts per pipeline.
- Avoid dynamic casts in `Draw.workloadEnter` environment reads.

### Setup

- Find out why setup runs every frame when the structure is unchanged (about 1.7–4 ms at 1000 cubes).

### Whole-system

- Skip unchanged subtrees entirely (SwiftUI `EquatableView`-style).
- Dirty-tracking from `@MSState` changes only, instead of diffing the whole tree every frame.
- Keep a flat array of nodes in traversal order instead of a dictionary.
- Non-copyable internal `Node` storage and swift-collections containers (some are experimental).
- Fewer modifier nodes per draw: merge adjacent modifiers into one node.
- Reduce `System.current` side-channel cost (#389) and `System` responsibilities (#390) if they show up in profiles.
- Evaluate `@MSState` initial values lazily (#475).

## Open questions

- What is the target? For example: 1000-cube demo at 60 fps in Release, and at what fps in Debug?
- How much behaviour change is acceptable in change detection (for example "elements holding closures always rebuild")?
- Is an opt-in macro for user elements acceptable as public API?
- Should the benchmark run in CI, with a regression threshold?
- Which swift-collections containers are mature enough to depend on directly?

## Verification

- Before and after each change: `Experiments/ReconciliationBenchmark` (cubes and draws, Release and Debug) and
  `Scripts/profile-benchmark.sh`. Record results in the issue.
- Full test suite passes, in particular reconciliation, identity, state, and setup tests.
