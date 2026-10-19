# MetalSprockets FAQ

## Why does my element not render? Why does the Metal debugger show "empty render encoder"?

### Problem
Your custom element compiles, but it does not render. The Metal debugger shows "empty render encoder", because no draw commands get to the encoder.

### Cause
Usually, the `body` property of the element returns `any Element` instead of `some Element`:

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
The framework needs concrete type information to walk the element tree. `any Element` is a type-erased existential. With it, the framework cannot walk into the child elements. It also cannot call their lifecycle methods, such as `workloadEnter` and `workloadExit`.

Debug builds assert when a body returns `any Element`. Release builds do not check.

### Solution
Use `some Element` as the return type of the `body` property. This keeps the concrete type information that the tree walk needs.

## Where can I apply `.parameter()`?

You can apply it anywhere above the ``Draw`` or ``ComputeDispatch`` that uses it. Parameters go down the tree like environment values. Each draw or dispatch finds its parameters by name, in the reflection of its enclosing pipeline.

```swift
try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
    Draw { encoder in
        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
    }
    .parameter("color", value: color)        // Only this draw
}
.parameter("uniforms", value: uniforms)      // Every draw in the pipeline
```

An inner `.parameter()` overrides an outer one with the same name. Sibling elements never see the parameters of other siblings.

Each draw must find every parameter that it inherits. If the pipeline of a draw has no binding with that name, the draw throws this error: `Parameter 'name' is not a binding of any stage the filter allows in this pipeline.` To prevent the error, apply the parameter nearer to the draws that use it.

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

## What is Ultraviolence?

"Ultraviolence" is the old codename of MetalSprockets. Old commits, documentation, and issues use this name.

## What is the relation to Apple Game Sprockets?

The name MetalSprockets comes from Apple Game Sprockets. Game Sprockets was a games framework for the classic Mac OS.
