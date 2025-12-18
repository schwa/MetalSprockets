import Combine
import Foundation
@testable import MetalSprockets
import Testing

final class TestModel: ObservableObject {
    @Published var counter: Int = 0
    @Published var text: String = "Hello"
    @Published var flag: Bool = false
}

@MainActor
@Suite(.serialized)
struct ObservableObjectTests {
    // MARK: - Basic ObservedObject Test

    struct BasicObservedElement: Element {
        @MSObservedObject var model = TestModel()

        var body: some Element {
            TestMonitor.shared.logUpdate("body-\(model.counter)")
            return DisplayElement(value: model.counter) {
                model.counter += 1
            }
        }
    }

    struct DisplayElement: Element, BodylessElement {
        let value: Int
        let action: () -> Void

        var body: Never {
            fatalError()
        }

        func workloadEnter(_ node: Node) throws {
            TestMonitor.shared.setValue(value, forKey: "counter")
        }
    }

    @Test
    func testBasicObservedObject() throws {
        TestMonitor.shared.reset()

        let root = BasicObservedElement()
        let system = System()

        try system.update(root: root)
        try system.processWorkload()

        #expect(TestMonitor.shared.updates == ["body-0"])
        #expect(TestMonitor.shared.values["counter"] as? Int == 0)

        TestMonitor.shared.clearUpdates()

        // Trigger change through Published property
        let display = system.element(at: [0, 0], type: DisplayElement.self)!
        system.withCurrentSystem {
            display.action()
        }

        try system.update(root: root)
        try system.processWorkload()

        #expect(TestMonitor.shared.updates == ["body-1"])
        #expect(TestMonitor.shared.values["counter"] as? Int == 1)
    }

    // MARK: - Multiple Published Properties Test

    struct MultiPropertyElement: Element {
        @MSObservedObject var model = TestModel()

        var body: some Element {
            TestMonitor.shared.logUpdate("body")
            return VStack {
                DisplayElement(value: model.counter) {
                    model.counter += 1
                }
                TextElement(text: model.text) {
                    model.text = "World"
                }
                FlagElement(flag: model.flag) {
                    model.flag.toggle()
                }
            }
        }
    }

    struct TextElement: Element, BodylessElement {
        let text: String
        let action: () -> Void

        var body: Never {
            fatalError()
        }

        func workloadEnter(_ node: Node) throws {
            TestMonitor.shared.setValue(text, forKey: "text")
        }
    }

    struct FlagElement: Element, BodylessElement {
        let flag: Bool
        let action: () -> Void

        var body: Never {
            fatalError()
        }

        func workloadEnter(_ node: Node) throws {
            TestMonitor.shared.setValue(flag, forKey: "flag")
        }
    }

    struct VStack<Content: Element>: Element {
        let content: Content

        init(@ElementBuilder content: () throws -> Content) rethrows {
            self.content = try content()
        }

        var body: some Element {
            content
        }
    }

    @Test
    func testMultiplePublishedProperties() throws {
        TestMonitor.shared.reset()

        let root = MultiPropertyElement()
        let system = System()

        try system.update(root: root)
        try system.processWorkload()

        #expect(TestMonitor.shared.values["counter"] as? Int == 0)
        #expect(TestMonitor.shared.values["text"] as? String == "Hello")
        #expect(TestMonitor.shared.values["flag"] as? Bool == false)

        TestMonitor.shared.clearUpdates()

        // Change text
        let textElement = system.element(at: [0, 0, 0, 1], type: TextElement.self)!
        system.withCurrentSystem {
            textElement.action()
        }

        try system.update(root: root)
        try system.processWorkload()

        #expect(TestMonitor.shared.updates == ["body"])
        #expect(TestMonitor.shared.values["text"] as? String == "World")

        // Change flag
        TestMonitor.shared.clearUpdates()
        let flagElement = system.element(at: [0, 0, 0, 2], type: FlagElement.self)!
        system.withCurrentSystem {
            flagElement.action()
        }

        try system.update(root: root)
        try system.processWorkload()

        #expect(TestMonitor.shared.values["flag"] as? Bool == true)
    }

    // MARK: - Shared ObservedObject Test

    nonisolated(unsafe) static let sharedModel = TestModel()

    struct ParentWithShared: Element {
        @MSObservedObject var model = ObservableObjectTests.sharedModel

