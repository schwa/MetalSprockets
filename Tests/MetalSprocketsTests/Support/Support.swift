import Accelerate
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

import os

final class TestMonitor: @unchecked Sendable {
    static let shared = TestMonitor()

    private struct State: @unchecked Sendable {
        var updates: [String] = []
        var values: [String: Any] = [:]
        var observations: [(phase: String, element: String, counter: Int, env: String)] = []
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())

    var updates: [String] {
        lock.withLockUnchecked { $0.updates }
    }

    var values: [String: Any] {
        lock.withLockUnchecked { $0.values }
    }

    var observations: [(phase: String, element: String, counter: Int, env: String)] {
        lock.withLockUnchecked { $0.observations }
    }

    func reset() {
        lock.withLockUnchecked {
            $0.updates.removeAll()
            $0.values.removeAll()
            $0.observations.removeAll()
        }
    }

    func logUpdate(_ message: String) {
        lock.withLockUnchecked {
            $0.updates.append(message)
        }
    }

    func record(phase: String, element: String, counter: Int = -1, env: String = "") {
        lock.withLockUnchecked {
            $0.observations.append((phase: phase, element: element, counter: counter, env: env))
        }
    }

    func setValue(_ value: Any, forKey key: String) {
        lock.withLockUnchecked {
            $0.values[key] = value
        }
    }

    func clearUpdates() {
        lock.withLockUnchecked {
            $0.updates.removeAll()
        }
    }
}

// Test helper extension
extension StructuralIdentifier.Atom {
    var index: Int? {
        if case .index(let value) = component {
            return value
        }
        return nil
    }

    var explicit: AnyHashable? {
        if case .explicit(let value) = component {
            return value
        }
        return nil
    }
}

// Test helper methods for accessing elements by indices
extension System {
    // Computed property to extract ordered identifiers from traversal events
    var orderedIdentifiers: [StructuralIdentifier] {
        var identifiers: [StructuralIdentifier] = []
        for event in traversalEvents {
            if case .enter(let node) = event {
                identifiers.append(node.id)
            }
        }
        return identifiers
    }

    func identifier(at indices: [Int]) -> StructuralIdentifier? {
        guard !indices.isEmpty else { return nil }

        // Simple approach: group identifiers by depth, then filter by parent
        var identifiersByDepth: [[StructuralIdentifier]] = []

        // First pass: group all identifiers by their depth
        for id in orderedIdentifiers {
            let depth = id.atoms.count - 1
            while identifiersByDepth.count <= depth {
                identifiersByDepth.append([])
            }
            identifiersByDepth[depth].append(id)
        }

        // Now walk the indices to find the target
        var targetPath: [StructuralIdentifier.Atom] = []

        for (depth, index) in indices.enumerated() {
            guard depth < identifiersByDepth.count else { return nil }

            // Filter identifiers at this depth to only those that match our path so far
            let candidates = identifiersByDepth[depth].filter { id in
                // Check if this identifier matches our path so far
                guard id.atoms.count == depth + 1 else { return false }
                return targetPath.enumerated().allSatisfy { $0.element == id.atoms[$0.offset] }
            }

            guard index < candidates.count else { return nil }

            // Add this atom to our path
            targetPath.append(candidates[index].atoms[depth])
        }

        return StructuralIdentifier(atoms: targetPath)
    }

    func element(at indices: [Int]) -> (any Element)? {
        guard let targetIdentifier = identifier(at: indices) else {
            return nil
        }
        return nodes[targetIdentifier]?.element
    }

    func element<E>(at indices: [Int], type: E.Type) -> E? where E: Element {
        element(at: indices) as? E
    }
}
