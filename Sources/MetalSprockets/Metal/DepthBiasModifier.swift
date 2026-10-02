import Metal
import MetalSprocketsSupport

internal struct DepthBiasModifier<Content>: Element, WorkloadElement, BodylessContentElement, Equatable where Content: Element {
    typealias Body = Never
    var depthBias: Float
    var slopeScale: Float
    var clamp: Float
    var content: Content

    // Written every frame; each Draw sets bias explicitly, so it never leaks to siblings.
    func workloadEnter(_ node: Node) throws {
        node.environmentValues.depthBias = DepthBias(bias: depthBias, slopeScale: slopeScale, clamp: clamp)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.depthBias == rhs.depthBias && lhs.slopeScale == rhs.slopeScale && lhs.clamp == rhs.clamp
    }
}

public extension Element {
    /// Applies a depth bias to the draws in this element.
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
    /// - Note: Only draws inside this element are biased; siblings are not.
    func depthBias(_ depthBias: Float, slopeScale: Float = 0, clamp: Float = 0) -> some Element {
        DepthBiasModifier(depthBias: depthBias, slopeScale: slopeScale, clamp: clamp, content: self)
    }
}
