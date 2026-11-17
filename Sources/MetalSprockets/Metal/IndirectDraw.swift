import Metal
import MetalSprocketsSupport

// MARK: - Indirect draws

// The GPU reads the draw arguments from a buffer, often one a compute pass filled this frame. These wrappers compute
// the Metal 4 GPU addresses, validate the ranges, and keep the buffers resident.

public extension Draw {
    /// Draws primitives with arguments the GPU reads from `indirectBuffer` (`MTLDrawPrimitivesIndirectArguments`).
    init(primitiveType: MTLPrimitiveType, indirectBuffer: any MTLBuffer, indirectBufferOffset: Int = 0) {
        self.init(resources: [indirectBuffer]) { encoder in
            let arguments = try IndirectArguments<MTLDrawPrimitivesIndirectArguments>.address(indirectBuffer, offset: indirectBufferOffset)
            encoder.drawPrimitives(primitiveType: primitiveType, indirectBuffer: arguments)
        }
    }

    /// Draws indexed primitives with arguments the GPU reads from `indirectBuffer`
    /// (`MTLDrawIndexedPrimitivesIndirectArguments`). The arguments' `indexStart` is relative to `indexBufferOffset`.
    init(primitiveType: MTLPrimitiveType, indexBuffer: any MTLBuffer, indexType: MTLIndexType, indexBufferOffset: Int = 0, indirectBuffer: any MTLBuffer, indirectBufferOffset: Int = 0) {
        self.init(resources: [indexBuffer, indirectBuffer]) { encoder in
            let indexSize = indexType == .uint16 ? 2 : 4
            guard indexBufferOffset >= 0, indexBufferOffset.isMultiple(of: indexSize), indexBufferOffset < indexBuffer.length else {
                throw EncodingFailure.invalidRange("index buffer offset \(indexBufferOffset) is invalid for index buffer length \(indexBuffer.length)")
            }
            let arguments = try IndirectArguments<MTLDrawIndexedPrimitivesIndirectArguments>.address(indirectBuffer, offset: indirectBufferOffset)
            let indexLength = (indexBuffer.length - indexBufferOffset) / indexSize * indexSize
            encoder.drawIndexedPrimitives(primitiveType: primitiveType, indexType: indexType, indexBuffer: indexBuffer.gpuAddress + UInt64(indexBufferOffset), indexBufferLength: indexLength, indirectBuffer: arguments)
        }
    }
}

internal enum IndirectArguments<Arguments> {
    /// The GPU address of one `Arguments` record, after checking it lies inside the buffer.
    static func address(_ buffer: any MTLBuffer, offset: Int) throws -> MTLGPUAddress {
        guard offset >= 0, offset.isMultiple(of: 4), offset + MemoryLayout<Arguments>.size <= buffer.length else {
            throw EncodingFailure.invalidIndirectOffset(offset)
        }
        return buffer.gpuAddress + UInt64(offset)
    }
}
