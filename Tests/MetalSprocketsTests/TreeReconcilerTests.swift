import Foundation
@testable import MetalSprockets
import Testing

@MainActor
@Suite(.serialized)
struct TreeReconcilerTests {
    struct Leaf: Element {
        var value: Int = 0

        var body: some Element {
            EmptyElement()
        }
    }

    struct Root: Element {
        var value: Int = 0

        var body: some Element {
            Leaf(value: value)
            Leaf()
        }
    }

    /// The reconciler can be driven directly, with no setup or workload phase in sight.
    @Test
    func reconcilerProducesNodesAndBalancedEvents() throws {
        let system = System()
        let reconciliation = try System.$current.withValue(system) {
            try TreeReconciler(system: system).reconcile(root: Root())
        }

        #expect(reconciliation.nodes.count == reconciliation.events.count / 2)
        var depth = 0
        for event in reconciliation.events {
            switch event {
            case .enter:
                depth += 1
            case .exit:
                depth -= 1
            }
            #expect(depth >= 0)
        }
        #expect(depth == 0)
    }

    /// A second pass over an equal tree reuses the same node objects.
    @Test
    func reconcilingEqualTreeReusesNodes() throws {
        let system = System()
        try system.update(root: Root())
        let before = system.nodes

        let reconciliation = try System.$current.withValue(system) {
            try TreeReconciler(system: system).reconcile(root: Root())
        }

        #expect(Set(reconciliation.nodes.keys) == Set(before.keys))
        for (id, node) in reconciliation.nodes {
            #expect(node === before[id])
        }
    }

    /// System.update installs whatever the reconciler produced.
    @Test
    func systemUpdateInstallsReconciliation() throws {
        let system = System()
        try system.update(root: Root(value: 1))
        let identifiers = Set(system.nodes.keys)

        try system.update(root: Root(value: 2))

        #expect(Set(system.nodes.keys) == identifiers)
        #expect(system.traversalEvents.count == identifiers.count * 2)
    }
}
