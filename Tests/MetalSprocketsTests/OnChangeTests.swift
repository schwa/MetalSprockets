@testable import MetalSprockets
import Testing

@Suite
@MainActor
struct OnChangeTests {
    struct TestElement: Element, BodylessElement {
        typealias Body = Never

        let value: String

        var body: Never {
            fatalError()
        }
    }

    @Test
    func testBasicOnChange() throws {
        var changeCount = 0
        var lastOldValue: Int?
        var lastNewValue: Int?

        struct ContentElement: Element {
            @MSState var counter = 0
            let onCounterChange: (Int, Int) -> Void

            var body: some Element {
                TestElement(value: "Test-\(counter)")
                    .onChange(of: counter) { old, new in
                        onCounterChange(old, new)
                    }
            }
        }

        let element = ContentElement { old, new in
            changeCount += 1
            lastOldValue = old
            lastNewValue = new
        }

        let system = System()
        try system.update(root: element)
        try system.processSetup()

        #expect(changeCount == 0)
        #expect(lastOldValue == nil)
        #expect(lastNewValue == nil)

        system.withCurrentSystem {
            element.counter = 1
        }
        try system.update(root: element)
        try system.processSetup()

        #expect(changeCount == 1)
        #expect(lastOldValue == 0)
        #expect(lastNewValue == 1)

        system.withCurrentSystem {
            element.counter = 5
        }
        try system.update(root: element)
        try system.processSetup()

        #expect(changeCount == 2)
        #expect(lastOldValue == 1)
        #expect(lastNewValue == 5)
    }

    @Test
    func testOnChangeWithInitial() throws {
        var changeCount = 0
        var lastOldValue: Int?
        var lastNewValue: Int?

        struct ContentElement: Element {
            let initialValue: Int
            let onChange: (Int, Int) -> Void

            var body: some Element {
                TestElement(value: "Test-\(initialValue)")
                    .onChange(of: initialValue, initial: true) { old, new in
                        onChange(old, new)
                    }
            }
        }

        let element = ContentElement(initialValue: 42) { old, new in
            changeCount += 1
            lastOldValue = old
            lastNewValue = new
        }

        let system = System()
        try system.update(root: element)
        try system.processSetup()

        #expect(changeCount == 1)
        #expect(lastOldValue == 42)
        #expect(lastNewValue == 42)

        let element2 = ContentElement(initialValue: 100) { old, new in
            changeCount += 1
            lastOldValue = old
            lastNewValue = new
        }

        try system.update(root: element2)
        try system.processSetup()

        #expect(changeCount == 2)
        #expect(lastOldValue == 42)
        #expect(lastNewValue == 100)
    }

    @Test
    func testOnChangeNoChangeWhenValueSame() throws {
        var changeCount = 0

        struct ContentElement: Element {
            @MSState var value: String = "Hello"
            let onChange: () -> Void

            var body: some Element {
                TestElement(value: "Test")
                    .onChange(of: value) { _, _ in
                        onChange()
                    }
            }
        }

        let element = ContentElement {
            changeCount += 1
        }

        let system = System()
        try system.update(root: element)
        try system.processSetup()

        #expect(changeCount == 0)

        system.withCurrentSystem {
            element.value = "Hello"
        }
        try system.update(root: element)
        try system.processSetup()

        #expect(changeCount == 0)

        system.withCurrentSystem {
            element.value = "World"
        }
        try system.update(root: element)
        try system.processSetup()

        #expect(changeCount == 1)
    }

    @Test
    func testOnChangeSimpleAction() throws {
        var actionCalled = false

        struct ContentElement: Element {
            @MSState var toggle = false
            let onToggle: () -> Void

            var body: some Element {
                TestElement(value: "Test-\(toggle)")
                    .onChange(of: toggle) {
                        onToggle()
                    }
            }
        }

        let element = ContentElement {
            actionCalled = true
        }

        let system = System()
        try system.update(root: element)
        try system.processSetup()

        #expect(actionCalled == false)

        system.withCurrentSystem {
            element.toggle = true
        }
        try system.update(root: element)
        try system.processSetup()

        #expect(actionCalled == true)
    }

