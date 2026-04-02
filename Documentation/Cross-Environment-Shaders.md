# Cross-environment shader headers

MetalSprockets has a set of preprocessor macros that let you write one struct definition that compiles on both the GPU (Metal) and CPU (Swift/ObjC). This is the `MetalSprocketsShaders` target.

## The problem

Metal shaders and Swift/ObjC code need to agree on struct layouts for argument buffers, vertex data, and uniforms. But the types are different — a texture on the GPU is `metal::texture2d<float, access::sample>`, while on the CPU side it's `MTLResourceID`.

Maintaining two separate definitions gets out of sync fast. These macros let you write one header that works in both places.

## The macros

All macros live in `MetalSprocketsShaders.h` and expand differently depending on whether `__METAL_VERSION__` is defined.

### Resource types

| Macro | Metal (GPU) | Swift/ObjC (CPU) |
|-------|-------------|-------------------|
| `TEXTURE2D(TYPE, ACCESS)` | `metal::texture2d<TYPE, ACCESS>` | `MTLResourceID` |
| `DEPTH2D(TYPE, ACCESS)` | `metal::depth2d<TYPE, ACCESS>` | `MTLResourceID` |
| `TEXTURECUBE(TYPE, ACCESS)` | `metal::texturecube<TYPE, ACCESS>` | `MTLResourceID` |
| `SAMPLER` | `metal::sampler` | `MTLResourceID` |
| `BUFFER(ADDRESS_SPACE, TYPE)` | `ADDRESS_SPACE TYPE` | `TYPE` |
| `ATTRIBUTE(INDEX)` | `[[attribute(INDEX)]]` | *(empty)* |

### Enum declaration

`MS_ENUM` gives you cross-environment enum declarations, modeled after `CF_ENUM`:

```c
typedef MS_ENUM(uint32_t, MyRenderMode) {
    MyRenderModeDefault = 0,
    MyRenderModeWireframe = 1,
    MyRenderModeNormals = 2,
};
```

### Example: shared argument buffer struct

```c
#import "MetalSprocketsShaders.h"

struct MyArguments {
    TEXTURE2D(float, access::sample) baseColor;
    TEXTURE2D(float, access::sample) normal;
    DEPTH2D(float, access::sample) shadow;
    SAMPLER textureSampler;
    BUFFER(constant, float4x4 *) transforms;
};
```

Include this from both `.metal` files and Swift (via a bridging/umbrella header) and the layout will match.

## Using MetalSprocketsShaders in your project

### 1. Add the dependency

In your `Package.swift`, add `MetalSprocketsShaders` as a dependency of your shaders target:

```swift
.target(
    name: "MyProjectShaders",
    dependencies: [
        .product(name: "MetalSprocketsShaders", package: "MetalSprockets"),
    ],
    exclude: ["Metal"],
    plugins: [
        .plugin(name: "MetalCompilerPlugin", package: "MetalCompilerPlugin")
    ]
),
```

### 2. Configure MetalCompilerPlugin

The Metal shader compiler doesn't use SPM's module maps, so it can't resolve `#import <MetalSprocketsShaders/MetalSprocketsShaders.h>` the way a C/ObjC compiler can. You need to tell [MetalCompilerPlugin](https://github.com/schwa/MetalCompilerPlugin) where to find headers.

Create (or update) `metal-compiler-plugin.json` in your shaders target directory:

```json
{
    "include-dependencies": true,
    "dependency-path-suffix": "include",
    "include-paths": ["include"]
}
```

What these do:

- `include-dependencies` — walk your target's SPM dependencies and add `-I` flags for each one.
- `dependency-path-suffix` — appended to each dependency's directory path. MetalSprocketsShaders (like most SPM C targets) puts public headers in `include/`, so this becomes `-I .../Sources/MetalSprocketsShaders/include`.
- `include-paths` — additional include paths relative to your own target directory. Usually `["include"]` so your own headers are found.

### 3. Import the header

In your shared header files:

```c
#pragma once

#import "MetalSprocketsShaders.h"

// Your shared structs, enums, etc.
struct MyVertexUniforms {
    float4x4 modelViewProjection;
    TEXTURE2D(float, access::sample) albedo;
};
```

**Use quoted includes (`"..."`) not angle-bracket includes (`<...>`).** The Metal compiler resolves quoted includes via `-I` paths. Angle-bracket includes need module map support that the Metal compiler doesn't have. On the CPU side both forms work, but stick with quoted includes so your headers compile everywhere.

### 4. Include from Metal shaders

Your `.metal` files include your umbrella header as usual:

```metal
#include "MyProjectShaders.h"
using namespace metal;

// MetalSprocketsShaders macros are available transitively
```

## How it works

MetalCompilerPlugin runs the `metal` compiler as a build tool plugin. It:

1. Scans the target's SPM dependency graph (when `include-dependencies` is `true`)
2. Adds `-I <target-directory>/<suffix>` for each dependency target
3. This makes headers from dependency targets discoverable via `#import "Header.h"`

The macros check `__METAL_VERSION__` (defined automatically by the Metal compiler) to decide which types to emit:

- In `.metal` files → Metal types (`metal::texture2d`, etc.)
- From ObjC/Swift → CPU types (`MTLResourceID`, etc.)

## Gotchas

- Transitive dependencies work, but every intermediate target needs to list its dependencies in `Package.swift`. The plugin walks the full graph.
- `dependency-path-suffix` applies to all dependencies the same way. If you have dependencies with different header layouts, add explicit paths via `include-paths`.
- The `float4x4` typedef (and similar SIMD aliases) is not provided by MetalSprocketsShaders. You'll need to define it yourself — the names differ between Metal (`float4x4` is built in) and CPU (`simd_float4x4`).
