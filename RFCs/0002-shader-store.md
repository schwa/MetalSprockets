# RFC 0002 — ShaderStore

**Status:** Draft
**Author:** schwa
**Date:** 2026-04-21
**Tracking issue:** #339

## Summary

Replace the process-global `LibraryRegistry` with `ShaderStore`: a user-
ownable, scopable cache of compiled `MTLLibrary`s and specialized
`MTLFunction`s. `ShaderStore` is attached to a view/element subtree via
an environment modifier. When no store is attached, `RenderView`
provides a private one scoped to its own lifetime. Shaders no longer
leak for the process lifetime.

## Motivation

Today, every `ShaderLibrary` (bundle, source, or wrapped `MTLLibrary`)
is deduped through `LibraryRegistry.shared`, a strong-reference
singleton that lives for the whole process. This has two problems:

1. **It leaks.** Long-running apps, apps that compile shaders from
   procedurally-generated sources, and test suites that compile many
   variants retain every `MTLLibrary` they've ever seen. The per-library
   `ShaderCache` of specialized `MTLFunction`s retains with it.
2. **It's not scopable.** Callers have no way to say "these shaders
   belong together and should share a cache," nor "throw these away when
   this view goes away."

The fix needs to preserve two things today's registry gets right:

- **Deduplication.** Two `ShaderLibrary(bundle: .main)` values under the
  same scope should share one compiled library and one function cache.
- **Predictable compile timing.** Compilation happens at `init`, not
  inside the render loop. A lazy-resolve design that defers compilation
  to first use during `draw()` is not acceptable — it would put
  shader compiles on the frame critical path.

## Non-goals

- Cross-device shader sharing. MetalSprockets targets one device per
  process (Apple Silicon only). A `ShaderStore` is assumed to be used
  with a single device; mixing devices in one store is undefined.
- Weak-referenced cache entries. The store is an explicit strong owner;
  lifetime is controlled by the caller's lifetime of the store.
- Async / background compilation. Orthogonal; can be layered later.
- Disk caching / metallib emission. Orthogonal.

## Proposed design

### `ShaderStore`

```swift
public final class ShaderStore: Sendable {
    public init()
    // internal adoption API (see below)
}
```

A `ShaderStore` owns a dictionary of `ShaderLibrary.ID → ShaderLibrary.State`.
`State` is the existing internal type that wraps one `MTLLibrary` plus
its per-library `ShaderCache`. The store holds strong references:
entries live as long as the store does.

### Eager compile, lazy adoption

`ShaderLibrary` initializers continue to compile the `MTLLibrary`
eagerly, matching today's behavior. Compilation cost lives at the
construction site, never inside `draw()`.

Each `ShaderLibrary` value holds its `State` in a small `StateBox`.
The first time a `ShaderLibrary` is used from inside a live `System`
context (i.e. inside an element's `body`/`setup`/`run` where
`System.current.activeNodeStack.last` is non-nil), the box looks for a
`ShaderStore` in the ambient `MSEnvironmentValues` and **adopts**
against it:

- If the store already contains a `State` for this `ID`, the box swaps
  to it (its own freshly-compiled `State` is discarded — one wasted
  compile, but no correctness issue).
- Otherwise, the box inserts its `State` into the store.

After adoption the box never swaps again. Outside a System — e.g. from
unit tests, or from code constructing `ShaderLibrary` at view init —
the box simply keeps using its private `State`, which dies with the
`ShaderLibrary` value.

This gives us:

- **No draw-loop compiles.** All compilation is at `init`.
- **Dedup within a store.** All `ShaderLibrary`s with the same ID used
  under the same ambient store converge on one `State`.
- **No cross-store sharing.** Separate stores are fully independent.
- **Graceful fallback.** `ShaderLibrary` still works outside any
  rendering context (tests, one-offs); it just doesn't dedupe.

### Environment modifiers

Two symmetric modifiers, one on each side of the SwiftUI/MetalSprockets
bridge:

```swift
// SwiftUI
extension View {
    func shaderStore(_ store: ShaderStore) -> some View
}

// MetalSprockets
extension Element {
    func shaderStore(_ store: ShaderStore) -> some Element
}
```

