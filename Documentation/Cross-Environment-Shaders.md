# Cross-environment shader headers

The `MetalSprocketsShaders` target provides preprocessor macros for shared struct definitions. One definition compiles for both the GPU (Metal) and CPU (Swift/ObjC).

## The problem

Metal shaders and Swift/ObjC code need matching struct layouts for argument buffers, vertex data, and uniforms. The resource types differ. For example, a texture uses `metal::texture2d<float, access::sample>` on the GPU and `MTLResourceID` on the CPU.

Separate definitions can differ by mistake. These macros provide one header for both environments.

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

Include this definition from `.metal` files and through a bridging or umbrella header for Swift. Both environments then use the same layout.

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

The Metal shader compiler does not use SPM module maps. It cannot resolve `#import <MetalSprocketsShaders/MetalSprocketsShaders.h>` as a C/ObjC compiler does.

Configure the header paths in [MetalCompilerPlugin](https://github.com/schwa/MetalCompilerPlugin).

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

**Use quoted includes (`"..."`), not angle-bracket includes (`<...>`).** The Metal compiler resolves quoted includes through `-I` paths. Angle-bracket includes need module map support, which the Metal compiler does not provide. Both forms work on the CPU. Quoted includes work in both environments.

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
- From Swift → CPU types (`MTLResourceID`, etc.)

## Constraints

- Transitive dependencies work, but every intermediate target needs to list its dependencies in `Package.swift`. The plugin walks the full graph.
- `dependency-path-suffix` applies to all dependencies. If dependencies use different header layouts, add explicit paths through `include-paths`.
