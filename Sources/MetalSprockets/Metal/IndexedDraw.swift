import Metal
import MetalKit
import MetalSprocketsSupport

// MARK: - Indexed draws

// Metal 4 indexed draws take a GPU address and byte length instead of an MTLBuffer. These wrappers compute both,
// validate the range, and keep the index buffer resident, so callers cannot forget `.useResource`.

public extension Draw {
    /// Draws indexed primitives from `indexBuffer`. `indexBufferOffset` is in bytes.
    init(primitiveType: MTLPrimitiveType, indexBuffer: any MTLBuffer, indexType: MTLIndexType, indexCount: Int, indexBufferOffset: Int = 0, instanceCount: Int = 1) {
        let indices = IndexBuffer(buffer: indexBuffer, type: indexType, indexCount: indexCount, offset: indexBufferOffset)
        self.init(resources: [indexBuffer]) { encoder in
            try encoder.drawIndexed(primitiveType: primitiveType, indices: indices, instanceCount: instanceCount)
        }
    }

    /// Draws every submesh of `mesh`. Bind its vertex buffers with ``Element/vertexBuffers(of:)``.
    init(mesh: MTKMesh, instanceCount: Int = 1) {
        let submeshes = mesh.submeshes.map { submesh in
            (primitiveType: submesh.primitiveType, indices: IndexBuffer(buffer: submesh.indexBuffer.buffer, type: submesh.indexType, indexCount: submesh.indexCount, offset: submesh.indexBuffer.offset))
        }
        self.init(resources: mesh.submeshes.map(\.indexBuffer.buffer)) { encoder in
            for submesh in submeshes {
                try encoder.drawIndexed(primitiveType: submesh.primitiveType, indices: submesh.indices, instanceCount: instanceCount)
            }
        }
    }
}

public extension Element {
    /// Binds each of `mesh`'s vertex buffers to the vertex-descriptor layout index matching its position.
    func vertexBuffers(of mesh: MTKMesh) -> some Element {
        ParameterModifier(content: self) { parameters in
            for (index, vertexBuffer) in mesh.vertexBuffers.enumerated() {
                parameters.setVertexBuffer(vertexBuffer.buffer, layoutIndex: index, offset: vertexBuffer.offset)
            }
        }
    }
}

private extension MTL4RenderCommandEncoder {
    func drawIndexed(primitiveType: MTLPrimitiveType, indices: IndexBuffer, instanceCount: Int) throws {
        let range = try indices.validatedRange()
        drawIndexedPrimitives(primitiveType: primitiveType, indexCount: indices.indexCount, indexType: indices.type, indexBuffer: range.address, indexBufferLength: range.length, instanceCount: instanceCount)
    }
}
