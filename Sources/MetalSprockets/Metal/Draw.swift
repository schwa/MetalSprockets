import Metal

// MARK: - Draw

/// Issues draw commands to a Metal render command encoder.
///
/// `Draw` provides direct access to the `MTLRenderCommandEncoder` to set vertex buffers,
/// bind resources, and issue draw calls. Place it inside a ``RenderPipeline``.
///
/// ## Overview
///
/// `Draw` must be placed inside a ``RenderPipeline``, which itself must be inside
/// a ``RenderPass``:
///
/// ```swift
/// RenderPass {
///     RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///         Draw { encoder in
///             encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
///         }
///         .parameter("vertices", values: [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>])
///     }
/// }
/// ```
///
/// ## Setting Shader Parameters
///
/// The preferred way to pass data to shaders is with the `.parameter()` modifier:
///
/// ```swift
/// Draw { encoder in ... }
///     .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
///     .parameter("transform", value: modelMatrix)
/// ```
///
/// For buffers, use the buffer variant:
///
/// ```swift
/// Draw { encoder in ... }
///     .parameter("vertices", buffer: vertexBuffer)
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
