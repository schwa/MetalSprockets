import Metal
import MetalSprocketsSupport
import MetalSupport

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
            try commandBufferDescriptor.addMetalSprocketsLogging()
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
    /// Registers a handler called when the command buffer is scheduled for execution.
    ///
    /// Use this to track when GPU work begins. The handler fires asynchronously
    /// after the command buffer is scheduled but before GPU execution completes.
    ///
    /// This modifier must be used inside a ``CommandBufferElement`` or ``RenderView``.
    /// Multiple handlers can be registered and all will fire.
    ///
    /// ```swift
    /// RenderView { context, size in
    ///     try RenderPass {
    ///         // render content
    ///     }
    ///     .onCommandBufferScheduled { buffer in
    ///         print("GPU work scheduled")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter action: The handler to call when the command buffer is scheduled.
    ///   Called on an unspecified queue.
    func onCommandBufferScheduled(_ action: @escaping @Sendable (MTLCommandBuffer) -> Void) -> some Element {
        onWorkloadEnter { environmentValues in
            if let commandBuffer = environmentValues.commandBuffer {
                commandBuffer.addScheduledHandler { buffer in
                    action(buffer)
                }
            } else {
                logger?.warning("onCommandBufferScheduled: No command buffer in environment. Ensure this modifier is inside a CommandBufferElement or RenderView.")
            }
        }
    }

    /// Registers a handler called when the command buffer completes GPU execution.
    ///
    /// Use this to perform cleanup after GPU work finishes, such as returning
    /// buffers to a pool or reading GPU timing information.
    ///
    /// This modifier must be used inside a ``CommandBufferElement`` or ``RenderView``.
    /// Multiple handlers can be registered and all will fire.
    ///
    /// ```swift
    /// RenderView { context, size in
    ///     try RenderPass {
    ///         // render content
    ///     }
    ///     .onCommandBufferCompleted { buffer in
    ///         let gpuTime = buffer.gpuEndTime - buffer.gpuStartTime
    ///         print("GPU time: \(gpuTime * 1000)ms")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter action: The handler to call when the command buffer completes.
    ///   Called on an unspecified queue after GPU execution finishes.
    func onCommandBufferCompleted(_ action: @escaping (MTLCommandBuffer) -> Void) -> some Element {
        nonisolated(unsafe) let action = action
        return onWorkloadEnter { environmentValues in
            if let commandBuffer = environmentValues.commandBuffer {
                guard commandBuffer.status == .notEnqueued || commandBuffer.status == .enqueued else {
                    logger?.warning("onCommandBufferCompleted: Command buffer is already completed or in error state; handler will not be added.")
                    return
                }
                commandBuffer.addCompletedHandler { buffer in
                    action(buffer)
                }
            } else {
                logger?.warning("onCommandBufferCompleted: No command buffer in environment. Ensure this modifier is inside a CommandBufferElement or RenderView.")
            }
        }
    }
}
