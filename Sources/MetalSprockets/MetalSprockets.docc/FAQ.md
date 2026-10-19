# MetalSprockets FAQ

## Why is not my Element rendering anything / Why does Metal debugger show "empty render encoder"?

### Problem
Your custom Element compiles but does not render. The Metal debugger shows "empty render encoder" because no draw commands reach it.

### Cause
This typically happens when an Element's `body` property returns `any Element` instead of `some Element`:

```swift
// ❌ WRONG - This compiles but doesn't work
public var body: any Element {
    get throws {
        return RenderPipeline(...) { ... }
    }
}

// ✅ CORRECT - Use 'some Element'
public var body: some Element {
    get throws {
        return RenderPipeline(...) { ... }
    }
}
```

### Why This Happens
The framework needs concrete type information to traverse the element tree. `any Element` creates a type-erased existential. This prevents traversal into child elements and calls to their lifecycle methods, such as `workloadEnter`/`workloadExit`.

Debug builds assert when a body returns `any Element`. Release builds do not check.

### Solution
Use `some Element` as the return type for your Element's body property. This preserves the concrete type information that tree traversal needs.

## Where can I apply `.parameter()`?

Anywhere above the ``Draw`` or ``ComputeDispatch`` that uses it. Parameters flow down the tree like environment values. Each draw or dispatch resolves them by name against the reflection of its enclosing pipeline.

```swift
try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
    Draw { encoder in
        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
    }
    .parameter("color", value: color)        // Only this draw
}
.parameter("uniforms", value: uniforms)      // Every draw in the pipeline
```

An inner `.parameter()` overrides an outer one with the same name. Sibling elements never see each other's parameters.

Every draw must find each parameter it inherits. If a draw's pipeline has no binding with that name, the draw throws: `Parameter 'name' is not a binding of any stage the filter allows in this pipeline.` Apply the parameter closer to the draws that use it.

## What happens when vertex and fragment shaders share a parameter name?

By default, `.parameter()` binds the value to every stage that declares the name:

```swift
.parameter("uniforms", value: uniforms)  // Vertex and fragment both receive it
```

To send a value to one stage only, pass `functionTypes`:

```swift
.parameter("uniforms", functionTypes: .vertex, value: vertexUniforms)
.parameter("uniforms", functionTypes: .fragment, value: fragmentUniforms)
```

## What is Ultraviolence

MetalSprockets originally used the codename "Ultraviolence". References to "Ultraviolence" in old commits, documentation, or issues refer to this project.

## What is the relationship to Apple Game Sprockets?

The MetalSprockets name is inspired by Apple's Game Sprockets, a games framework from the classic Mac OS era.
