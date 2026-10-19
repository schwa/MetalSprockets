# MetalSprockets Architecture

## Overview

MetalSprockets is a declarative Metal rendering framework for Swift, based on SwiftUI's architecture. Its API composes rendering pipelines while preserving Metal's performance and flexibility.

## Core Concepts

### 1. Element Protocol

The `Element` protocol defines a unit of MetalSprockets composition, like SwiftUI's `View` protocol.

```swift
public protocol Element {
    associatedtype Body: Element
    var body: Body { get throws }
}
```

Elements compose hierarchically to form a rendering tree. Each element can either:

- Return other elements via its `body` property (compositional elements)
- Perform actual Metal operations (bodyless elements)

### 2. BodylessElement

`BodylessElement` represents elements that perform Metal operations rather than compose children.
An element conforms to `SetupElement`, `WorkloadElement`, or both to specify its processing phases.
These protocols are internal to the framework:

```swift
protocol BodylessElement {
    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws
    func configureNodeBodyless(_ node: Node) throws
    func teardown(_ node: Node) throws
    func skipsWorkload(_ node: Node) -> Bool
    func requiresSetup(comparedTo old: Self) -> Bool
}

protocol SetupElement: BodylessElement {
    func setupEnter(_ node: Node) throws
    func setupExit(_ node: Node) throws
}

protocol WorkloadElement: BodylessElement {
    func workloadEnter(_ node: Node) throws
    func workloadExit(_ node: Node) throws
}
```

These elements interact directly with Metal command encoders and perform rendering operations. Only `SetupElement`
nodes ever report `needsSetup`, so a workload-only element costs nothing in the setup phase.

### 3. Rendering Graph

The framework manages a graph that transforms your declarative element tree into Metal commands:

- Elements are expanded into an internal graph structure
- The graph handles state changes and selective rebuilding
- Two-phase processing: setup (one-time) and workload (per-frame)

### 4. State Management

MetalSprockets provides SwiftUI-like property wrappers for state management:

#### @MSState

Local state within an element:

```swift
@MSState private var rotation: Float = 0
```

#### @MSBinding

Two-way binding to external state:

```swift
@MSBinding var isEnabled: Bool
```

#### @MSObservedObject

Observe changes in external objects:

```swift
@MSObservedObject var viewModel: MyViewModel
```

#### @MSEnvironment

Access values from the environment:

```swift
@MSEnvironment(\.device) var device
```

### 5. Environment System

The environment propagates values down the element tree:

```swift
public struct MSEnvironmentValues {
    // Predefined environment keys
    var device: MTLDevice?
    var commandQueue: (any MTL4CommandQueue)?
    var commandBuffer: (any MTL4CommandBuffer)?
    var renderPassDescriptor: MTL4RenderPassDescriptor?
    // ... and more
}
```

Elements can read from and modify the environment for their children.

## Module Structure

### Core Framework (MetalSprockets)

The main framework containing:

- Element protocol and core types
- State management system
- Environment system
- Built-in rendering elements
- Metal integration helpers

### UI Integration (MetalSprocketsUI)

SwiftUI integration components:

- `RenderView`: SwiftUI view for Metal rendering
- `MTKView` integration
- SwiftUI environment bridging

### Support Utilities (MetalSprocketsSupport)

Supporting utilities and extensions:

- Metal helpers and extensions
- Error types (`MetalSprocketsError`)
- Logging utilities
- The `@MSEntry` macro

### Macros (MetalSprocketsMacros)

The compiler plugin that implements `@MSEntry`. The macro generates the key type and accessor for a custom ``MSEnvironmentValues`` property. Import `MetalSprocketsSupport` to use it.

### Shaders

Metal shader libraries:

- **MetalSprocketsShaders**: Shared Metal headers for MetalSprockets shaders
- **MetalSprocketsUIShaders**: Shaders used by MetalSprocketsUI, such as `YCbCrBillboardRenderPass`

The `Example` folder contains a demo app that is not part of the package products.

## Rendering Pipeline

### 1. Setup Phase

The setup phase occurs once when the element tree is built. `System.render(root:)` runs update, setup, and workload in order, rather than driving each phase separately:

```swift
try system.render(root: root)
```

