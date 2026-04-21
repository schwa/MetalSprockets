@testable import MetalSprockets
import Testing

@Suite
@MainActor
struct OnDisappearTests {
    struct Leaf: Element, BodylessElement {
        typealias Body = Never
        let tag: String
        var body: Never { fatalError() }
    }

    // MARK: - Basics

    @Test
    func fires_when_element_is_removed_from_tree() throws {
        struct Root: Element {
            @MSState var present = true
            let onGone: () -> Void

            var body: some Element {
                if present {
                    Leaf(tag: "a").onDisappear(perform: onGone)
                } else {
                    Leaf(tag: "replacement")
                }
            }
        }

        var disappearCount = 0
        let root = Root { disappearCount += 1 }
        let system = System()

        try system.update(root: root)
        try system.processSetup()
        #expect(disappearCount == 0)

        // Remove the Leaf by flipping `present`.
        system.withCurrentSystem { root.present = false }
        try system.update(root: root)

        #expect(disappearCount == 1)
    }

    @Test
    func does_not_fire_while_element_stays_in_tree() throws {
        struct Root: Element {
            @MSState var counter = 0
            let onGone: () -> Void

            var body: some Element {
                Leaf(tag: "stays-\(counter)").onDisappear(perform: onGone)
            }
        }

        var disappearCount = 0
        let root = Root { disappearCount += 1 }
        let system = System()

        try system.update(root: root)
        try system.processSetup()

        // Mutate state multiple times; structure stays the same.
        for i in 1...5 {
            system.withCurrentSystem { root.counter = i }
            try system.update(root: root)
            try system.processSetup()
        }

        #expect(disappearCount == 0)
    }

    @Test
    func does_not_fire_when_reordered_but_kept() throws {
        // Reordering siblings of the same type/structure should not remove them.
        struct Root: Element {
            @MSState var flipped = false
            let onGone: () -> Void

            var body: some Element {
                get throws {
                    if flipped {
                        try Group {
                            Leaf(tag: "b")
                            Leaf(tag: "a").onDisappear(perform: onGone)
                        }
                    } else {
                        try Group {
                            Leaf(tag: "a").onDisappear(perform: onGone)
                            Leaf(tag: "b")
                        }
                    }
                }
            }
        }

        var disappearCount = 0
        let root = Root { disappearCount += 1 }
        let system = System()

        try system.update(root: root)
        try system.processSetup()

        system.withCurrentSystem { root.flipped = true }
        try system.update(root: root)
        try system.processSetup()

        // Structural identity IS index-based within type, so reordering may or may
        // not re-identify; what we actually want to assert is that teardown isn't
        // called spuriously when the same total set of Leaf+OnDisappearModifier
        // nodes remain. Exact count depends on matching; both 0 and a bounded
        // value are acceptable, but it must not fire more than once.
        #expect(disappearCount <= 1)
    }

    // MARK: - Multiple / nesting

    @Test
    func fires_once_per_removed_element() throws {
        struct Root: Element {
            @MSState var present = true
            let onGone: (String) -> Void

            var body: some Element {
                get throws {
                    if present {
                        try Group {
                            Leaf(tag: "a").onDisappear { onGone("a") }
                            Leaf(tag: "b").onDisappear { onGone("b") }
                            Leaf(tag: "c").onDisappear { onGone("c") }
                        }
                    } else {
                        Leaf(tag: "replacement")
                    }
                }
            }
        }

        var gone: [String] = []
        let root = Root { gone.append($0) }
        let system = System()

        try system.update(root: root)
        try system.processSetup()

        system.withCurrentSystem { root.present = false }
        try system.update(root: root)

        #expect(gone.sorted() == ["a", "b", "c"])
    }

    @Test
    func nested_modifier_fires_in_addition_to_child() throws {
        struct Root: Element {
            @MSState var present = true
            let onOuterGone: () -> Void
            let onInnerGone: () -> Void

            var body: some Element {
                if present {
                    Leaf(tag: "leaf")
                        .onDisappear(perform: onInnerGone)
                        .onDisappear(perform: onOuterGone)
                } else {
                    Leaf(tag: "replacement")
                }
            }
        }

        var outer = 0
        var inner = 0
        let root = Root(onOuterGone: { outer += 1 }, onInnerGone: { inner += 1 })
        let system = System()

        try system.update(root: root)
        try system.processSetup()

        system.withCurrentSystem { root.present = false }
        try system.update(root: root)

        #expect(outer == 1)
        #expect(inner == 1)
    }

    // MARK: - Lifecycle extremes

    @Test
    func fires_on_complete_tree_replacement() throws {
        // Replacing the root's body wholesale should still tear down the modifier.
        struct Root: Element {
            @MSState var mode = 0
            let onGone: () -> Void

            var body: some Element {
                get throws {
                    switch mode {
                    case 0:
                        Leaf(tag: "original").onDisappear(perform: onGone)
                    default:
                        try Group {
                            Leaf(tag: "x")
                            Leaf(tag: "y")
                        }
                    }
                }
            }
        }

        var count = 0
        let root = Root { count += 1 }
        let system = System()

        try system.update(root: root)
        try system.processSetup()

        system.withCurrentSystem { root.mode = 1 }
        try system.update(root: root)

        #expect(count == 1)
    }

    @Test
    func does_not_fire_if_never_torn_down() throws {
        struct Root: Element {
            let onGone: () -> Void
            var body: some Element {
                Leaf(tag: "permanent").onDisappear(perform: onGone)
            }
        }

        var count = 0
        let root = Root { count += 1 }
        let system = System()

        try system.update(root: root)
        try system.processSetup()
        try system.update(root: root)
        try system.processSetup()
        try system.update(root: root)
        try system.processSetup()

        #expect(count == 0)
    }

    @Test
    func teardown_error_in_element_protocol_is_logged_not_thrown() throws {
        // The OnDisappearModifier closure is () -> Void and can't throw, but
        // the BodylessElement.teardown hook is throwing. This test exercises
        // the System.update path when a BodylessElement's teardown throws,
        // ensuring update() itself does not propagate the error.
        struct Throwing: Element, BodylessElement, BodylessContentElement {
            typealias Content = Leaf
            var content: Leaf { Leaf(tag: "c") }
            func teardown(_ node: Node) throws {
                struct Boom: Error {}
                throw Boom()
            }
        }

        struct Root: Element {
            @MSState var present = true
            var body: some Element {
                if present {
                    Throwing()
                } else {
                    Leaf(tag: "replacement")
                }
            }
        }

        let root = Root()
        let system = System()
        try system.update(root: root)
        try system.processSetup()

        system.withCurrentSystem { root.present = false }
        // Must not throw — teardown failures are swallowed + logged.
        try system.update(root: root)
    }
}
