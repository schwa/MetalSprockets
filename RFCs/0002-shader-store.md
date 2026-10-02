# RFC 0002 — ShaderStore

**Status:** Draft
**Author:** schwa
**Date:** 2026-04-21
**Tracking issue:** #339

## Summary

Replace the process-global `LibraryRegistry` with `ShaderStore`, a client-owned cache of compiled `MTLLibrary`s and specialized `MTLFunction`s.
An environment modifier attaches the store to a view or element subtree.
When no store is attached, `RenderView` provides a private store with the same lifetime as the view.
Shaders no longer remain retained for the process lifetime.

## Motivation

Today, `LibraryRegistry.shared` deduplicates every `ShaderLibrary`, whether it comes from a bundle, source, or wrapped `MTLLibrary`.
This singleton holds strong references for the process lifetime. It has two problems:

1. **It leaks.** Long-running apps and test suites retain every compiled `MTLLibrary`, including libraries from generated sources.
   Each library also retains its `ShaderCache` of specialized `MTLFunction`s.
2. **It has no client-controlled scope.** Callers cannot group shaders in a shared cache or release them with a view.

The fix needs to preserve two things today's registry gets right:

- **Deduplication.** The design requires two `ShaderLibrary(bundle: .main)` values in one scope to share a compiled library and function cache.
- **Predictable compile timing.** Compilation occurs at `init`, not in the render loop.
  Deferring compilation until first use in `draw()` puts that cost on the frame's critical path.

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
context (that is inside an element's `body`/`setup`/`run` where
`System.current.activeNodeStack.last` is non-nil), the box looks for a
`ShaderStore` in the ambient `MSEnvironmentValues` and **adopts**
against it:

- If the store already contains a `State` for this `ID`, the box swaps
  to it (its own freshly-compiled `State` is discarded — one wasted
  compile, but no correctness issue).
- Otherwise, the box inserts its `State` into the store.

After adoption, the box does not swap again.
Outside a System, the box uses its private `State`, whose lifetime follows the `ShaderLibrary` value.
Examples include unit tests and `ShaderLibrary` construction during view initialization.

This gives us:

- **No draw-loop compiles.** All compilation is at `init`.
- **Dedup within a store.** All `ShaderLibrary`s with the same ID used
  under the same ambient store converge on one `State`.
- **No cross-store sharing.** Separate stores are fully independent.
- **Standalone use.** `ShaderLibrary` works outside a rendering context, such as in tests or one-off operations. It does not deduplicate libraries there.

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
Each frame, `RenderView` copies the SwiftUI environment value into the MetalSprockets environment for the root element tree.

### `RenderView` fallback

If no ancestor provides a `ShaderStore`, `RenderView` creates a private store owned by its `RenderViewViewModel`.
The store's lifetime follows the view model, which usually ends when SwiftUI removes the view.
This bounds the lifetime that the global registry left unbounded.

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

In this alternative, `ShaderLibrary` holds only the `ID`. It resolves the `MTLLibrary` and cache entry at first use.
The environment controls the cache scope, and construction does not compile shaders.
This design is rejected because first use compiles the library in `draw()`. That adds frame-time spikes that are difficult to diagnose.

### Explicit store parameter on every initializer

This alternative passes the store explicitly, as in `ShaderLibrary(bundle:, store:)`, without environment lookup.
Every library initializer and utility extension, including `ShaderLibrary.metalSprocketsUI`, must receive the store.
That adds arguments to stored-property initializers far from the view.

### Weak-referenced global registry

This alternative keeps a global registry with weak references. States are released with the last `ShaderLibrary` value.
It fixes the leak but does not give callers control of sharing scope.
Unrelated references to an `MTLLibrary` also affect its lifetime. Explicit ownership is clearer.

## Open questions

- Should `ShaderStore` expose a `purge()` API for cases where callers
  want to drop cached entries without tearing down the store? Probably
  yes, as a later addition; not needed for #339.
- Should `ShaderStore` track statistics (hit/miss/compile counts) for
  diagnostics? Useful, but separable.
- Should there be a convenience `ShaderStore` instance on `RenderView`
  exposed for external observation (for example debugging which shaders a
  view has compiled)? Separable.

## Status

Implemented in the branch landing with this RFC. See #339.
