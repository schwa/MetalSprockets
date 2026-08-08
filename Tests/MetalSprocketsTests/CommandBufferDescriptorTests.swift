import Metal
@testable import MetalSprockets
import Testing

@MainActor
@Suite("Command Buffer Descriptor Tests")
struct CommandBufferDescriptorTests {
    private final class Box: @unchecked Sendable {
        var buffer: MTLCommandBuffer?
    }

    @Test("Descriptor supplied via the environment reaches the created command buffer")
    func descriptorFromEnvironment() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        let box = Box()
        let descriptor = MTLCommandBufferDescriptor()
        descriptor.retainedReferences = false

        let root = CommandBufferElement(completion: .none) {
            EmptyElement()
                .onWorkloadEnter { env in
                    box.buffer = env.commandBuffer
                }
        }
        .commandBufferDescriptor(descriptor)
        .environment(\.commandQueue, queue)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        let buffer = try #require(box.buffer)
        #expect(buffer.retainedReferences == false)
        buffer.commit()
        buffer.waitUntilCompleted()
    }

    @Test("commandBufferDescriptorModifier mutates a copy, not the supplied descriptor")
    func descriptorModifierCopies() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        let box = Box()
        let shared = MTLCommandBufferDescriptor()

        let root = CommandBufferElement(completion: .none) {
            EmptyElement()
                .onWorkloadEnter { env in
                    box.buffer = env.commandBuffer
                }
        }
        .commandBufferDescriptorModifier { descriptor in
            descriptor.retainedReferences = false
        }
        .commandBufferDescriptor(shared)
        .environment(\.commandQueue, queue)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        let buffer = try #require(box.buffer)
        #expect(buffer.retainedReferences == false)
        #expect(shared.retainedReferences == true)
        buffer.commit()
        buffer.waitUntilCompleted()
    }

    @Test("No descriptor in the environment still creates a command buffer")
    func defaultDescriptor() throws {
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
        .environment(\.commandQueue, queue)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        let buffer = try #require(box.buffer)
        #expect(buffer.retainedReferences == true)
        buffer.commit()
        buffer.waitUntilCompleted()
    }
}