- Creates Metal pipeline states
- Allocates buffers
- Loads textures and resources
- Compiles shaders

### 2. Workload Phase

The workload phase executes for each frame, as the last phase of `render(root:)`:

- Encodes rendering commands
- Updates uniforms and buffers
- Executes compute kernels
- Performs draw calls

### 3. Element Lifecycle

1. **Element Creation**: Elements are instantiated declaratively
2. **Node Expansion**: Elements expand into nodes in the graph
3. **Setup Processing**: One-time setup operations
4. **Workload Processing**: Per-frame rendering operations
5. **State Updates**: Property changes trigger selective rebuilding


### 4. Environment Propagation

Environment values flow down the element tree:

#### Environment Flow Example

```
RootElement (env: device, commandQueue)
├── RenderPass (env: + renderPassDescriptor)
│   ├── Draw (env: + renderEncoder)
│   │   └── Parameters (env: unchanged)
│   └── Draw (env: + renderEncoder)
└── ComputePass (env: + computeEncoder)
```

#### Key Environment Values

- **Device & Queue**: Set at the root level
- **Command Buffer**: Created per frame
- **Encoders**: Created by pass elements
- **Descriptors**: Modified by modifier elements
- **Custom Values**: User-defined values

### 5. Command Buffer Structure

The root (``Runner``, ``OffscreenRenderer``, `RenderView`) owns a Metal 4 command buffer for each frame:

```
MTL4CommandBuffer
├── MTL4RenderCommandEncoder (RenderPass)
│   ├── Draw / RenderCommand
│   └── Parameters, textures, samplers (argument tables)
└── MTL4ComputeCommandEncoder (ComputePass)
    ├── ComputeDispatch
    └── ComputeCommand (copies and fills)
```

Commands inside a pass are not ordered automatically.
Use ``EncoderBarrier``, ``QueueBarrier`` or ``Element/barrierAfterPass(after:beforeQueueStages:visibility:)`` to order them.
Attach `onSubmissionCommitted` and `onCommandBufferCompleted` to observe commit and completion.

## Key Patterns

### Composition

Elements compose to build complex rendering pipelines:

```swift
struct MyScene: Element {
    let library: ShaderLibrary
    let vertices: [Vertex]
    let transforms: Transforms

    var body: some Element {
        get throws {
            try RenderPass {
                try RenderPipeline(vertexShader: library.vertex_main, fragmentShader: library.fragment_main) {
                    Draw { encoder in
                        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: vertices.count)
                    }
                    .vertexValues(vertices, index: 0)
                    .parameter("transforms", value: transforms)
                }
                .vertexDescriptor(Vertex.descriptor)
            }
        }
    }
}
```

### Modifiers

Modifiers configure rendering state:

```swift
element
    .renderPipelineDescriptorTransformer { descriptor in
        descriptor.isAlphaToCoverageEnabled = true
    }
    .depthBias(-0.001)
```

### Environment Injection

Pass values down the tree:

```swift
MyScene()
    .device(metalDevice)
    .environment(\.myCustomValue, value)
```

Elements have convenience modifiers for the device, render pass and pipeline descriptors, current drawable, and drawable size.
`environment(_:_:)` supports custom keys. In SwiftUI, `RenderView` reads the device and command queue from the SwiftUI environment: `.environment(\.device, device)` and `.environment(\.commandQueue, queue)`.

### Conditional Rendering

Dynamic content based on state:

```swift
var body: some Element {
    if showWireframe {
        WireframeRenderer(mesh: mesh)
    } else {
        SolidRenderer(mesh: mesh)
    }
}
```

## Metal Integration

### Shader Management

The `ShaderLibrary` provides type-safe shader loading:

```swift
let library = try ShaderLibrary(bundle: .module)
let vertexShader: VertexShader = library.vertex_main
let fragmentShader = try library.function(type: FragmentShader.self, named: "fragment_main")
```

### Parameter Binding

Parameters bind by name, using the pipeline's reflection. A value goes to every stage that declares the name, unless you pass `functionTypes`:

```swift
Draw { encoder in /* ... */ }
    .parameter("transforms", functionTypes: .vertex, value: transforms)
    .parameter("material", functionTypes: .fragment, value: material)
```

