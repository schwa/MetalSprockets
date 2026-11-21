/// A cached value and the entries it depends on. Whoever holds the entry keeps it, and its dependencies, cached.
internal final class CacheEntry<Value> {
    let value: Value
    private let dependencies: [AnyObject]

    init(_ value: Value, dependencies: [AnyObject] = []) {
        self.value = value
        self.dependencies = dependencies
    }
}

/// A cache that holds its entries weakly, so an entry is released when nothing uses it any more (#535).
///
/// Users keep an entry alive by holding it, for example in a pipeline value stored in a node's environment.
internal struct EvictingCache<Key: Hashable, Value> {
    private var entries: [Key: WeakBox<CacheEntry<Value>>] = [:]

    subscript(key: Key) -> CacheEntry<Value>? {
        entries[key]?.wrappedValue
    }

    /// Caches `value`, and drops entries that were released.
    mutating func insert(_ value: Value, dependencies: [AnyObject] = [], for key: Key) -> CacheEntry<Value> {
        entries = entries.filter { $0.value.wrappedValue != nil }
        let entry = CacheEntry(value, dependencies: dependencies)
        entries[key] = WeakBox(entry)
        return entry
    }

    /// The number of entries still in use.
    var count: Int {
        entries.values.count { $0.wrappedValue != nil }
    }
}
