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
        if let handler = node.environmentValues.commandBufferScheduledHandler {
            commandBuffer.addScheduledHandler { buffer in
                handler(buffer)
            }
        }
        if let handler = node.environmentValues.commandBufferCompletedHandler {
            commandBuffer.addCompletedHandler { buffer in
                handler(buffer)
            }
        }
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
    /// Registers a handler called when the command buffer is scheduled for execution.
    ///
    /// The handler is attached to the command buffer in `CommandBufferElement.workloadExit`,
    /// just before the buffer is committed.
    func onCommandBufferScheduled(_ action: @escaping @Sendable (MTLCommandBuffer) -> Void) -> some Element {
        environment(\.commandBufferScheduledHandler, action)
    }

    /// Registers a handler called when the command buffer completes execution.
    ///
    /// The handler is attached to the command buffer in `CommandBufferElement.workloadExit`,
    /// just before the buffer is committed. Use this to read GPU timing via
    /// `commandBuffer.gpuStartTime` / `gpuEndTime`.
    func onCommandBufferCompleted(_ action: @escaping @Sendable (MTLCommandBuffer) -> Void) -> some Element {
        environment(\.commandBufferCompletedHandler, action)
    }
}
