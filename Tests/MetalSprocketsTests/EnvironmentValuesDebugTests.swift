@testable import MetalSprockets
import Testing

@Suite("MSEnvironmentValues Debug Descriptions")
struct EnvironmentValuesDebugTests {
    private struct MyKey: MSEnvironmentKey {
        static var defaultValue: Int { 0 }
    }

    @Test("Empty environment has a debug description")
    func emptyEnvironmentDebugDescription() {
        let env = MSEnvironmentValues()
        let description = String(reflecting: env)
        #expect(description.contains("values: []"))
        #expect(description.contains("inherited: []"))
    }

    @Test("Populated environment lists keys in debug description")
    func populatedEnvironmentDebugDescription() {
        var parent = MSEnvironmentValues()
        parent[MyKey.self] = 1

        var env = MSEnvironmentValues()
        env[MyKey.self] = 42
        env.inherit(from: parent)

        let description = String(reflecting: env)
        #expect(description.contains("values: [MyKey]"))
        #expect(description.contains("inherited: [MyKey]"))
    }

    @Test("Key.debugDescription stringifies the underlying type")
    func keyDebugDescription() {
        let key = MSEnvironmentValues.Key(MyKey.self)
        let description = String(reflecting: key)
        #expect(description.contains("MyKey"))
    }
}
