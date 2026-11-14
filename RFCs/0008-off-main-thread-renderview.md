# RFC 0008 — Off-main-thread RenderView

**Status:** Draft
**Author:** schwa
**Date:** 2026-11-14
**Tracking issue:** #560
**Related:** SceneSprockets #393, #559

## Summary

Add an opt-in mode in which `RenderView` on macOS and iOS calls the content closure, updates the element tree, encodes,
and commits on a dedicated render thread. The main thread keeps only SwiftUI updates, layout, and input. This is the
model the visionOS immersive path (`ImmersiveRuntime` on `ImmersiveRendererActor`) already uses.

## Problem

`RenderViewViewModel.draw(in:)` is an `MTKViewDelegate` callback. MTKView drives it from the main run loop, so every
phase runs on the main thread:

| Phase | Where today |
|---|---|
| `content(context, size)` | main |
| `System.update` / setup / workload | main |
| drawable acquire (may block) | main |
| commit + present | main |

SceneSprockets measured about 70 ms of CPU per frame in TinyTorii's sample town. All of it is main-thread time, so
input and UI stall.

## What already works off main

- The core (`System`, `FrameRunner`, `Runner`, `MetalContext`) is not `@MainActor`. It requires one owning isolation
  (see the `System` doc comment), not the main one.
- `OffscreenRenderer` runs on background threads (SceneSprockets #391). #559 fixed the only TSan report found there.
- `ImmersiveRuntime` runs the whole frame on a custom actor.

So the main work is in MetalSprocketsUI: frame pacing, drawable acquisition, and the hand-off of state from SwiftUI.

## Proposal

### API

```swift
RenderView(threading: .renderThread) { context, size in
    // Called on the render thread.
}
```

```swift
public enum RenderViewThreading: Sendable {
    case main          // today's behavior, the default
    case renderThread  // one dedicated thread per RenderView
}
```

In `.renderThread` mode the content closure must be `@Sendable`. This is a separate `init` overload, so `.main`
callers keep non-Sendable closures that capture main-actor models.

### Render loop

One serial executor per view, made from a dedicated `Thread` with its own run loop (not the cooperative pool, because
drawable acquisition and `waitForSubmissionCapacity` can block).

Frame pacing:

- macOS 14+: `NSView.displayLink(target:selector:)` added to the render thread's run loop.
- iOS: `CADisplayLink` added to the render thread's run loop.
- `preferredFramesPerSecond`, pause, and on-demand redraw (#553) map to the display link.

The frame body is today's `draw(in:)`, moved to the render thread, unchanged in order: `prepareFrame` → acquire
drawable → build context → content → `submitFrame(presenting:)`.

### Drawable source

MTKView's `currentDrawable` and `currentMTL4RenderPassDescriptor` are main-thread APIs. In `.renderThread` mode the view
uses a plain view backed by `CAMetalLayer`, and the render thread:

- calls `layer.nextDrawable()` itself;
- builds the `MTL4RenderPassDescriptor`, including MSAA and depth textures, which MTKView makes today.

So this mode needs a small replacement for MTKView's attachment management: color MSAA texture, depth/stencil texture,
reallocation on size, sample count, or format change, and the `metal*` environment modifiers (pixel formats,
storage mode, usage, store actions, clear values). That code is shared with `.main` where practical, so MTKView can
eventually be removed from both paths.

### Main → render thread state

The main thread writes, and the render thread reads at the start of each frame, one `Mutex`-protected snapshot:

- content closure, drawable size and scale, pixel formats, sample count, and attachment settings;
- residency, maximum in-flight submissions, shader store, capture configuration, and diagnostics.

`CAMetalLayer.drawableSize` is set on the main thread during layout (CoreAnimation requires it), and the render thread
reads the new size from the snapshot.

### Render thread → main state

Today these callbacks run inline on main. In `.renderThread` mode they are delivered with `MainActor` hops:

- `onDrawableSizeChange`: fired from main during layout, as before.
- `onFrameTimingChange`: coalesced, at most one main-actor hop per frame, dropping stale values.
- `lastError`: hopped to main; `renderViewFatalErrorOnError` still traps on the render thread.
- `frame`, which is observable today: hopped, or not observable in this mode.

### Lifetime

- On dismantle, the main thread stops the display link, signals the thread, and returns without blocking. The thread
  drains in-flight submissions (`drain(timeout:)`) and then exits. The view model and `FrameRunner` are released on the
  render thread.
- The #301 rule still applies: no frame starts after dismantle.

## User-facing rules in `.renderThread` mode

- The content closure runs on the render thread. It must not touch main-actor state directly. Apps pass a `Sendable`
  snapshot (for example a `Mutex`-protected scene state) and read it in the closure.
- `@MSState` and element-local state belong to the render thread.
- `onCommandBufferCompleted` and similar handlers run where they run today (Metal's threads), not on main.

SwiftUI `@Observable` models read inside the closure do not trigger redraws in this mode. Continuous display-link
rendering hides this. On-demand mode needs an explicit redraw request.

## Alternatives considered

1. **Keep MTKView, call `draw()` from a background thread.** MTKView's documentation does not cover this, and its
   drawable and descriptor properties are not documented as thread-safe. Rejected unless Apple documents it.
2. **Only move encoding off main; keep content on main.** It still runs the content closure and element update on main,
   which is a large part of the SceneSprockets cost. It also needs a frozen tree to pass across threads, which the
   `System` does not support.
3. **Use a Swift actor instead of a thread.** Drawable acquisition and in-flight waits block, and blocking a cooperative
   pool thread is not acceptable. A custom `SerialExecutor` backed by the dedicated thread could expose an actor API on
   top of the thread later.

## Plan

1. `CAMetalLayer`-backed host view plus attachment management, used by `.main` mode behind MTKView parity tests (golden
   images for MSAA, depth, and formats).
2. Render thread + display link; `.renderThread` option; snapshot hand-off.
3. Callbacks, errors, and lifetime; TSan test that renders a `RenderView` in `.renderThread` mode in a window.
4. Port the SceneSprockets SceneView, then measure main-thread time.

## Decisions

- Both modes share the new layer-backed host. MTKView is removed; two different paths are not worth keeping.
- `.main` stays the default for now. Revisiting the default is tracked in #561.
- Each `RenderView` gets its own render thread.

## Open questions

- iOS: not verified that `CADisplayLink` on a background run loop behaves like on main (ProMotion,
  `preferredFrameRateRange`). Test later.
