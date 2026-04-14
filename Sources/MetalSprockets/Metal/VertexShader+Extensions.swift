import Metal
import MetalSupport

public extension VertexShader {
    func inferredVertexDescriptor() throws -> MTLVertexDescriptor? {
        try function.inferredVertexDescriptor()
    }
}
