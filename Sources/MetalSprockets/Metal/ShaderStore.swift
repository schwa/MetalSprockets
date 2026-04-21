import Metal
import MetalSprocketsSupport
import os

/// A cache of compiled ``ShaderLibrary`` instances, shared between elements that
/// use the same bundle, source, or wrapped `MTLLibrary`.
///
/// `ShaderStore` dedupes `ShaderLibrary` backing state by ``ShaderLibrary/ID``.
/// Two `ShaderLibrary(bundle: .main)` values resolved through the same store
/// share a single compiled `MTLLibrary` and a single cache of specialized
/// `MTLFunction` objects.
///
/// ## Lifetime
///
/// A `ShaderStore` holds strong references to every library and specialized
/// function it has seen. They live as long as the store does. Create and own a
/// store for as long as you want its shaders cached — typically for a scene,
/// a feature, or the lifetime of one or more ``RenderView``s.
///
/// ## Scoping
///
/// Attach a store to a SwiftUI view or MetalSprockets element tree:
///
/// ```swift
/// @State var store = ShaderStore()
///
/// var body: some View {
///     HStack {
///         RenderView { ... }
///         RenderView { ... }
///     }
///     .shaderStore(store) // both RenderViews share one cache
/// }
/// ```
///
/// If no store is attached, ``RenderView`` creates a private one scoped to its
/// own lifetime. Shaders compiled inside that `RenderView` die with it — no
/// process-global cache, no long-lived retention.
///
/// ## Threading
///
/// `ShaderStore` is `Sendable` and safe to share across concurrent rendering.
public final class ShaderStore: Sendable {
    private let storage = OSAllocatedUnfairLock<[ShaderLibrary.ID: ShaderLibrary.State]>(initialState: [:])

    /// Creates an empty shader store.
    public init() {
        // Empty store; entries are inserted lazily on first use.
    }

    /// Adopts an already-compiled `State` into the store.
    ///
    /// If the store already has a `State` for this ID, returns the existing one
    /// and the caller should discard `candidate`. Otherwise inserts `candidate`
    /// and returns it.
    internal func adopt(_ candidate: ShaderLibrary.State) -> ShaderLibrary.State {
        storage.withLock { storage in
            if let existing = storage[candidate.id] {
                return existing
            }
            storage[candidate.id] = candidate
            return candidate
        }
    }
}
