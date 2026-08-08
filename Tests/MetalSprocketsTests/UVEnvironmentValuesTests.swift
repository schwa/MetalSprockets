@testable import MetalSprockets
import Testing

struct TestEnvironmentKey: MSEnvironmentKey {
    static let defaultValue = "default"
}

extension MSEnvironmentValues {
    // periphery:ignore
    var testValue: String {
        get { self[TestEnvironmentKey.self] }
        set { self[TestEnvironmentKey.self] = newValue }
    }
}

@Suite struct MSEnvironmentValuesInheritanceTests {
    @Test func `unset values fall back to the key default`() {
        let environment = MSEnvironmentValues()
        #expect(environment[TestEnvironmentKey.self] == "default")
    }

    @Test func `inherited values are visible to children`() {
        var parent = MSEnvironmentValues()
        parent[TestEnvironmentKey.self] = "from parent"

        var child = MSEnvironmentValues()
        child.inherit(from: parent)

        #expect(child[TestEnvironmentKey.self] == "from parent")
        #expect(child.values.isEmpty)
    }

    @Test func `own values shadow inherited values`() {
        var parent = MSEnvironmentValues()
        parent[TestEnvironmentKey.self] = "from parent"

        var child = MSEnvironmentValues()
        child[TestEnvironmentKey.self] = "from child"
        child.inherit(from: parent)

        #expect(child[TestEnvironmentKey.self] == "from child")
    }

    @Test func `inheriting is idempotent`() {
        var parent = MSEnvironmentValues()
        parent[TestEnvironmentKey.self] = "from parent"

        var child = MSEnvironmentValues()
        child.inherit(from: parent)
        child.inherit(from: parent)

        #expect(child[TestEnvironmentKey.self] == "from parent")
    }

    @Test func `re-inheriting picks up later writes to the parent`() {
        var parent = MSEnvironmentValues()
        parent[TestEnvironmentKey.self] = "first"

        var child = MSEnvironmentValues()
        child.inherit(from: parent)
        #expect(child[TestEnvironmentKey.self] == "first")

        parent[TestEnvironmentKey.self] = "second"
        child.inherit(from: parent)
        #expect(child[TestEnvironmentKey.self] == "second")
    }

    @Test func `values flow down a deep chain`() {
        var environments = [MSEnvironmentValues]()
        for index in 0..<10 {
            var environment = MSEnvironmentValues()
            if index > 0 {
                environment.inherit(from: environments[index - 1])
            }
            if index == 0 {
                environment[TestEnvironmentKey.self] = "from the root"
            }
            environments.append(environment)
        }

        #expect(environments.last?[TestEnvironmentKey.self] == "from the root")
    }

    @Test func `the nearest write in the chain wins`() {
        var grandparent = MSEnvironmentValues()
        grandparent[TestEnvironmentKey.self] = "grandparent"

        var parent = MSEnvironmentValues()
        parent.inherit(from: grandparent)
        parent[TestEnvironmentKey.self] = "parent"

        var child = MSEnvironmentValues()
        child.inherit(from: parent)

        #expect(child[TestEnvironmentKey.self] == "parent")
    }

    @Test func `removing inherited values keeps values written directly`() {
        var parent = MSEnvironmentValues()
        parent[TestEnvironmentKey.self] = "from parent"

        var child = MSEnvironmentValues()
        child.inherit(from: parent)
        child[OtherTestEnvironmentKey.self] = 42

        child.removeInheritedValues()

        #expect(child[TestEnvironmentKey.self] == "default")
        #expect(child[OtherTestEnvironmentKey.self] == 42)
    }

    @Test func `copies do not share writes with their source`() {
        var parent = MSEnvironmentValues()
        parent[TestEnvironmentKey.self] = "from parent"

        var copy = parent
        copy[TestEnvironmentKey.self] = "from copy"

        #expect(parent[TestEnvironmentKey.self] == "from parent")
        #expect(copy[TestEnvironmentKey.self] == "from copy")
    }
}

private struct OtherTestEnvironmentKey: MSEnvironmentKey {
    static let defaultValue = 0
}
