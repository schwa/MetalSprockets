
import Metal
@testable import MetalSprockets
import Testing

private struct WorkloadTestKey: MSEnvironmentKey {
    static var defaultValue: String? { nil }
}

private extension MSEnvironmentValues {
    var workloadTestValue: String? {
        get { self[WorkloadTestKey.self] }
        set { self[WorkloadTestKey.self] = newValue }
    }
}

@MainActor
@Suite
struct CommandBufferCompletionTests {
    struct ParentElement<Content: Element>: Element, WorkloadElement, BodylessContentElement {
        var content: Content

        init(@ElementBuilder content: () throws -> Content) rethrows {
            self.content = try content()
        }

        func workloadEnter(_ node: Node) throws {
            node.environmentValues.workloadTestValue = "set-in-workload"
        }
    }

    @Test
    func testChildSeesValueSetByParentInWorkload() throws {
        var capturedValue: String?

        let root = ParentElement {
            EmptyElement()
                .onWorkloadEnter { env in
                    capturedValue = env.workloadTestValue
                }
        }

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(capturedValue == "set-in-workload")
    }

    @Test
    func testChildSeesValueSetByParentInWorkload_MultipleFrames() throws {
        var capturedValues: [String?] = []

        let root = ParentElement {
            EmptyElement()
                .onWorkloadEnter { env in
                    capturedValues.append(env.workloadTestValue)
                }
        }

        let system = System()

        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(capturedValues == ["set-in-workload", "set-in-workload", "set-in-workload"])
    }

    @Test
    func testMultipleHandlersAllFire() throws {
        var handler1Called = false
        var handler2Called = false
        var handler3Called = false

        let root = ParentElement {
            EmptyElement()
                .onWorkloadEnter { env in
                    handler1Called = env.workloadTestValue != nil
                }
                .onWorkloadEnter { env in
                    handler2Called = env.workloadTestValue != nil
                }
                .onWorkloadEnter { env in
                    handler3Called = env.workloadTestValue != nil
                }
        }

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(handler1Called)
        #expect(handler2Called)
        #expect(handler3Called)
    }

    @Test
    func testRenderPassWithCompletionHandler() throws {
        var completionCalled = false
        var capturedValue: String?

        let root = try ParentElement {
            try Group {
                EmptyElement()
                    .onWorkloadEnter { env in
                        capturedValue = env.workloadTestValue
                        completionCalled = env.workloadTestValue != nil
                    }
            }
            .onWorkloadEnter { _ in
            }
        }

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(completionCalled, "Completion handler should be called")
        #expect(capturedValue == "set-in-workload", "Should see parent's environment value")
    }

    @Test
    func testDeeplyNestedCompletion() throws {
        var innerCalled = false

        struct DeepChild: Element {
            var body: some Element {
                EmptyElement()
            }
        }

        let root = try ParentElement {
            try Group {
                try Group {
                    try Group {
                        DeepChild()
                            .onWorkloadEnter { env in
                                innerCalled = env.workloadTestValue != nil
                            }
                    }
                }
            }
        }

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(innerCalled)
    }

    @Test
    func testCommandBufferElementCompletionHandler() throws {
        var commandBufferSeen: Bool = false

        let root = CommandBufferElement(completion: .none) {
            EmptyElement()
                .onCommandBufferCompleted { _ in
                }
                .onWorkloadEnter { env in
                    commandBufferSeen = env.commandBuffer != nil
                }
        }
        .environment(\.commandQueue, MTLCreateSystemDefaultDevice()?.makeCommandQueue())

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(commandBufferSeen, "Command buffer should be in environment")
    }

    @Test
    func testRenderViewPattern_RebuildTreeEachFrame() throws {
        var capturedValues: [String?] = []

        let system = System()

        for _ in 0..<3 {
            let root = ParentElement {
                EmptyElement()
                    .onWorkloadEnter { env in
                        capturedValues.append(env.workloadTestValue)
                    }
            }

            try system.update(root: root)
            try system.processSetup()
            try system.processWorkload()
        }

        #expect(capturedValues == ["set-in-workload", "set-in-workload", "set-in-workload"])
    }

