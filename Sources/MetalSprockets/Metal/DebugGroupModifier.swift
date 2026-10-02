import Metal
import MetalSprocketsSupport

public extension Element {
    /// Wraps this element's GPU work in a named debug group.
    ///
    /// Debug groups show up as collapsible scopes in GPU captures and Instruments traces:
    ///
    /// ```swift
    /// RenderPass {
    ///     try SkyboxPipeline()
    ///     try TerrainPipeline(model: terrain)
    ///         .debugGroup("Terrain")
    /// }
    /// ```
    ///
    /// The group is pushed on the innermost active encoder, or on the command buffer when no encoder is active (so it
    /// can wrap whole passes). It is popped even when the content throws.
    ///
    /// - Parameter label: The name shown in capture tools.
    func debugGroup(_ label: String) -> some Element {
        DebugGroupModifier(label: label, content: self)
    }
}
