import Metal
import MetalSupport

public extension VertexShader {
    func inferredVertexDescriptor() -> MTLVertexDescriptor? {
        function.inferredVertexDescriptor()
    }
}
