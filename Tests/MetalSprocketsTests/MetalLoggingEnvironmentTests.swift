import Foundation
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("Metal Logging Environment Tests")
struct MetalLoggingEnvironmentTests {
    private final class Box: @unchecked Sendable {
        var enabled: Bool?
        var buffer: MTLCommandBuffer?
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

    @Test("metalLoggingEnabled modifier sets the value for a subtree")
    func modifierSetsSubtreeValue() throws {
        let box = Box()
        let root = EmptyElement()
            .onWorkloadEnter { env in
                box.enabled = env.metalLoggingEnabled
            }
            .metalLoggingEnabled(true)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(box.enabled == true)
    }

    // The log state itself isn't readable back off MTLCommandBuffer, so this only checks that the
    // environment-driven logging path builds a usable command buffer.
    @Test(
        "CommandBufferElement honours metalLoggingEnabled from the environment",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Metal log state unavailable on CI runners")
    )
    func commandBufferUsesEnvironmentValue() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        let box = Box()
        let root = CommandBufferElement(completion: .none) {
            EmptyElement()
                .onWorkloadEnter { env in
                    box.buffer = env.commandBuffer
                }
        }
        .metalLoggingEnabled(true)
        .environment(\.commandQueue, queue)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        let buffer = try #require(box.buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
    }
}
