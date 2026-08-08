# Autoresearch: test coverage for MetalSprockets

## Objective

Raise the amount of MetalSprockets that is actually exercised by the test suite, by writing tests — not by
deleting code and not by weakening what existing tests assert.

MetalSprockets is "SwiftUI for Metal": a tree of `Element`s is expanded into nodes by `System`, then walked in
two phases (setup, then workload) to encode Metal commands. Most of the library therefore only runs when an
element tree is actually rendered, which is why so much of it went untested.

Two things worth knowing before writing tests:

- `OffscreenRenderer` renders an element tree headlessly and hands back a texture, so almost anything can be
  tested without a window. `Runner` does the same and keeps its `System` between calls, which is how you reach
  second-frame behaviour (caches, `@MSState` persistence, setup skipping).
- `MTKView` vends drawables without being in a window, so `RenderViewViewModel.draw(in:)` can be driven
  directly. See `RenderViewViewModelTests`.

## Metrics

- **Primary**: `covered_lines` (count, higher is better) — absolute covered lines. Deliberately *not* a
  percentage: a percentage goes up when you delete untested source, which is not the goal here.
- **Secondary**: `uncovered_lines`, `line_pct`, `function_pct`, `covered_functions`, `total_lines`.
  Watch `total_lines`: if it falls, library code was removed — that is a red flag, not a win.

## How to Run

`./.auto/measure.sh` — runs `xcb test --coverage-summary --coverage-sort-by-impact`, emits `METRIC` lines and
prints the current worst-covered files. A run takes roughly 60–90s.

`./.auto/checks.sh` runs automatically afterwards: swiftlint must be clean, `Sources` must not lose net lines,
and no new golden reference image may appear without deliberate blessing (see below).

## Files in Scope

- `Tests/MetalSprocketsTests/**` — where new tests go. Prefer extending the existing suite file for an area
  over creating another one.
- `Tests/MetalSprocketsTests/Golden Images/**` — reference images. See the golden-image rules below.
- `Sources/**` — only for **behaviour-preserving testability changes**: widening `private` to `internal`,
  extracting a pure function out of a view body or a long method so it can be asserted on directly. The
  `FrameTimingView.rows(for:options:targetFramesPerSecond:)` extraction is the pattern to copy.

## Off Limits

- Changing library behaviour to make a test pass. If a test fails because the library is wrong, that is a bug
  to file (`issues create`), not something to paper over.
- Deleting or disabling library code, tests, or assertions to move the metric.
- Adding dependencies.
- `Example/`, `Experiments/`, `Documentation/`, `RFCs/`.

## Constraints

- The suite must pass and swiftlint must be clean, every iteration.
- Tests must assert on **behaviour**, not on "it didn't throw". A test that only checks that a render completed
  is exactly the kind of test that let #354 (MSAA renders nothing) sit undetected — see below.
- Skip cleanly (`return` early) when hardware support is missing (mesh shaders, MetalFX, MSAA sample counts)
  rather than failing on machines that lack it.
- Follow the repo's Swift conventions: backtick-named `@Test` functions describing behaviour, `#expect`,
  four-space indent, no force unwraps outside tests where a crash is the failure.

## Golden Images

Golden-image tests are the highest-value tests in this repo — they are what caught #354, #355 and #356. Use
`Golden.verify(_:named:size:)` from `Tests/MetalSprocketsTests/Support/Golden.swift`.

**Blessing a new reference is a deliberate act.** When a reference is missing, the comparison writes the
rendered image to `$TMPDIR/MetalSprocketsGoldenImages/<name>.png` and fails. Before copying that file into
`Tests/MetalSprocketsTests/Golden Images/`:

1. **Look at it** (the `read` tool renders PNGs).
2. Say out loud what the image *should* show, and confirm the pixels agree.
3. Only then copy it in.

`checks.sh` fails while an unblessed golden is sitting in the working tree, so this cannot happen by accident.
Never bless an image you have not viewed — that enshrines a bug as the reference.

## What's Been Tried

Starting point: 82.1% lines / 70.4% functions. After the first manual pass: ~88% lines / ~74% functions.

Worked well:
- Driving `RenderViewViewModel.draw(in:)` with a headless `MTKView` (5% → 58% on `RenderView.swift`).
- Extracting `FrameTimingView`'s row construction out of the `TimelineView` body (13.6% → 39.2%).
- Golden images for depth ordering, depth bias, parameter binding, function constants, and object/mesh stages.
- Reusing one `OffscreenRenderer`/`Runner` across two renders to reach cache-hit and second-frame paths.

Bugs found this way (do not "fix" the tests to match the buggy behaviour):
- **#354** `.msaa(sampleCount:)` never anti-aliases and drops rendering after frame 1.
- **#355** a misplaced `.msaa()` is a silent no-op.
- **#356** the capture modifier can never produce a `.gpuTraceDocument`.

Known-hard, low-yield (deprioritise):
- The remaining ~150 uncovered lines in `RenderView.swift` are SwiftUI `body`/modifier plumbing.
- The remaining ~79 in `FrameTimingView.swift` are the `TimelineView` shell.
- Capture paths need the host launched with `MTL_CAPTURE_ENABLED=1`; tests skip otherwise.
