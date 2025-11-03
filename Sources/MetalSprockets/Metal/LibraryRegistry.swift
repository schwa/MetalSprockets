import Metal
import MetalSprocketsSupport
internal import os

internal final class LibraryRegistry: Sendable {
    static let shared = LibraryRegistry()

    private let registry = OSAllocatedUnfairLock<[ShaderLibrary.ID: ShaderLibrary.State]>(initialState: [:])

    private init() {
        // Private initializer for singleton pattern
    }

    func getOrCreate(id: ShaderLibrary.ID, create: @Sendable () throws -> MTLLibrary) rethrows -> ShaderLibrary.State {
        try registry.withLock { registry in
            // Check if we have a cached state
            if let state = registry[id] {
                return state
            }

            // Create new state
            let library = try create()
            let state = ShaderLibrary.State(library: library, id: id)

            // Store strong reference
            registry[id] = state

            return state
        }
    }
}
