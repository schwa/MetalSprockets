import Foundation
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

// Shader logging itself (a message from a shader reaching the log handler) is covered by ShaderLoggingTests.
// On Metal 4 a log state covers a whole command buffer, so the per-subtree `metalLoggingEnabled(_:)` modifier is
// unavailable; only the process-wide default remains readable from the environment.
@MainActor
@Suite("Metal Logging Environment Tests")
struct MetalLoggingEnvironmentTests {
    private final class Box: @unchecked Sendable {
        var enabled: Bool?
    }

    @Test("metalLoggingEnabled defaults to the system environment value")
    func defaultsToSystemEnvironment() throws {
        let box = Box()
        let root = EmptyElement()
            .onWorkloadEnter { env in
                box.enabled = env.metalLoggingEnabled
            }

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(box.enabled == SystemEnvironment.current.metalLoggingEnabled)
    }
}