    @Test
    func testMultipleOnChangeModifiers() throws {
        var value1ChangeCount = 0
        var value2ChangeCount = 0

        struct ContentElement: Element {
            @MSState var value1 = 0
            @MSState var value2 = "A"
            let onValue1Change: () -> Void
            let onValue2Change: () -> Void

            var body: some Element {
                TestElement(value: "Test-\(value1)-\(value2)")
                    .onChange(of: value1) {
                        onValue1Change()
                    }
                    .onChange(of: value2) {
                        onValue2Change()
                    }
            }
        }

        let element = ContentElement(
            onValue1Change: { value1ChangeCount += 1 },
            onValue2Change: { value2ChangeCount += 1 }
        )

        let system = System()
        try system.update(root: element)
        try system.processSetup()

        #expect(value1ChangeCount == 0)
        #expect(value2ChangeCount == 0)

        system.withCurrentSystem {
            element.value1 = 10
        }
        try system.update(root: element)
        try system.processSetup()

        #expect(value1ChangeCount == 1)
        #expect(value2ChangeCount == 0)

        system.withCurrentSystem {
            element.value2 = "B"
        }
        try system.update(root: element)
        try system.processSetup()

        #expect(value1ChangeCount == 1)
        #expect(value2ChangeCount == 1)

        system.withCurrentSystem {
            element.value1 = 20
            element.value2 = "C"
        }
        try system.update(root: element)
        try system.processSetup()

        #expect(value1ChangeCount == 2)
        #expect(value2ChangeCount == 2)
    }

    @Test
    func testOnChangeWithBinding() throws {
        var changeCount = 0
        var lastValue: Int?

        struct ChildElement: Element {
            @MSBinding var boundValue: Int
            let onChange: (Int) -> Void

            var body: some Element {
                TestElement(value: "Child-\(boundValue)")
                    .onChange(of: boundValue) { _, new in
                        onChange(new)
                    }
            }
        }

        struct ParentElement: Element {
            @MSState var value = 5
            let onChange: (Int) -> Void

            var body: some Element {
                ChildElement(boundValue: $value, onChange: onChange)
            }
        }

        let element = ParentElement { newValue in
            changeCount += 1
            lastValue = newValue
        }

        let system = System()
        try system.update(root: element)
        try system.processSetup()

        #expect(changeCount == 0)

        system.withCurrentSystem {
            element.value = 10
        }
        try system.update(root: element)
        try system.processSetup()

        #expect(changeCount == 1)
        #expect(lastValue == 10)

        system.withCurrentSystem {
            element.value = 15
        }
        try system.update(root: element)
        try system.processSetup()

        #expect(changeCount == 2)
        #expect(lastValue == 15)
    }

    @Test
    func testOnChangeOnlyCalledWhenValueChanges() throws {
        var callCount = 0

        struct TrackedElement: Element {
            @MSState var value = 0
            let onValueChange: () -> Void

            var body: some Element {
                TestElement(value: "\(value)")
                    .onChange(of: value) { _, _ in
                        onValueChange()
                    }
            }
        }

        let element = TrackedElement {
            callCount += 1
        }

        let system = System()
        try system.update(root: element)
        try system.processSetup()

        #expect(callCount == 0)

        system.withCurrentSystem {
            element.value = 1
        }
        try system.update(root: element)
        try system.processSetup()
        #expect(callCount == 1)

        system.withCurrentSystem {
            element.value = 1
        }
        try system.update(root: element)
        try system.processSetup()
        #expect(callCount == 1) // Should still be 1

        system.withCurrentSystem {
            element.value = 2
        }
        try system.update(root: element)
        try system.processSetup()
        #expect(callCount == 2)
    }
}
