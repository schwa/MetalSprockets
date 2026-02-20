# <img src="Documentation/MetalSprockets.png" width="40" alt="MetalSprockets"> [MetalSprockets](https://github.com/schwa/MetalSprockets)

> "It's like SwiftUI — but for Metal."

MetalSprockets is a Swift package that brings a **declarative, composable** layer to Metal.

## [Documentation](https://schwa.github.io/MetalSprockets)

- [Getting Started](https://schwa.github.io/MetalSprockets/documentation/metalsprockets/gettingstarted)
- [Tutorials](https://schwa.github.io/MetalSprockets/documentation/metalsprockets/tutorialoverview)
- [Architecture](https://schwa.github.io/MetalSprockets/documentation/metalsprockets/architecture)
- [FAQ](https://schwa.github.io/MetalSprockets/documentation/metalsprockets/faq)

---

## Why MetalSprockets?

Metal is powerful but verbose. Setting up a render pass requires dozens of lines of boilerplate: descriptors, pipeline states, encoder configuration, manual buffer indices. Combining render and compute passes means juggling resources and synchronization by hand. Mistakes are easy and debugging is painful.

MetalSprockets fixes this:

- **Less boilerplate** — Declarative API eliminates repetitive setup code
- **Type safety** — Catch (more) errors at compile time, not in GPU frame captures
- **Easy composition** — Combine render passes, compute shaders, and mesh pipelines naturally
- **Better Swift ↔ Metal interface** — Bind parameters by name, not magic buffer indices

---

## Highlights

- **Declarative & composable:**
  Compose your GPU workload as a tree of `Element`s — each representing a _pass_, _pipeline_, or composition of both.
  Combine them naturally with Swift result builders to create render graphs in pure Swift.

- **SwiftUI-inspired design:**
  `Element` ≈ `View`. Property wrappers like `@MSState`, `@MSBinding`, and `@MSEnvironment` mirror SwiftUI's data-flow model.

- **Automatic resource binding:**
  Forget manual Metal shader uniform/buffer/texture indices.
  The `.parameter()` API uses **reflection** to bind values by name across shader stages.

- **Unified graph for all GPU stages:**
  Mix render, compute, mesh, and object shaders in a single graph.

- **SwiftUI, ARKit, and visionOS:**
  Render to SwiftUI views with `RenderView`, ARKit camera sessions on iOS, visionOS immersive spaces, or offscreen with `OffscreenRenderer`.

---

## Requirements

- Apple Silicon Mac, iOS, or visionOS device
- Swift 6.1 / Xcode 16+
- **Apple GPUs only:** Intel Macs are not supported.

---

## Installation

Add via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/schwa/MetalSprockets", branch: "main")
]
```

Or in Xcode: **File ▸ Add Packages…** and paste the repo URL.

Link `MetalSprockets` and `MetalSprocketsUI` in your target.

---

## Quick Start

See the [Tutorials](https://schwa.github.io/MetalSprockets/documentation/metalsprockets/tutorialoverview) in the documentation.

---

## Companion Repositories

- [MetalSprocketsTutorials](https://github.com/schwa/MetalSprocketsTutorials) — Step-by-step tutorial companion code
- [MetalSprocketsExamples](https://github.com/schwa/MetalSprocketsExamples) — Larger example projects
- [MetalSprocketsAddOns](https://github.com/schwa/MetalSprocketsAddOns) — Additional Elements and utilities
- [MetalSprocketsGaussianSplats](https://github.com/schwa/MetalSprocketsGaussianSplats) — Gaussian splatting renderer

---

## Environment Variables

MetalSprockets supports several environment variables for debugging and development. Set these in Xcode's scheme editor or in your shell.

| Variable | Description |
|----------|-------------|
| `LOGGING` | Enable general logging output |
| `VERBOSE` | Enable verbose logging (more detailed output) |
| `METAL_LOGGING` | Enable Metal-specific logging |
| `FATALERROR_ON_THROW` | Convert thrown errors to fatal errors for easier debugging |
| `RENDERVIEW_LOG_FRAME` | Log frame rendering information in RenderView |
| `MS_DUMP_SNAPSHOTS` | Dump system snapshots to JSONL files in `$TMPDIR/metal-sprockets_snapshots/` for debugging the element tree |

Truthy values: `yes`, `true`, `y`, `1`, `on` (case-insensitive).

---

## License

MIT — see [LICENSE](LICENSE)

---

## Links

- [Swift Package Index](https://swiftpackageindex.com/schwa/MetalSprockets)
- [MetalCompilerPlugin](https://github.com/schwa/MetalCompilerPlugin)
