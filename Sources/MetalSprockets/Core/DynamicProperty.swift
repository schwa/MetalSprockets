// MARK: - MSDynamicProperty

/// A property wrapper that participates in an element's update pass.
///
/// `MSDynamicProperty` is analogous to SwiftUI's `DynamicProperty`. The System discovers
/// conforming property wrappers on an element and gives them two chances to act around each
/// update: ``update(in:)`` before the element's body is evaluated, and ``persist(in:)`` after.
///
/// ## Overview
///
/// The built-in wrappers (``MSState``, ``MSObservedObject``) conform to this protocol. Adopt it
/// to write your own wrapper that needs per-node storage, dependency registration, or
/// environment access:
///
/// ```swift
/// @propertyWrapper
/// struct FrameCounter: MSDynamicProperty {
///     private let box = Box(0)
///
///     var wrappedValue: Int { box.value }
///
///     func update(in context: MSDynamicPropertyContext) {
///         box.value = (context.persistedValue(forKey: context.label) as? Int ?? 0) + 1
///     }
///
///     func persist(in context: MSDynamicPropertyContext) {
///         context.setPersistedValue(box.value, forKey: context.label)
///     }
/// }
/// ```
///
/// Both requirements have default no-op implementations, so conformers only implement the phase
/// they need.
///
/// ## Topics
///
/// ### Related Types
/// - ``MSDynamicPropertyContext``
public protocol MSDynamicProperty {
    /// Prepares the property for this update, before the element's body is evaluated.
    ///
    /// Restore persisted storage, register dependencies, or read the environment here.
    nonmutating func update(in context: MSDynamicPropertyContext) throws

    /// Persists anything the System should carry over to the next update.
    nonmutating func persist(in context: MSDynamicPropertyContext) throws
}

public extension MSDynamicProperty {
    nonmutating func update(in context: MSDynamicPropertyContext) throws {
        // Default: nothing to prepare.
    }

    nonmutating func persist(in context: MSDynamicPropertyContext) throws {
        // Default: nothing to carry over.
    }
}

// MARK: - MSDynamicPropertyContext

/// The per-node context handed to an ``MSDynamicProperty`` during an element's update.
///
/// A context is scoped to one property on one node: ``label`` identifies the property, and the
/// persistence methods are keyed so several properties on the same element don't collide.
public struct MSDynamicPropertyContext {
    internal let node: Node

    /// The declared name of the property this context belongs to, including the property
    /// wrapper's leading underscore (for example `_rotation`).
    public let label: String

    internal init(node: Node, label: String) {
        self.node = node
        self.label = label
    }

    /// The environment values visible to this node.
    public var environmentValues: MSEnvironmentValues {
        node.environmentValues
    }

    /// Returns a value previously stored with ``setPersistedValue(_:forKey:)``.
    ///
    /// Storage lives on the node, so it survives the element value being recreated as long as
    /// the node keeps its structural identity.
    ///
    /// - Parameter key: The storage key. Use ``label`` unless the property needs several slots.
    public func persistedValue(forKey key: String) -> Any? {
        node.stateProperties[key]
    }

    /// Stores a value that should survive until the next update of this node.
    ///
    /// - Parameters:
    ///   - value: The value to store, or `nil` to clear the slot.
    ///   - key: The storage key. Use ``label`` unless the property needs several slots.
    public func setPersistedValue(_ value: Any?, forKey key: String) {
        node.stateProperties[key] = value
    }

    /// Marks this node as needing to be re-evaluated and set up on the next update.
    ///
    /// Call this when the property's value changes outside the update pass.
    public func invalidate() {
        node.system?.markDirty(node.id)
        node.needsSetup = true
    }
}
