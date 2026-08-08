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

`./.auto/measure.sh` — runs the suite three times, reports the **median** covered-line count and the spread
between samples, then prints the current worst-covered files. Roughly 16s with a warm build, longer after a source
change. `COVERAGE_RUNS=1 ./.auto/measure.sh` for a quick look.

**The measurement is not deterministic.** The ViewHosting tests put a real SwiftUI view on screen, and whether the
hosted `RenderView` gets a frame drawn depends on the run loop; that alone swings the total by ~70 lines. Watch
`sample_spread`: 0–2 means trust the number, large means re-run before concluding anything. Never discard a change
on a single down measurement.

To see exactly which lines are uncovered in a file:

```sh
xcrun llvm-cov show \
  .build/out/Products/Debug/MetalSprocketsTests.xctest/Contents/MacOS/MetalSprocketsTests \
  -instr-profile=.build/out/Products/Debug/codecov/default.profdata \
  Sources/MetalSprockets/Metal/Parameters.swift | rg '^ *[0-9]+\| +0\|'
```

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

82.1% → 92.3% lines (5,008 → 5,282 covered) over the manual pass plus eleven loop iterations.

### Techniques that worked, in rough order of value

1. **`ViewHosting.host(view:size:)`** (ViewInspector). Anything behind a SwiftUI `body` or a `Representable` is
   unreachable by constructing values — it needs a host. This was +113 lines from one small test (`RenderView`)
   and +77 from another (`FrameTimingView`). Pattern:
   `ViewHosting.host(view: v, size: ...); defer { ViewHosting.expel() }`.
2. **Driving `RenderViewViewModel.draw(in:)` directly.** An `MTKView` vends drawables without being in a window.
3. **Reusing one `Runner`/`OffscreenRenderer` across renders** to reach second-frame paths. Pipeline caches key on
   `ObjectIdentifier(MTLFunction)`, so **build the shaders once and share them** — a fresh `ShaderLibrary` per
   render always misses the cache and the hit path stays uncovered.
4. **`System().update(root:)` + `processSetup()` with no renderer at all**, for elements whose setup only reads the
   environment. Cheaper and more precise than rendering, and no encoder is created.
5. **Extracting a pure function out of a view body** (`FrameTimingView.rows(for:options:targetFramesPerSecond:)`).
6. **Golden images** for anything with a visual result.

### The rule for error paths

- **Setup-phase throws are safe** to test end-to-end: no encoder exists yet.
- **Workload-phase throws abort the process** (#357). Do not test them through `OffscreenRenderer`/`Runner`; the
  test binary dies. Instead build the encoder in the test and call the unit directly (see the "Rejected bindings"
  section of `ParameterBindingTests`), ending the encoder in a `defer`.

### Bugs found this way (do not "fix" the tests to match the buggy behaviour)

- **#354** `.msaa(sampleCount:)` never anti-aliases and drops rendering after frame 1.
- **#355** a misplaced `.msaa()` is a silent no-op.
- **#356** the capture modifier can never produce a `.gpuTraceDocument`.
- **#357** an error thrown during the workload phase aborts the process.

### What is left, and why it is mostly not worth chasing

Of the ~440 uncovered lines, the bulk is unreachable by design:

- `fatalError` / `preconditionFailure` / `assertionFailure` bodies (`Error.swift`, `StateBox`, `Parameters`,
  `System`, `Support`) — covering these would mean crashing the test process.
- `#if os(visionOS)` blocks (`RenderPass`, `ComputePass`) — not compiled on macOS.
- Defensive `Mirror` fallbacks in `SystemSnapshot` for shapes that never occur.
- Workload-phase error paths blocked on #357 (`VisibleFunctionTableModifier`, `Parameters`).

The one large genuinely reachable block left is **`CaptureModifier` (36 lines)**, which needs the test host
launched with `MTL_CAPTURE_ENABLED=1`. The tests for it already exist and skip cleanly without it. Turning that on
in `measure.sh` would raise the number without adding a single test, so it is a decision for the user, not
something to slip in mid-session.
