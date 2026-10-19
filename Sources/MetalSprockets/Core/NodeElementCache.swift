/// A framework-internal marker protocol for per-node, per-element caches.
///
/// Some elements build expensive Metal state in `setupEnter` (pipeline state
/// objects, compiled descriptors, reflections). These elements can reuse that
/// state across frames when their inputs do not change.
/// `requiresSetup(comparedTo:)` cannot see inputs that come from the
/// environment. Instead, an element can:
///
/// 1. Return `true` from `requiresSetup(comparedTo:)` so setup runs every frame.
/// 2. Maintain a typed subclass of `NodeElementCache` via ``Node/cache(_:make:)``.
/// 3. Key the cache on whatever inputs actually affect the built state
///    (function identity, linked functions from the environment, label).
///
/// On a cache hit the element restores its cached outputs into the node's
/// environment and returns early — making the "rebuild" a dictionary read.
///
/// Cache objects live as long as the owning ``Node``. When the node is torn
/// down or reused for a different element type, the cache is released.
internal protocol NodeElementCache: AnyObject {}
