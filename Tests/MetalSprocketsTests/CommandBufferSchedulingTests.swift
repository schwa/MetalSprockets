import Metal
@testable import MetalSprockets
import Testing

@MainActor
@Suite("Command Buffer Scheduling Tests")
struct CommandBufferSchedulingTests {
    @Test("onCommandBufferScheduled fires after the command buffer is scheduled")
    func scheduledHandlerFires() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        final class Box: @unchecked Sendable {
            var capturedBuffer: MTLCommandBuffer?
            var scheduledFired = false
        }
        let box = Box()

        let root = CommandBufferElement(completion: .none) {
            EmptyElement()
                .onWorkloadEnter { env in
                    box.capturedBuffer = env.commandBuffer
                }
                .onCommandBufferScheduled { _ in
                    box.scheduledFired = true
                }
        }
        .environment(\.commandQueue, queue)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        let buffer = try #require(box.capturedBuffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        #expect(box.scheduledFired)
    }

    @Test("CommandBufferElement with .commit completion commits the buffer")
    func commitCompletionMode() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        final class Box: @unchecked Sendable {
            var buffer: MTLCommandBuffer?
        }
        let box = Box()

        let root = CommandBufferElement(completion: .commit) {
            EmptyElement()
                .onWorkloadEnter { env in
                    box.buffer = env.commandBuffer
                }
        }
        .environment(\.commandQueue, queue)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        let buffer = try #require(box.buffer)
        // After .commit completion, the buffer should no longer be in .notEnqueued state.
        buffer.waitUntilCompleted()
        #expect(buffer.status == .completed)
    }

    @Test("onCommandBufferScheduled outside a CommandBufferElement logs a warning and no-ops")
    func scheduledHandlerWithoutCommandBuffer() throws {
        // No CommandBufferElement in the tree -> no commandBuffer in environment -> warning branch.
        let root = EmptyElement()
            .onCommandBufferScheduled { _ in
                Issue.record("Handler should not be called without a command buffer")
            }

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()
    }

    @Test("onCommandBufferCompleted outside a CommandBufferElement logs a warning and no-ops")
    func completedHandlerWithoutCommandBuffer() throws {
        let root = EmptyElement()
            .onCommandBufferCompleted { _ in
                Issue.record("Handler should not be called without a command buffer")
            }

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()
    }
}
