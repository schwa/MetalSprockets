import Metal
import MetalSprocketsSupport

// MARK: - CommandBufferElement

/// Creates and manages a Metal command buffer for child elements.
///
/// `CommandBufferElement` creates a command buffer that render passes,
/// compute passes, and blit passes use to encode GPU work.
///
/// ## Overview
///
/// > Important: Most users will not need to use this element directly.
/// `RenderView` and similar containers automatically create command buffers.
///
/// Use `CommandBufferElement` only for advanced scenarios like offscreen
/// rendering or when you need explicit control over command buffer lifecycle.
///
/// ```swift
/// CommandBufferElement(completion: .commitAndWaitUntilCompleted) {
///     RenderPass {
///         // Render content
///     }
/// }
/// ```
///
/// ## Completion Modes
///
/// - `.none`: Don't commit (caller manages lifecycle)
/// - `.commit`: Commit after encoding completes
/// - `.commitAndWaitUntilCompleted`: Commit and block until GPU finishes
///
/// ## Topics
///
/// ### Related Elements
/// - ``RenderPass``
/// - ``ComputePass``
/// - ``BlitPass``
public struct CommandBufferElement <Content>: Element, BodylessContentElement where Content: Element {
    var completion: MTLCommandQueueCompletion
    var content: Content

    /// Creates a command buffer element.
    ///
    /// - Parameters:
    ///   - completion: How to handle the command buffer after encoding.
    ///   - content: Child elements that encode GPU work.
    public init(completion: MTLCommandQueueCompletion, @ElementBuilder content: () throws -> Content) rethrows {
        self.completion = completion
        self.content = try content()
    }

    func workloadEnter(_ node: Node) throws {
        let commandQueue = try node.environmentValues.commandQueue.orThrow(.missingEnvironment(\.commandQueue))
        let commandBufferDescriptor = MTLCommandBufferDescriptor()
        // TODO: #89 Users cannot modify the environment here. This is a problem.
        if ProcessInfo.processInfo.metalLoggingEnabled {
            try commandBufferDescriptor.addDefaultLogging()
        }
        // TODO: #90 There isn't an opportunity to modify the descriptor here.
        let commandBuffer = try commandQueue._makeCommandBuffer(descriptor: commandBufferDescriptor)
        node.environmentValues.commandBuffer = commandBuffer
    }

    func workloadExit(_ node: Node) throws {
        let commandBuffer = try node.environmentValues.commandBuffer.orThrow(.missingEnvironment(\.commandBuffer))
        switch completion {
        case .none:
            break

        case .commit:
            commandBuffer.commit()

        case .commitAndWaitUntilCompleted:
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
}

// MARK: -

public extension Element {
    func onCommandBufferScheduled(_ action: @escaping (MTLCommandBuffer) -> Void) -> some Element {
        EnvironmentReader(keyPath: \.commandBuffer) { commandBuffer in
            // Copy action into a nonisolated(unsafe) local so the @Sendable closure can capture it safely.
            nonisolated(unsafe) let actionCopy = action
            return self.onWorkloadEnter { _ in
                if let commandBuffer {
                    commandBuffer.addScheduledHandler { commandBuffer in
                        actionCopy(commandBuffer)
                    }
                }
            }
        }
    }

    func onCommandBufferCompleted(_ action: @escaping (MTLCommandBuffer) -> Void) -> some Element {
        EnvironmentReader(keyPath: \.commandBuffer) { commandBuffer in
            // Copy action into a nonisolated(unsafe) local so the @Sendable closure can capture it safely.
            nonisolated(unsafe) let actionCopy = action
            return self.onWorkloadEnter { _ in
                if let commandBuffer {
                    guard commandBuffer.status == .notEnqueued || commandBuffer.status == .enqueued else {
                        logger?.warning("onCommandBufferCompleted: Command buffer is already completed or in error state; handler will not be added.")
                        return
                    }

                    commandBuffer.addCompletedHandler { commandBuffer in
                        actionCopy(commandBuffer)
                    }
                }
            }
        }
    }
}