        var body: some Element {
            TestMonitor.shared.logUpdate("parent-body")
            return VStack {
                DisplayElement(value: model.counter) {
                    model.counter += 10
                }
                ChildWithShared()
            }
        }
    }

    struct ChildWithShared: Element {
        @MSObservedObject var model = ObservableObjectTests.sharedModel

        var body: some Element {
            TestMonitor.shared.logUpdate("child-body")
            return DisplayElement(value: model.counter) {
                model.counter += 1
            }
        }
    }

    @Test
    func testSharedObservedObject() throws {
        TestMonitor.shared.reset()
        Self.sharedModel.counter = 0 // Reset

        let root = ParentWithShared()
        let system = System()

        try system.update(root: root)

        #expect(TestMonitor.shared.updates == ["parent-body", "child-body"])

        TestMonitor.shared.clearUpdates()

        // Change from child - should rebuild both
        let childDisplay = system.element(at: [0, 0, 0, 1, 0], type: DisplayElement.self)!
        system.withCurrentSystem {
            childDisplay.action()
        }

        try system.update(root: root)

        #expect(TestMonitor.shared.updates == ["parent-body", "child-body"])
        #expect(ObservableObjectTests.sharedModel.counter == 1)
    }

    // MARK: - ObservedObject with Binding Test

    struct ObservedWithBinding: Element {
        @MSObservedObject var model = TestModel()

        var body: some Element {
            BindingChild(counter: $model.counter)
        }
    }

    struct BindingChild: Element {
        @MSBinding var counter: Int

        var body: some Element {
            DisplayElement(value: counter) {
                counter += 5
            }
        }
    }

    @Test
    func testObservedObjectWithBinding() throws {
        TestMonitor.shared.reset()

        let root = ObservedWithBinding()
        let system = System()

        try system.update(root: root)
        try system.processWorkload()

        #expect(TestMonitor.shared.values["counter"] as? Int == 0)

        // Modify through binding
        let display = system.element(at: [0, 0, 0], type: DisplayElement.self)!
        system.withCurrentSystem {
            display.action()
        }

        try system.update(root: root)
        try system.processWorkload()

        #expect(root.model.counter == 5)
        #expect(TestMonitor.shared.values["counter"] as? Int == 5)
    }

    // MARK: - Selective Rebuilding with ObservedObject

    struct SelectiveParent: Element {
        @MSObservedObject var model = TestModel()

        var body: some Element {
            TestMonitor.shared.logUpdate("parent-body")
            return VStack {
                DisplayElement(value: model.counter) {
                    model.counter += 1
                }
                ConstantChild()
                DependentChild(value: model.counter)
                IndependentChild()
            }
        }
    }

    struct ConstantChild: Element {
        var body: some Element {
            TestMonitor.shared.logUpdate("constant-body")
            return EmptyElement()
        }
    }

    struct DependentChild: Element {
        let value: Int

        var body: some Element {
            TestMonitor.shared.logUpdate("dependent-body-\(value)")
            return EmptyElement()
        }
    }

    struct IndependentChild: Element {
        @MSState var ownState = 0

        var body: some Element {
            TestMonitor.shared.logUpdate("independent-body")
            return DisplayElement(value: ownState) {
                ownState += 1
            }
        }
    }

    @Test
    func testSelectiveRebuildingWithObservedObject() throws {
        TestMonitor.shared.reset()

        let root = SelectiveParent()
        let system = System()

        try system.update(root: root)

        #expect(TestMonitor.shared.updates == [
            "parent-body",
            "constant-body",
            "dependent-body-0",
            "independent-body"
        ])

        TestMonitor.shared.clearUpdates()

        // Change observed object
        if let display = system.element(at: [0, 0, 0], type: DisplayElement.self) {
            system.withCurrentSystem {
                display.action()
            }

            try system.update(root: root)

            // Parent and dependent rebuild, constant and independent should not
            #expect(TestMonitor.shared.updates == [
                "parent-body",
                "dependent-body-1"
            ])
        }

        TestMonitor.shared.clearUpdates()

        // Change independent child's state
        if let independentDisplay = system.element(at: [0, 0, 3, 0], type: DisplayElement.self) {
            system.withCurrentSystem {
                independentDisplay.action()
            }

            try system.update(root: root)

            // Only independent should rebuild
            #expect(TestMonitor.shared.updates == ["independent-body"])
        }
    }
}
