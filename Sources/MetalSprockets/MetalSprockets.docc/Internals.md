# Framework Internals

Implementation details for contributors and advanced users.

## Overview

This document describes the MetalSprockets implementation. It is for contributors and developers who debug or extend the framework.

For the public API architecture, see <doc:Architecture>.

## System Class

The `System` class is the central coordinator that manages the element tree, structural identity, and processing phases.

### Key Components

- **orderedIdentifiers**: Array of StructuralIdentifiers in depth-first traversal order
- **nodes**: Dictionary mapping identifiers to Node instances
- **traversalContext**: `TraversalContext` owning the stack of nodes being visited by the current phase
- **dirtyIdentifiers**: Set of identifiers that need re-processing due to state changes

## Structural Identity

Each element's position in the tree determines its structural identity, as in SwiftUI. This provides:

- Stable identity across frames
- Efficient state preservation
- Avoiding unnecessary setup operations (like shader recompilation)

## Node System

Nodes are the runtime representation of elements:

- **Node**: Holds element instance, environment values, state properties
- Each node has a stable `StructuralIdentifier`
- Nodes persist across frames when structure is unchanged
- Parent-child relationships tracked via `parentIdentifier`

## Processing Phases

### Update Phase

Walks the element tree and updates the node graph via `System.update`:

1. Traverse element tree depth-first using `visitChildren`
2. Build structural identifiers using atom stack (stored in pre-order traversal order)
3. Compare with previous frame's structural identifiers
4. Create new nodes or reuse existing ones
5. Apply environment values and state

### Setup Phase

Runs setup operations for elements that need initialization, as the second phase of `System.render(root:)`:

- Called via `setupEnter` and `setupExit` on BodylessElements
- Used for expensive operations like shader compilation
- Only runs when element properties change
- Results cached in environment values

### Workload Phase

Executes the actual rendering work via `System.processWorkload`:

- Called via `workloadEnter` and `workloadExit` on BodylessElements
- Creates and configures Metal encoders
- Manages encoder lifetimes to obey Metal's single-encoder rule
- Handles parent-child and sibling relationships

## Known Architectural Issues

### Hidden Global Dependency in Environment Access

The framework has an architectural inconsistency in how environment values are accessed during the process phase.

#### The Problem

- `workloadEnter/Exit` and `setupEnter/Exit` methods receive a `node` parameter directly
- However, `@MSEnvironment` property wrappers cannot access this parameter
- Instead, they resolve through the `TraversalContext` reached via `System.current`

#### Why This Is Problematic

1. **Hidden coupling**: Elements appear to have local access but actually depend on global mutable state
2. **Thread safety concerns**: Global mutable state complicates concurrent processing
3. **Testing difficulties**: Tests must set up global state correctly
4. **Refactoring hazard**: Easy to break by forgetting to push/pop the traversal context

#### Potential Solutions

1. **Pass node explicitly**: Redesign @MSEnvironment to take node as parameter
2. **Context object**: Pass a context containing both node and environment
3. **Remove property wrapper**: Use explicit `node.environmentValues` access
4. **Accept the tradeoff**: Document the dependency and keep the stack valid

This limitation keeps the implementation simple but leaves a global dependency.

## Performance Considerations

### Current Optimizations

- Structural identity avoids expensive comparisons
- Setup phase results are cached
- Nodes are reused when unchanged
- Single-pass tree traversal

### Potential Optimizations

- Cache body results for unchanged elements
- Parallel processing for independent branches
- Incremental updates for large trees
- More aggressive node pooling

## Design Decisions

### Why Structural Identity?

1. **Stability**: Elements at the same position are considered "the same" across frames
2. **Performance**: Avoids comparing closures and complex properties
3. **Predictability**: Matches SwiftUI's mental model
4. **Efficiency**: Setup operations only run when truly needed

### Processing Order

Depth-first traversal and sibling handling provide:

- Metal's single-encoder rule is respected
- Parent context is available to children
- Predictable, consistent execution order
- Efficient resource management

## Future Directions

### Planned Improvements

- Pass the traversal context to elements explicitly instead of via `System.current`
- Implement proper ElementModifier protocol
- Add explicit ID support via `.id()` modifier
- Performance optimizations for large graphs

### Long-term Vision

- Move towards fully reactive dependency tracking
- Eliminate setup/workload distinction
- Support for custom processing phases
- Better debugging and profiling tools

## References

### WWDC Sessions

- [Demystify SwiftUI (WWDC 2021)](https://developer.apple.com/videos/play/wwdc2021/10022): SwiftUI's identity system

### Community Resources

- [SwiftUI Structural Identity](https://swiftwithmajid.com/2021/12/09/structural-identity-in-swiftui/)
- [Making Friends with AttributeGraph](https://saagarjha.com/blog/2024/02/27/making-friends-with-attributegraph/)

## See Also

- <doc:Architecture>
