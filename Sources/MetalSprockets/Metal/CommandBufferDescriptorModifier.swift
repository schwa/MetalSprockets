import Metal
import MetalSprocketsSupport

public extension MSEnvironmentValues {
    /// The descriptor ``CommandBufferElement`` uses when it creates a command buffer.
    ///
    /// When `nil` a fresh `MTLCommandBufferDescriptor` is used.
    @MSEntry var commandBufferDescriptor: MTLCommandBufferDescriptor?
}

public extension Element {
    /// Sets the command buffer descriptor used by ``CommandBufferElement`` in this subtree.
    ///
    /// The descriptor is copied, so the value passed in is never mutated by MetalSprockets.
    func commandBufferDescriptor(_ commandBufferDescriptor: MTLCommandBufferDescriptor) -> some Element {
        environment(\.commandBufferDescriptor, commandBufferDescriptor.copyWithType(MTLCommandBufferDescriptor.self))
    }

    /// Mutates the command buffer descriptor used by ``CommandBufferElement`` in this subtree.
    ///
    /// ```swift
    /// CommandBufferElement(completion: .commit) { ... }
    ///     .commandBufferDescriptorModifier { descriptor in
    ///         descriptor.errorOptions = .encoderExecutionStatus
    ///     }
    /// ```
    ///
    /// The inherited descriptor (if any) is copied before the closure runs, so a descriptor
    /// shared with an ancestor is never mutated in place.
    func commandBufferDescriptorModifier(_ modify: @escaping (MTLCommandBufferDescriptor) -> Void) -> some Element {
        transformEnvironment(\.commandBufferDescriptor) { descriptor in
            let copy = descriptor?.copyWithType(MTLCommandBufferDescriptor.self) ?? MTLCommandBufferDescriptor()
            modify(copy)
            descriptor = copy
        }
    }
}
