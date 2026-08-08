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

extension System {
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

        var identifiersByDepth: [[StructuralIdentifier]] = []

        for id in orderedIdentifiers {
            let depth = id.atoms.count - 1
            while identifiersByDepth.count <= depth {
                identifiersByDepth.append([])
            }
            identifiersByDepth[depth].append(id)
        }

        var targetPath: [StructuralIdentifier.Atom] = []

        for (depth, index) in indices.enumerated() {
            guard depth < identifiersByDepth.count else { return nil }

            let candidates = identifiersByDepth[depth].filter { id in
                guard id.atoms.count == depth + 1 else { return false }
                return targetPath.enumerated().allSatisfy { $0.element == id.atoms[$0.offset] }
            }

            guard index < candidates.count else { return nil }

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
