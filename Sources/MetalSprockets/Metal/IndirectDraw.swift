import Metal
import MetalSprocketsSupport

// MARK: - Indirect draws

// The GPU reads the draw arguments from a buffer, often one a compute pass filled this frame. These wrappers compute
// the Metal 4 GPU addresses, validate the ranges, and keep the buffers resident.

public extension Draw {
    /// Draws primitives with arguments the GPU reads from `indirectBuffer` (`MTLDrawPrimitivesIndirectArguments`).
    init(primitiveType: MTLPrimitiveType, indirectBuffer: any MTLBuffer, indirectBufferOffset: Int = 0) {
        self.init(resources: [indirectBuffer], geometry: .indirect(primitiveType, buffer: indirectBuffer, offset: indirectBufferOffset))
    }

    /// Draws indexed primitives with arguments the GPU reads from `indirectBuffer`
    /// (`MTLDrawIndexedPrimitivesIndirectArguments`). The arguments' `indexStart` is relative to `indexBufferOffset`.
    init(primitiveType: MTLPrimitiveType, indexBuffer: any MTLBuffer, indexType: MTLIndexType, indexBufferOffset: Int = 0, indirectBuffer: any MTLBuffer, indirectBufferOffset: Int = 0) {
        self.init(resources: [indexBuffer, indirectBuffer], geometry: .indexedIndirect(IndexedIndirect(primitiveType: primitiveType, indexBuffer: indexBuffer, indexType: indexType, indexBufferOffset: indexBufferOffset, indirectBuffer: indirectBuffer, indirectBufferOffset: indirectBufferOffset)))
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
