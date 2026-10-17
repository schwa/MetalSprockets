# RFC 0007 — Typed content domains

**Status:** Draft
**Author:** schwa
**Date:** 2026-10-17
**Tracking issue:** #529
**Related issues:** #528

## Summary

Today every MetalSprockets node is an `Element`, so any element can go inside any other. Users can write nonsensical
trees, for example a `ComputeDispatch` inside a `RenderPipeline`, and only find out at runtime (or never).

SwiftUI 27 unified its result builders under `@ContentBuilder`. We can use the same pattern to make each level of the
tree a separate type domain, so invalid nesting fails to compile.

## Background: SwiftUI 27 `@ContentBuilder`

- `ContentBuilder` is a typealias for `ViewBuilder`. Its `buildBlock` / `buildEither` no longer require `View`.
- It builds shared container types: `TupleContent`, `_ConditionalContent`, `ForEach`, `Optional`, `EmptyContent`.
- Each domain adds conditional conformances, for example
  `extension TupleContent: ChartContent where repeat each Content: ChartContent`.
- The call site enforces the domain, for example `Chart.init<Content: ChartContent>(@ContentBuilder content:)`.

Result: one builder and one set of container types, with type safety per domain.

## Proposal

Add domain protocols that follow the nesting of the API:

| Container | Accepts |
|---|---|
| `RenderView` / root | `PassContent` (`RenderPass`, `ComputePass`, blit…) |
| `RenderPass` | `RenderPipelineContent` (`RenderPipeline`, `MeshRenderPipeline`) |
| `RenderPipeline` | `DrawContent` (`Draw`, `IndexedDraw`…) |
| `ComputePass` | `ComputePipelineContent` → `ComputeDispatch` |

- Keep one `ElementBuilder`. Relax its constraints if needed.
- `TupleElement`, `_ConditionalContent`, `ForEach`, `Group`, `EmptyElement` get one conditional conformance per domain.
- Containers constrain their `Content` generic to the domain they accept.

## Open problems

1. **Modifiers.** `.parameter(...)`, `.environment(...)` and similar must keep the domain of their input (a modified
   draw is still `some DrawContent`). This needs an overload per domain or a generic modifier with conditional
   conformances. Expect type-checker ambiguity, like SwiftUI's `.opacity` issue.
2. **Custom elements.** User types must declare a domain
   (`struct Foo: DrawContent { var body: some DrawContent }`). This is source breaking and needs a migration plan.
3. **Cross-level elements.** Environment readers, `Group`, and similar can appear at many levels. They need a
   conformance per domain, or some levels stay loose.
4. **Type erasure.** `AnyElement` needs one erased type per domain, or a generic `AnyContent<Domain>`.
5. **Compile time.** More overloads and conditional conformances can slow type-checking.

## First step

Do a spike with two domains only: `PassContent` and `DrawContent`. Constrain `RenderView` to `PassContent` and `RenderPipeline` to `DrawContent`,
make `.parameter` keep the domain, and measure compile errors and type-check time before going further.