Both write into their respective environment's `shaderStore` entry.
`RenderView` reads the SwiftUI env value and propagates it into the
MetalSprockets env when building the root element tree each frame.

### `RenderView` fallback

If no `ShaderStore` is attached above a `RenderView`, the view creates
a private `ShaderStore` owned by its `RenderViewViewModel`. It dies
when the `RenderView`'s view model dies (typically when the SwiftUI
view is torn down). This replaces the leak of the old global registry
with a bounded lifetime tied to the view.

### Typical usage

Shared store across views (explicit, preferred):

```swift
@State private var store = ShaderStore()

var body: some View {
    HStack {
        RenderView { ... }
        RenderView { ... }
    }
    .shaderStore(store)
}
```

One-off / scoped:

```swift
RenderView { ... }   // gets a private store; shaders die with the view
```

Inside an element tree:

```swift
RenderPass {
    try RenderPipeline(vertexShader: vs, fragmentShader: fs) { ... }
}
.shaderStore(myStore)
```

## Lifetime and adoption semantics

Informal rules:

1. A `ShaderLibrary` compiles its `MTLLibrary` at `init`. This never
   happens in `draw()`.
2. The compiled `State` lives inside the `ShaderLibrary`'s `StateBox`.
3. The first time the library is asked for its `id`, `library`, or
   `cache` from inside a `System` with an ambient `ShaderStore`, the
   box adopts against that store and swaps to whatever `State` the
   store returns (existing or newly inserted). Adoption is one-shot.
4. Subsequent accesses return the adopted `State` with no locking
   beyond the box's internal fast path.
5. Outside a `System`, the box returns the private `State` and remains
   un-adopted; a later access from inside a `System` can still adopt.

Adoption is intentionally idempotent and order-insensitive: two
libraries created in any order, used in any order, converge on one
`State` per store per `ID`.

## Migration

- `LibraryRegistry` is deleted. No one imports it externally; it was
  internal.
- `ShaderLibrary`'s public API is unchanged. The only observable
  behavior change is that two `ShaderLibrary(source: sameSource)`
  values constructed outside any store no longer share a backing
  `MTLLibrary`. Code that relied on that implicit sharing should either
  attach a shared `ShaderStore` or accept two compilations.
- One existing test asserting cross-instance sharing via the global
  registry is rewritten as its inverse (separate libraries, no global
  cache) plus new tests for store-scoped sharing.

## Alternatives considered

### Lazy compilation with ambient-resolved state

A design where `ShaderLibrary` holds only the `ID` and resolves both
the `MTLLibrary` *and* the cache entry at first use. Conceptually
clean: the cache scope is purely environment-driven, and construction
is free anywhere. Rejected because it moves `MTLLibrary` compilation
into `draw()` on the first frame a given shader is touched, making
frame-time spikes inevitable and hard to diagnose.

### Explicit store parameter on every initializer

`ShaderLibrary(bundle:, store:)` etc., with no ambient resolution.
Fully explicit, no magic, but forces store-threading through every
call site that constructs a library, including utility extensions like
`ShaderLibrary.metalSprocketsUI`. Too noisy given how often these are
constructed as stored properties far from any view.

### Weak-referenced global registry

Keep a process-global registry but weak-reference its entries so states
die when the last `ShaderLibrary` value does. Fixes the leak, but
doesn't give callers control over sharing scope, and "weak" is fragile
with `MTLLibrary`s that some caller might be holding via unrelated
paths. Explicit ownership is clearer.

## Open questions

- Should `ShaderStore` expose a `purge()` API for cases where callers
  want to drop cached entries without tearing down the store? Probably
  yes, as a later addition; not needed for #339.
- Should `ShaderStore` track statistics (hit/miss/compile counts) for
  diagnostics? Useful, but separable.
- Should there be a convenience `ShaderStore` instance on `RenderView`
  exposed for external observation (e.g. debugging which shaders a
  view has compiled)? Separable.

## Status

Implemented in the branch landing with this RFC. See #339.
