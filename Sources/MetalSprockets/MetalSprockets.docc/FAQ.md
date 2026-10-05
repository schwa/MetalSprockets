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

### Solution
Use `some Element` as the return type for your Element's body property. This preserves the concrete type information that tree traversal needs.

### Related Issues
- [#256](https://github.com/schwa/MetalSprockets/issues/256) - Framework should detect or warn when Element body returns 'any Element'

## Why am I getting "missingEnvironment("reflection")" errors?

### Problem
You get an error like `Missing environment value: reflection` when trying to use `.parameter()` modifiers.

### Cause
This happens when `.parameter()` modifiers are applied outside of a RenderPipeline or ComputePipeline context:

```swift
// ❌ WRONG - Parameters applied outside the pipeline
return RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
    content
}
.parameter("uniforms", value: uniforms)  // Error: No reflection context here!
```

### Why This Happens
The `.parameter()` modifier uses shader reflection data to find parameter bindings. This data is available only within the RenderPipeline or ComputePipeline content closure.

### Solution
Apply `.parameter()` modifiers to elements inside the pipeline's content closure:

```swift
// ✅ CORRECT - Parameters applied inside the pipeline
return RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
    content
        .parameter("uniforms", value: uniforms)  // Reflection context available here
}
```

Parameters can then access the pipeline's reflection data.

## Why am I getting "Ambiguous parameter" errors?

### Problem
You get a fatal error like `Fatal error: Ambiguous parameter, found parameter named uniforms in both vertex (index: #1) and fragment (index: #0) shaders.`

### Cause
This occurs when vertex and fragment shaders share a parameter name, but the binding does not specify a function:

```swift
// ❌ WRONG - Ambiguous, parameter exists in both shaders
.parameter("uniforms", value: myUniforms)
```

### Why This Happens
When vertex and fragment functions share parameter names, the framework cannot determine which function the binding targets. Metal shaders often share buffer indices and names between these stages.

### Solution
Explicitly specify the function type when binding parameters that exist in multiple shader stages:

```swift
// ✅ CORRECT - Explicitly specify function type
.parameter("uniforms", functionType: .vertex, value: myUniforms)
.parameter("uniforms", functionType: .fragment, value: myUniforms)
```

Each stage can use the same value or a different value. An explicit function type identifies the target stage.

## What is Ultraviolence

MetalSprockets originally used the codename "Ultraviolence". References to "Ultraviolence" in old commits, documentation, or issues refer to this project.

## What is the relationship to Apple Game Sprockets?

The MetalSprockets name is inspired by Apple's Game Sprockets, a games framework from the classic Mac OS era.
