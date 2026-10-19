# MetalSprockets Architecture

## Overview

MetalSprockets is a declarative Metal rendering framework for Swift. Its design comes from SwiftUI. You compose render pipelines from elements, and you keep the performance and control of Metal.

## Core Concepts

### 1. Element Protocol

The `Element` protocol defines one unit of composition. It is like the `View` protocol in SwiftUI.

```swift
public protocol Element {
    associatedtype Body: Element
    var body: Body { get throws }
}
```

Elements make a tree. Each element does one of these:

- It returns other elements from its `body` property (compositional elements).
- It does Metal operations itself (bodyless elements).

### 2. Bodyless Elements

A bodyless element does Metal operations. It does not compose children through a `body`.
An element conforms to `SetupElement`, `WorkloadElement`, or both. The protocol tells the system which phases the element takes part in.
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

Bodyless elements use Metal command encoders directly. Only a `SetupElement` node can report `needsSetup`. Thus an element that has only a workload costs nothing in the setup phase.

### 3. Render Graph

The framework changes your element tree into Metal commands:

- The system expands elements into an internal graph of nodes.
- When state changes, the graph rebuilds only the parts that the change affects.
- Each frame has a setup phase and a workload phase. Setup runs only for nodes that need it. The workload runs every frame.

### 4. State Management

MetalSprockets has property wrappers like the ones in SwiftUI.

#### @MSState

Local state in an element:

```swift
@MSState private var rotation: Float = 0
```

#### @MSBinding

A two-way binding to state outside the element:

```swift
@MSBinding var isEnabled: Bool
```

#### @MSObservedObject

Observes changes in an external object:

```swift
@MSObservedObject var viewModel: MyViewModel
```

#### @MSEnvironment

Reads a value from the environment:

```swift
@MSEnvironment(\.device) var device
```

### 5. Environment System

The environment sends values down the element tree:

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

An element can read the environment. It can also change the environment for its children.

## Module Structure

### Core Framework (MetalSprockets)

The main framework. It contains:

- The `Element` protocol and the core types
- The state management system
- The environment system
- The built-in render elements
- Metal integration helpers

### UI Integration (MetalSprocketsUI)

SwiftUI integration. It contains:

- `RenderView`, a SwiftUI view for Metal rendering
- `MTKView` integration
- A bridge between the SwiftUI environment and the MetalSprockets environment

### Support Utilities (MetalSprocketsSupport)

Support utilities and extensions. It contains:

- Metal helpers and extensions
- Error types (`MetalSprocketsError`)
- Logging utilities
- The `@MSEntry` macro

### Macros (MetalSprocketsMacros)

The compiler plugin that implements `@MSEntry`. The macro generates the key type and the accessor for a custom ``MSEnvironmentValues`` property. To use the macro, import `MetalSprocketsSupport`.

### Shaders

Metal shader libraries:

- **MetalSprocketsShaders**: Shared Metal headers for MetalSprockets shaders
- **MetalSprocketsUIShaders**: Shaders for MetalSprocketsUI, such as `YCbCrBillboardRenderPass`

The `Example` folder contains a demo app. The demo app is not part of the package products.

## Rendering Pipeline

### 1. Setup Phase

The system runs three phases in this order: update, setup, and workload. `System.render(root:)` runs all three:

```swift
try system.render(root: root)
```

The setup phase does work that is too expensive for each frame:

- It creates Metal pipeline states.
- It allocates buffers.
- It loads textures and other resources.
- It compiles shaders.

### 2. Workload Phase

The workload phase runs every frame. It is the last phase of `render(root:)`:

- It encodes render commands.
- It updates uniforms and buffers.
- It runs compute kernels.
- It issues draw calls.

### 3. Element Lifecycle

1. **Element creation**: Your code makes elements declaratively.
2. **Node expansion**: The system expands elements into nodes in the graph.
3. **Setup**: The system does the setup work that nodes need.
4. **Workload**: The system encodes the work for the frame.
5. **State updates**: When a property changes, the system rebuilds only the affected nodes.

### 4. Environment Flow

Environment values go down the element tree:

#### Example

```
RootElement (env: device, commandQueue)
├── RenderPass (env: + renderPassDescriptor)
│   ├── Draw (env: + renderEncoder)
│   │   └── Parameters (env: unchanged)
│   └── Draw (env: + renderEncoder)
└── ComputePass (env: + computeEncoder)
```

#### Key Environment Values

- **Device and queue**: The root sets them.
- **Command buffer**: The root makes one for each frame.
- **Encoders**: Pass elements make them.
- **Descriptors**: Modifier elements change them.
- **Custom values**: You define them.

### 5. Command Buffer Structure

The root (``Runner``, ``OffscreenRenderer``, or `RenderView`) owns one Metal 4 command buffer for each frame:

```
MTL4CommandBuffer
├── MTL4RenderCommandEncoder (RenderPass)
│   ├── Draw / RenderCommand
│   └── Parameters, textures, samplers (argument tables)
└── MTL4ComputeCommandEncoder (ComputePass)
    ├── ComputeDispatch
    └── ComputeCommand (copies and fills)
```