    @Test
    func testCommandBufferElement_MultipleFrames() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        var commandBufferSeenCount = 0
        let system = System()

        for _ in 0..<3 {
            let root = CommandBufferElement(completion: .none) {
                EmptyElement()
                    .onWorkloadEnter { env in
                        if env.commandBuffer != nil {
                            commandBufferSeenCount += 1
                        }
                    }
            }
            .environment(\.commandQueue, commandQueue)

            try system.update(root: root)
            try system.processSetup()
            try system.processWorkload()
        }

        #expect(commandBufferSeenCount == 3, "Command buffer should be seen in all 3 frames")
    }

    @Test
    func testIssue290_RenderPassCompletionHandler() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        var userHandlerCommandBufferSeen = false
        var renderViewHandlerCommandBufferSeen = false

        let root = try CommandBufferElement(completion: .none) {
            try Group {
                EmptyElement()  // Stand-in for RenderPass
                    .onWorkloadEnter { env in
                        userHandlerCommandBufferSeen = env.commandBuffer != nil
                    }
            }
            .onWorkloadEnter { env in
                renderViewHandlerCommandBufferSeen = env.commandBuffer != nil
            }
        }
        .environment(\.commandQueue, commandQueue)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(renderViewHandlerCommandBufferSeen, "RenderView's handler should see command buffer")
        #expect(userHandlerCommandBufferSeen, "User's handler should see command buffer")
    }

    @Test
    func testIssue290_MultipleFrames() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        var userHandlerSeenCount = 0
        var renderViewHandlerSeenCount = 0

        let system = System()

        for _ in 0..<5 {
            let root = try CommandBufferElement(completion: .none) {
                try Group {
                    EmptyElement()
                        .onWorkloadEnter { env in
                            if env.commandBuffer != nil {
                                userHandlerSeenCount += 1
                            }
                        }
                }
                .onWorkloadEnter { env in
                    if env.commandBuffer != nil {
                        renderViewHandlerSeenCount += 1
                    }
                }
            }
            .environment(\.commandQueue, commandQueue)

            try system.update(root: root)
            try system.processSetup()
            try system.processWorkload()
        }

        #expect(renderViewHandlerSeenCount == 5, "RenderView handler should fire all 5 frames")
        #expect(userHandlerSeenCount == 5, "User handler should fire all 5 frames")
    }

    @Test
    func testIssue290_WithRealRenderPass() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 100,
            height: 100,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            Issue.record("Failed to create texture")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        var userHandlerCommandBufferSeen = false

        let root = try CommandBufferElement(completion: .none) {
            try Group {
                try RenderPass {
                    EmptyElement()
                }
                .onWorkloadEnter { env in
                    userHandlerCommandBufferSeen = env.commandBuffer != nil
                }
            }
        }
        .environment(\.commandQueue, commandQueue)
        .environment(\.renderPassDescriptor, renderPassDescriptor)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(userHandlerCommandBufferSeen, "Handler on RenderPass should see command buffer")
    }

    @Test
    func testActualOnCommandBufferCompleted() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        var handlerRegistered = false

        let root = CommandBufferElement(completion: .none) {
            EmptyElement()
                .onCommandBufferCompleted { _ in
                }
                .onWorkloadEnter { env in
                    handlerRegistered = env.commandBuffer != nil
                }
        }
        .environment(\.commandQueue, commandQueue)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(handlerRegistered, "Command buffer should be available for handler registration")
    }

    @Test
    func testHandlerRegistrationVerification() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            Issue.record("Metal not available")
            return
        }

        var capturedCommandBuffer: MTLCommandBuffer?
        var handlerWasAdded = false

        let root = CommandBufferElement(completion: .none) {
            EmptyElement()
                .onWorkloadEnter { env in
                    capturedCommandBuffer = env.commandBuffer
                }
                .onCommandBufferCompleted { _ in
                    handlerWasAdded = true
                }
        }
        .environment(\.commandQueue, commandQueue)

        let system = System()
        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        #expect(capturedCommandBuffer != nil, "Should have captured command buffer")

        if let cb = capturedCommandBuffer {
            cb.commit()
            cb.waitUntilCompleted()
            #expect(handlerWasAdded, "Completion handler should have fired")
        }
    }
}
