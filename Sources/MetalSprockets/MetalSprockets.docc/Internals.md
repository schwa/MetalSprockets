# Framework Internals

Implementation details for contributors and advanced users.

## Overview

This article describes the implementation of MetalSprockets. It is for contributors, and for developers who debug or extend the framework.

For the architecture of the public API, see <doc:Architecture>.

## System Class

The `System` class is the central coordinator. It manages the element tree, structural identity, and the processing phases.

### Key Components

- **nodes**: A dictionary from identifiers to `Node` instances.
- **traversalEvents**: The sequence of enter and exit events that the last update recorded. The setup and workload phases replay it.
- **traversalContext**: The `TraversalContext` that holds the stack of nodes that the current phase visits.
- **dirtyIdentifiers**: The identifiers of nodes that a state change makes dirty. A lock protects this set, because `@MSState` writes can come from other threads. For example, an `onCommandBufferCompleted` handler can write state.

## Structural Identity

The position of an element in the tree gives its structural identity, as in SwiftUI. This identity gives:

- Stable identity across frames
- State that stays with the element
- No unnecessary setup work, such as shader compilation

To make identity follow data instead of position, use the `id(_:)` modifier.

## Node System

Nodes are the runtime form of elements:

- A **node** holds the element instance, the environment values, and the state properties.
- Each node has a stable `StructuralIdentifier`.
- When the structure does not change, nodes stay across frames.
- `parentIdentifier` records the parent of each node.

## Processing Phases

### Update Phase

`System.update(root:)` walks the element tree and updates the node graph:

1. It walks the element tree depth-first with `visitChildren`.
2. It builds structural identifiers with an atom stack, in pre-order.
3. It compares them with the structural identifiers of the previous frame.
4. It makes new nodes or uses existing nodes again.
5. It applies environment values and state.

### Setup Phase

The setup phase is the second phase of `System.render(root:)`. It does setup work for elements that need it:

- The system calls `setupEnter` and `setupExit` on elements that conform to `SetupElement`.
- Setup does expensive work, such as shader compilation.
- Setup runs only when the properties of an element change.
- The results go into environment values and node caches.

### Workload Phase

The workload phase is the last phase of `System.render(root:)`. It does the render work:

- The system calls `workloadEnter` and `workloadExit` on elements that conform to `WorkloadElement`.
- It creates and configures Metal encoders.
- It manages the lifetime of encoders, so that only one encoder is open at a time.
- It handles parent-child and sibling relations.

## Known Architectural Issues

### Hidden Global Dependency in Environment Access

During the setup and workload phases, the framework reads environment values in two different ways.

#### The Problem

- The `workloadEnter`, `workloadExit`, `setupEnter`, and `setupExit` methods get a `node` parameter directly.
- The `@MSEnvironment` property wrapper cannot get this parameter.
- Instead, it reads through the `TraversalContext`, which it finds through `System.current`.

#### Why This Is a Problem

1. **Hidden coupling**: Elements seem to have local access, but they use global mutable state.
2. **Thread safety**: Global mutable state makes concurrent processing difficult.
3. **Tests**: Tests must set up the global state correctly.
4. **Refactor risk**: If code does not push and pop the traversal context, it breaks.

#### Possible Solutions

1. **Pass the node explicitly**: Change `@MSEnvironment` to take the node as a parameter.
2. **Context object**: Pass a context that contains the node and the environment.
3. **Remove the property wrapper**: Use `node.environmentValues` directly.
4. **Accept the tradeoff**: Document the dependency, and keep the stack valid.

The current design keeps the implementation simple, but it has a global dependency.

## Performance

### Current Optimizations

- Structural identity prevents expensive comparisons.
- The system caches the results of the setup phase.
- The system uses unchanged nodes again.
- The system skips clean subtrees when their environment is stable (#370).

### Possible Optimizations

- Parallel processing for independent branches
- Incremental updates for large trees
- More node pooling

## Design Decisions

### Why Structural Identity?

1. **Stability**: Elements at the same position are "the same" across frames.
2. **Performance**: The system does not compare closures and complex properties.
3. **Predictability**: It matches the mental model of SwiftUI.
4. **Efficiency**: Setup runs only when it is necessary.

### Processing Order

The traversal is depth-first and visits siblings in order. This gives:

- Only one Metal encoder at a time
- Parent context that is available to children
- An execution order that is the same every time

## Future Directions

### Planned Improvements

- Pass the traversal context to elements explicitly, instead of through `System.current`
- A real `ElementModifier` protocol
- Optimizations for large graphs

### Long-Term Vision

- Fully reactive dependency tracking
- No separate setup and workload phases
- Custom processing phases
- Better tools for debugging and profiling

## References

### WWDC Sessions

- [Demystify SwiftUI (WWDC 2021)](https://developer.apple.com/videos/play/wwdc2021/10022): The identity system of SwiftUI

### Community Resources

- [SwiftUI Structural Identity](https://swiftwithmajid.com/2021/12/09/structural-identity-in-swiftui/)
- [Making Friends with AttributeGraph](https://saagarjha.com/blog/2024/02/27/making-friends-with-attributegraph/)

## See Also

- <doc:Architecture>
