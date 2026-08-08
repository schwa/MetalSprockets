import Metal
import MetalSprocketsSupport

internal struct DepthBiasModifier<Content>: Element, WorkloadElement, BodylessContentElement, Equatable where Content: Element {
    typealias Body = Never

    var depthBias: Float
    var slopeScale: Float
    var clamp: Float
    var content: Content

    func workloadEnter(_ node: Node) throws {
        let encoder = try node.environmentValues.renderCommandEncoder.orThrow(.missingEnvironment(\.renderCommandEncoder))
        encoder.setDepthBias(depthBias, slopeScale: slopeScale, clamp: clamp)
    }

    func workloadExit(_ node: Node) throws {
        // Depth bias is sticky encoder state, so it is cleared on the way out rather than leaking into siblings.
        let encoder = try node.environmentValues.renderCommandEncoder.orThrow(.missingEnvironment(\.renderCommandEncoder))
        encoder.setDepthBias(0, slopeScale: 0, clamp: 0)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.depthBias == rhs.depthBias && lhs.slopeScale == rhs.slopeScale && lhs.clamp == rhs.clamp
    }
}

public extension Element {
    /// Applies a depth bias to the draws in this element, then clears it again.
    ///
    /// Depth bias nudges fragment depth values to keep coplanar geometry (decals, wireframe overlays, shadow-map
    /// casters) from z-fighting.
    ///
    /// ```swift
    /// FlatShader(...) {
    ///     Draw { encoder in ... }
    /// }
    /// .depthBias(-0.1, slopeScale: -1.0, clamp: -0.01)
    /// ```
    ///
    /// - Parameters:
    ///   - depthBias: A constant offset added to each fragment's depth value.
    ///   - slopeScale: A scale applied to the fragment's depth slope before it is added to the bias.
    ///   - clamp: The maximum (or, for negative values, minimum) bias that may be applied.
    ///
    /// - Note: This is render-encoder state, so the modifier has to sit inside a ``RenderPass``. The bias is reset to
    ///   zero when the element's workload finishes, so it does not affect later siblings.
    func depthBias(_ depthBias: Float, slopeScale: Float = 0, clamp: Float = 0) -> some Element {
        DepthBiasModifier(depthBias: depthBias, slopeScale: slopeScale, clamp: clamp, content: self)
    }
}