Use ``Element/parameters(_:)`` to set several values in one modifier.

### Resource Management

Automatic resource lifecycle management:

- Textures loaded on demand
- Buffers allocated as needed
- Pipeline states cached and reused

## Threading Model

Each `System` is confined to one isolation context:

- **Owning isolation**: Element updates, setup, and command encoding run synchronously on the isolation that drives the system. For `RenderView`, this is the main thread through `MTKViewDelegate`.
- **GPU**: Command buffer execution happens asynchronously after commit.

### Rules

`System` is `@unchecked Sendable` because each instance stays in one isolation. Do not share an instance across isolations.

- The traversal context's node stack has no synchronization. Only the owning isolation may traverse.
- `@MSEnvironment` resolves through the current traversal context, so it works only during a traversal.
- `@MSState` writes from other threads are safe. For example, an `onCommandBufferCompleted` handler can write state. The system records the change under a lock and applies it at the next update.

### SwiftUI Integration

In `RenderView`, MetalKit's `MTKViewDelegate.draw(in:)` drives the render loop. This callback runs on the main thread, where all MetalSprockets processing occurs.

## Performance Considerations

- **Selective Rebuilding**: Only affected parts rebuild when state changes
- **Resource Caching**: Pipeline states and shaders are cached
- **Command Buffer Optimization**: Commands are batched efficiently

## Extension Points

### Custom Elements

Create custom elements by conforming to `Element`:

```swift
struct MyCustomElement: Element {
    var body: some Element {
        // Custom composition
    }
}
```

### Direct Metal Encoding

The bodyless element protocols are internal. To encode Metal commands yourself, use the encoder closures:

- ``Draw`` for draws with the enclosing pipeline's state bound
- ``RenderCommand`` for raw access to the render encoder
- ``ComputeCommand`` for copies, fills, and other compute-encoder work

### Environment Keys

Add custom environment values:

```swift
import MetalSprocketsSupport

extension MSEnvironmentValues {
    @MSEntry var myCustomValue: MyType = MyType()
}
```

You can also conform a key type to ``MSEnvironmentKey`` and write the accessor yourself.

## Best Practices

1. **Keep Elements Small**: Give each element one responsibility
2. **Use Composition**: Build complex scenes from simple, reusable elements
3. **Minimize State**: Only use state where necessary for performance
4. **Use the Environment**: Share values across the tree through the environment
5. **Cache Resources**: Reuse Metal resources when possible
6. **Profile Performance**: Use Metal System Trace to identify bottlenecks

### Element and Modifier Equality

The reconciler uses equality to decide whether it can reuse a previous subtree. For a clean subtree with a stable environment, equal elements can skip body evaluation and child traversal.

A custom `Equatable` conformance takes precedence over structural comparison. Equality must account for all inputs that affect the element or its children, including wrapped `content`.

Guidelines for element authors:

- Do not compare only a modifier's label or rendering settings while ignoring its `content`.
- For struct wrappers, prefer the default structural comparison unless a complete custom comparison is necessary.
- Keep `requiresSetup(comparedTo:)` separate from subtree equality. It controls setup work, not whether children need updates.
- Add regression tests that keep modifier settings constant while changing child values and resource references across updates.
- Include nested modifiers and unchanged-content cases in those tests.

In issue #477, `DebugGroupModifier` compared only its label, and `DepthBiasModifier` compared only its bias settings. Both comparisons ignored `content`, so the reconciler could reuse stale children. Removing these conformances restored structural comparison, including `content`.

Regression coverage: `Tests/MetalSprocketsTests/ModifierContentReconciliationTests.swift`.

## Comparison with SwiftUI

| Aspect        | SwiftUI          | MetalSprockets          |
| ------------- | ---------------- | ---------------------- |
| Core Protocol | View             | Element                |
| Composition   | Views            | Elements               |
| State         | @State, @Binding | @MSState, @MSBinding   |
| Environment   | @Environment     | @MSEnvironment         |
| Output        | UI Elements      | Metal Commands         |
| Rebuild       | Diffing          | Selective Node Updates |

## See Also

- <doc:GettingStarted>
- <doc:Internals>
- <doc:FAQ>
