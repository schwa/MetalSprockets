@testable import MetalSprockets
import Testing

@Suite("MSEnvironmentValues Debug Descriptions")
struct EnvironmentValuesDebugTests {
    private struct MyKey: MSEnvironmentKey {
        static var defaultValue: Int { 0 }
    }

    @Test("Empty storage has a debug description")
    func emptyStorageDebugDescription() {
        let env = MSEnvironmentValues()
        // `debugDescription` on MSEnvironmentValues forwards to its storage,
        // which includes the (possibly empty) sorted key list and parent flag.
        let description = String(reflecting: env)
        #expect(description.contains("storage:"))
        #expect(description.contains("parent: false"))
    }

    @Test("Populated storage lists keys in debug description")
    func populatedStorageDebugDescription() {
        var env = MSEnvironmentValues()
        env[MyKey.self] = 42
        let description = String(reflecting: env)
        #expect(description.contains("storage:"))
        // The storage description also contains "parent: false" when there's no chained parent.
        #expect(description.contains("parent: false"))
    }

    @Test("Key.debugDescription stringifies the underlying type")
    func keyDebugDescription() {
        let key = MSEnvironmentValues.Key(MyKey.self)
        let description = String(reflecting: key)
        #expect(description.contains("MyKey"))
    }
}
