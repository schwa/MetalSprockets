import Metal
import MetalSprocketsSupport

// MARK: - Indirect command buffers

public extension MTLDevice {
    /// Makes an indirect command buffer for render commands that inherit the enclosing ``Draw``'s state: its pipeline,
    /// argument tables, depth/stencil state, depth bias, cull mode, winding and fill mode.
    ///
    /// Encode commands into it from the CPU with `indirectRenderCommandAt(_:)`, or from a compute kernel bound with
    /// ``Element/parameter(_:functionTypes:indirectCommandBuffer:)``. Execute it with
    /// ``Draw/init(indirectCommandBuffer:range:resources:)``.
    func makeRenderIndirectCommandBuffer(commandTypes: MTLIndirectCommandType = [.draw, .drawIndexed], maxCommandCount: Int, options: MTLResourceOptions = .storageModePrivate) throws -> any MTLIndirectCommandBuffer {
        let descriptor = MTLIndirectCommandBufferDescriptor()
        descriptor.commandTypes = commandTypes
        descriptor.inheritPipelineState = true
        descriptor.inheritBuffers = true
        descriptor.inheritDepthStencilState = true
        descriptor.inheritDepthBias = true
        descriptor.inheritDepthClipMode = true
        descriptor.inheritCullMode = true
        descriptor.inheritFrontFacingWinding = true
        descriptor.inheritTriangleFillMode = true
        return try makeIndirectCommandBuffer(descriptor: descriptor, maxCommandCount: maxCommandCount, options: options)
            .orThrow(.resourceCreationFailure("Failed to create indirect command buffer with \(maxCommandCount) commands."))
    }
}

public extension Draw {
    /// Executes `range` of `indirectCommandBuffer` with the enclosing pipeline's state and parameters.
    ///
    /// The enclosing pipeline must support indirect command buffers (``Element/supportsIndirectCommandBuffers()``).
    /// `resources` are buffers and textures the commands reach that no parameter binds, such as vertex and index
    /// buffers set on the commands. They are kept resident and alive for the submission.
    init(indirectCommandBuffer: any MTLIndirectCommandBuffer, range: Range<Int>, resources: [any MTLResource] = []) {
        self.init(resources: [indirectCommandBuffer] + resources) { encoder in
            guard range.lowerBound >= 0, range.upperBound <= indirectCommandBuffer.size else {
                throw EncodingFailure.invalidRange("commands \(range) exceed indirect command buffer size \(indirectCommandBuffer.size)")
            }
            encoder.executeCommands(buffer: indirectCommandBuffer, range: range)
        }
    }

    /// Executes the range of `indirectCommandBuffer` that the GPU reads from `rangeBuffer`
    /// (`MTLIndirectCommandBufferExecutionRange`), for example one a culling kernel wrote this frame.
    init(indirectCommandBuffer: any MTLIndirectCommandBuffer, rangeBuffer: any MTLBuffer, rangeBufferOffset: Int = 0, resources: [any MTLResource] = []) {
        self.init(resources: [indirectCommandBuffer, rangeBuffer] + resources) { encoder in
            let address = try IndirectArguments<MTLIndirectCommandBufferExecutionRange>.address(rangeBuffer, offset: rangeBufferOffset)
            encoder.executeCommands(buffer: indirectCommandBuffer, indirectBuffer: address)
        }
    }
}

public extension Element {
    /// Builds the enclosing render pipelines with support for indirect command buffers.
    func supportsIndirectCommandBuffers() -> some Element {
        renderPipelineDescriptorTransformer { $0.supportIndirectCommandBuffers = .enabled }
    }

    /// Binds `indirectCommandBuffer` so a kernel can encode commands into it, and keeps it resident.
    ///
    /// Metal passes a `command_buffer` inside an argument buffer. The shader declares the parameter as a pointer to a
    /// struct whose only member is the command buffer:
    ///
    /// ```metal
    /// struct Commands { command_buffer buffer; };
    /// kernel void encode(device Commands &commands [[buffer(0)]], ...) { ... }
    /// ```
    func parameter(_ name: String, functionTypes: FunctionTypes = [], indirectCommandBuffer: any MTLIndirectCommandBuffer) -> some Element {
        parameter(name, functionTypes: functionTypes, value: indirectCommandBuffer.gpuResourceID)
            .useComputeResources([indirectCommandBuffer], usage: [.read, .write])
    }
}
