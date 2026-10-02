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

    @Test(.requiresMetal4)
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

    // MARK: - Root-published command buffer and completion callbacks
    //
    // Roots publish the command buffer while traversing the element tree.

    @Test(.requiresMetal4)
    func testRecordingPublishesCommandBuffer() throws {
        var commandBufferSeen = false
        let runner = try Runner()
        let recording = try runner.submit(
            EmptyElement()
                .onCommandBufferCompleted { _ in }
                .onWorkloadEnter { env in
                    commandBufferSeen = env.commandBuffer != nil
                }
        )
        try recording.waitUntilCompleted()
        #expect(commandBufferSeen, "Command buffer should be in environment")
    }

    @Test(.requiresMetal4)
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

    @Test(.requiresMetal4)
    func testRecording_MultipleFrames() throws {
        var commandBufferSeenCount = 0
        let runner = try Runner()
        for _ in 0..<3 {
            let recording = try runner.submit(
                EmptyElement()
                    .onWorkloadEnter { env in
                        if env.commandBuffer != nil {
                            commandBufferSeenCount += 1
                        }
                    }
            )
            try recording.waitUntilCompleted()
        }
        #expect(commandBufferSeenCount == 3, "Command buffer should be seen in all 3 frames")
    }

    @Test(.requiresMetal4)
    func testIssue290_RenderPassCompletionHandler() throws {
        var userHandlerCommandBufferSeen = false
        var renderViewHandlerCommandBufferSeen = false

        let runner = try Runner()
        let recording = try runner.submit(
            try Group {
                EmptyElement()  // Stand-in for RenderPass
                    .onWorkloadEnter { env in
                        userHandlerCommandBufferSeen = env.commandBuffer != nil
                    }
            }
            .onWorkloadEnter { env in
                renderViewHandlerCommandBufferSeen = env.commandBuffer != nil
            }
        )
        try recording.waitUntilCompleted()

        #expect(renderViewHandlerCommandBufferSeen, "RenderView's handler should see command buffer")
        #expect(userHandlerCommandBufferSeen, "User's handler should see command buffer")
    }

    @Test(.requiresMetal4)
    func testIssue290_MultipleFrames() throws {
        var userHandlerSeenCount = 0
        var renderViewHandlerSeenCount = 0

        let runner = try Runner()
        for _ in 0..<5 {
            let recording = try runner.submit(
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
            )
            try recording.waitUntilCompleted()
        }

        #expect(renderViewHandlerSeenCount == 5, "RenderView handler should fire all 5 frames")
        #expect(userHandlerSeenCount == 5, "User handler should fire all 5 frames")
    }

    @Test(.requiresMetal4)
    func testIssue290_WithRealRenderPass() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 100, height: 100, mipmapped: false)
        textureDescriptor.usage = [.renderTarget]
        let texture = try #require(device.makeTexture(descriptor: textureDescriptor))

        let renderPassDescriptor = MTL4RenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        var userHandlerCommandBufferSeen = false

        let runner = try Runner(device: device)
        try runner.run(
            try Group {
                try RenderPass {
                    EmptyElement()
                }
                .onWorkloadEnter { env in
                    userHandlerCommandBufferSeen = env.commandBuffer != nil
                }
            }
            .renderPassDescriptor(renderPassDescriptor)
        )

        #expect(userHandlerCommandBufferSeen, "Handler on RenderPass should see command buffer")
    }

    @Test(.requiresMetal4)
    func testOnCommandBufferCompletedReceivesTheResult() throws {
        final class Box: @unchecked Sendable {
            var result: SubmissionResult?
        }
        let box = Box()
        let runner = try Runner()
        let recording = try runner.submit(
            EmptyElement()
                .onCommandBufferCompleted { result in
                    box.result = result
                }
        )
        let submission = recording
        let result = try submission.waitUntilCompleted()
        #expect(result.outcome == .completed)
        #expect(box.result?.submissionIdentifier == submission.identifier)
        #expect(box.result?.outcome == .completed)
    }

    // #463: the isolation-aware overload runs on the caller's isolation (here @MainActor), so it can write isolated
    // state such as @MSState directly without an actor hop.
    @Test(.requiresMetal4)
    func testIsolatedCompletionRunsOnMainActorAndWritesState() async throws {
        var outcome: SubmissionResult.Outcome?
        let runner = try Runner()
        let recording = try runner.submit(
            // swiftlint:disable:next trailing_closure
            EmptyElement().onCommandBufferCompleted(perform: { result in
                MainActor.assertIsolated()
                outcome = result.outcome
            })
        )
        let submission = recording
        _ = try await submission.waitUntilCompleted()
        // The callback hops to the MainActor via a Task, so wait for it to land.
        while outcome == nil {
            await Task.yield()
        }
        #expect(outcome == .completed)
    }

    @Test(.requiresMetal4)
    func testFailedEncodingReportsNoCompletion() throws {
        enum Failure: Error { case expected }
        let runner = try Runner()
        #expect(throws: Failure.expected) {
            try runner.submit(
                EmptyElement()
                    .onCommandBufferCompleted { _ in Issue.record("Failed encoding must not report GPU completion") }
                    .onWorkloadEnter { _ in throw Failure.expected }
            )
        }
        #expect(runner.context.inFlightCount == 0)
    }
}
