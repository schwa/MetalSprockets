/// A framework-internal marker protocol for per-node, per-element caches.
///
/// Elements whose `setupEnter` phase builds expensive Metal state (pipeline
/// state objects, compiled descriptors, reflections) may want to reuse that
/// state across frames when their inputs haven't changed. Rather than trying
/// to make `requiresSetup(comparedTo:)` reason about environment-driven
/// inputs it can't see, an element can:
///
/// 1. Return `true` from `requiresSetup(comparedTo:)` so setup runs every frame.
/// 2. Maintain a typed subclass of `NodeElementCache` via ``Node/cache(_:make:)``.
/// 3. Key the cache on whatever inputs actually affect the built state
///    (function identity, env-provided linked functions, label, etc.).
///
/// On a cache hit the element restores its cached outputs into the node's
/// environment and returns early — making the "rebuild" a dictionary read.
///
/// Cache objects live as long as the owning ``Node``. When the node is torn
/// down or reused for a different element type, the cache is released.
internal protocol NodeElementCache: AnyObject {}