The commands in a pass do not have an automatic order.
To order them, use ``EncoderBarrier``, ``QueueBarrier``, or ``Element/barrierAfterPass(after:beforeQueueStages:visibility:)``.
To observe commit and completion, attach `onSubmissionCommitted` and `onCommandBufferCompleted`.

## Key Patterns

### Composition

You make complex render pipelines from elements:

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

Modifiers configure the render state:

```swift
element
    .renderPipelineDescriptorTransformer { descriptor in
        descriptor.isAlphaToCoverageEnabled = true
    }
    .depthBias(-0.001)
```

### Environment Injection

Send values down the tree:

```swift
MyScene()
    .device(metalDevice)
    .environment(\.myCustomValue, value)
```

Elements have modifiers for the device, the render pass descriptor, the render pipeline descriptor, the current drawable, and the drawable size.
For custom keys, use `environment(_:_:)`.

In SwiftUI, `RenderView` reads the device and the command queue from the SwiftUI environment. Set them with `.environment(\.device, device)` and `.environment(\.commandQueue, queue)`.

### Conditional Rendering

The content can change with state:

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

`ShaderLibrary` loads shaders with type safety:

```swift
let library = try ShaderLibrary(bundle: .module)
let vertexShader: VertexShader = library.vertex_main
let fragmentShader = try library.function(type: FragmentShader.self, named: "fragment_main")
```

### Parameter Binding

Parameters bind by name. The system uses the reflection of the pipeline to find each binding. A value goes to every stage that declares the name. To select stages, pass `functionTypes`:

```swift
Draw { encoder in /* ... */ }
    .parameter("transforms", functionTypes: .vertex, value: transforms)
    .parameter("material", functionTypes: .fragment, value: material)
```

To set many values in one modifier, use ``Element/parameters(_:)``.

### Resource Management

The framework manages the lifecycle of resources:

- It loads textures when an element needs them.
- It allocates buffers when an element needs them.
- It caches pipeline states and uses them again.

## Threading Model

Each `System` stays in one isolation context:

- **Owning isolation**: Element updates, setup, and command encoding run synchronously on the isolation that drives the system. For `RenderView`, this is the main thread, through `MTKViewDelegate`.
- **GPU**: The GPU runs the command buffer asynchronously after the commit.

### Rules

`System` is `@unchecked Sendable` because each instance stays in one isolation. Do not share an instance across isolations.

- The node stack of the traversal context has no synchronization. Only the owning isolation can do a traversal.
- `@MSEnvironment` gets its value from the current traversal context. Thus it works only during a traversal.
- You can write `@MSState` from other threads. For example, an `onCommandBufferCompleted` handler can write state. The system records the change under a lock. The next update applies it.

### SwiftUI Integration

In `RenderView`, the MetalKit callback `MTKViewDelegate.draw(in:)` drives the render loop. This callback runs on the main thread. All MetalSprockets work for the view occurs there.

## Performance

- **Selective rebuild**: When state changes, only the affected parts rebuild.
- **Resource cache**: The system caches pipeline states and shaders.

## Extension Points

### Custom Elements

To make a custom element, conform to `Element`:

```swift
struct MyCustomElement: Element {
    var body: some Element {
        // Custom composition
    }
}
```

### Direct Metal Encoding

The bodyless element protocols are internal. To encode Metal commands yourself, use the encoder closures:

- ``Draw`` for draws, with the state of the enclosing pipeline bound
- ``RenderCommand`` for raw access to the render encoder
- ``ComputeCommand`` for copies, fills, and other compute-encoder work

### Environment Keys

To add a custom environment value:

```swift
import MetalSprocketsSupport

extension MSEnvironmentValues {
    @MSEntry var myCustomValue: MyType = MyType()
}
```

You can also conform a key type to ``MSEnvironmentKey`` and write the accessor yourself.

## Best Practices

1. **Keep elements small**: Give each element one responsibility.
2. **Use composition**: Make complex scenes from small elements that you can use again.
3. **Keep state small**: Use state only where it is necessary.
4. **Use the environment**: Share values across the tree through the environment.
5. **Cache resources**: Use Metal resources again when you can.
6. **Measure performance**: To find bottlenecks, use Metal System Trace.

### Element and Modifier Equality

The reconciler uses equality to decide if it can use a previous subtree again. A subtree can be clean and have a stable environment. In that subtree, equal elements skip body evaluation and child traversal.

A custom `Equatable` conformance takes precedence over structural comparison. The equality must include all inputs that affect the element or its children. This includes the wrapped `content`.

Rules for element authors:

- Do not compare only the label or the render settings of a modifier. Also compare its `content`.
- For struct wrappers, use the default structural comparison. Write a custom comparison only when it is necessary and complete.
- Keep `requiresSetup(comparedTo:)` separate from subtree equality. It controls setup work. It does not control child updates.
- Add regression tests. In these tests, keep the modifier settings the same, and change child values and resource references across updates.
- Include nested modifiers and unchanged content in these tests.

In issue #477, `DebugGroupModifier` compared only its label. `DepthBiasModifier` compared only its bias settings. Both comparisons ignored `content`. As a result, the reconciler used stale children again. The fix removed these conformances, so structural comparison, including `content`, applies again.

The regression tests are in `Tests/MetalSprocketsTests/ModifierContentReconciliationTests.swift`.

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
