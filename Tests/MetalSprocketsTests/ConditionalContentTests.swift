import Foundation
@testable import MetalSprockets
import Testing

@MainActor
@Suite
struct ConditionalContentTests {
    struct TrackedLeaf: Element, BodylessElement {
        let name: String

        var body: Never { fatalError() }

        func setupEnter(_ node: Node) throws {
            TestMonitor.shared.logUpdate(name)
        }
    }

    struct BranchingRoot: Element {
        let useFirst: Bool

        var body: some Element {
            if useFirst {
                TrackedLeaf(name: "first")
            }
            else {
                TrackedLeaf(name: "second")
            }
        }
    }

    @Test
    func testTrueBranchIsVisited() throws {
        TestMonitor.shared.reset()
        let system = System()
        try system.update(root: BranchingRoot(useFirst: true))
        try system.processSetup()
        #expect(TestMonitor.shared.updates == ["first"])
    }

    @Test
    func testFalseBranchIsVisited() throws {
        TestMonitor.shared.reset()
        let system = System()
        try system.update(root: BranchingRoot(useFirst: false))
        try system.processSetup()
        #expect(TestMonitor.shared.updates == ["second"])
    }

    @Test
    func testBranchSwitch() throws {
        struct Root: Element {
            @MSState var flag: Bool = true
            var body: some Element {
                if flag {
                    TrackedLeaf(name: "A")
                }
                else {
                    TrackedLeaf(name: "B")
                }
            }
        }

        TestMonitor.shared.reset()
        let root = Root()
        let system = System()
        try system.update(root: root)
        try system.processSetup()

        TestMonitor.shared.reset()
        system.withCurrentSystem { root.flag = false }
        try system.update(root: root)
        try system.processSetup()

        #expect(TestMonitor.shared.updates == ["B"])
    }

    @Test
    func testRequiresSetupIsAlwaysTrue() {
        // _ConditionalContent conservatively reports requiresSetup==true
        let a = _ConditionalContent<TrackedLeaf, TrackedLeaf>(first: TrackedLeaf(name: "x"))
        let b = _ConditionalContent<TrackedLeaf, TrackedLeaf>(first: TrackedLeaf(name: "x"))
        #expect(a.requiresSetup(comparedTo: b) == true)
    }
}
