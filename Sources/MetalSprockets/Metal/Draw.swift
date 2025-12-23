import Metal

// MARK: - Draw

/// Issues draw commands to a Metal render command encoder.
///
/// `Draw` provides direct access to the `MTLRenderCommandEncoder` to set vertex buffers,
/// bind resources, and issue draw calls. Place it inside a ``RenderPipeline``.
///
/// ## Overview
///
/// Use the closure to encode draw commands:
///
/// ```swift
/// Draw { encoder in
///     // Set vertex data
///     var vertices: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
///     encoder.setVertexBytes(&vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
///
///     // Draw the triangle
///     encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
/// }
/// ```
///
/// ## Setting Vertex Data
///
/// For small amounts of data, use `setVertexBytes`:
///
/// ```swift
/// encoder.setVertexBytes(&data, length: dataSize, index: bufferIndex)
/// ```
///
/// For larger data or data that persists across frames, use `MTLBuffer`:
///
/// ```swift
/// encoder.setVertexBuffer(buffer, offset: 0, index: bufferIndex)
/// ```
///
/// ## Draw Methods
///
/// Common draw methods include:
/// - `drawPrimitives(type:vertexStart:vertexCount:)` — Draw non-indexed geometry
/// - `drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:)` — Draw indexed geometry
/// - `drawPrimitives(type:indirectBuffer:indirectBufferOffset:)` — GPU-driven rendering
///
/// ## Topics
///
/// ### Related Elements
/// - ``RenderPipeline``
/// - ``RenderPass``
// Note: Cannot use EnvironmentReader here because Draw needs to execute during the workload phase when the render command encoder is available, not during the tree expansion phase where EnvironmentReader operates.
public struct Draw: Element, BodylessElement {
    public typealias Body = Never

    var encodeGeometry: (MTLRenderCommandEncoder) throws -> Void

    /// Creates a draw element with the specified encoding closure.
    ///
    /// - Parameter encodeGeometry: A closure that receives the `MTLRenderCommandEncoder`
    ///   and issues draw commands. Called every frame during the workload phase.
    public init(encodeGeometry: @escaping (MTLRenderCommandEncoder) throws -> Void) {
        self.encodeGeometry = encodeGeometry
    }

    func workloadEnter(_ node: Node) throws {
        let renderCommandEncoder = try node.environmentValues.renderCommandEncoder.orThrow(.missingEnvironment(\.renderCommandEncoder))
        try encodeGeometry(renderCommandEncoder)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        // Draw only encodes during workload, never needs setup
        false
    }
}
