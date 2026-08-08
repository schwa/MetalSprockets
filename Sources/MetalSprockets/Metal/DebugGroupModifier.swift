import Metal
import MetalSprocketsSupport

internal struct DebugGroupModifier<Content>: Element, WorkloadElement, BodylessContentElement, Equatable where Content: Element {
    typealias Body = Never

    var label: String
    var content: Content

    func workloadEnter(_ node: Node) throws {
        try debugGroupTarget(for: node).push(label)
    }

    func workloadExit(_ node: Node) throws {
        try debugGroupTarget(for: node).pop()
    }

    /// The innermost thing that can carry a debug group: whichever encoder is current, or the command buffer when the
    /// modifier wraps whole passes.
    private func debugGroupTarget(for node: Node) throws -> DebugGroupTarget {
        let environmentValues = node.environmentValues
        if let encoder = environmentValues.renderCommandEncoder {
            return .encoder(encoder)
        }
        if let encoder = environmentValues.computeCommandEncoder {
            return .encoder(encoder)
        }
        if let encoder = environmentValues.blitCommandEncoder {
            return .encoder(encoder)
        }
        return .commandBuffer(try environmentValues.commandBuffer.orThrow(.missingEnvironment(\.commandBuffer)))
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.label == rhs.label
    }
}

private enum DebugGroupTarget {
    case encoder(any MTLCommandEncoder)
    case commandBuffer(any MTLCommandBuffer)

    func push(_ label: String) {
        switch self {
        case .encoder(let encoder):
            encoder.pushDebugGroup(label)
        case .commandBuffer(let commandBuffer):
            commandBuffer.pushDebugGroup(label)
        }
    }

    func pop() {
        switch self {
        case .encoder(let encoder):
            encoder.popDebugGroup()
        case .commandBuffer(let commandBuffer):
            commandBuffer.popDebugGroup()
        }
    }
}

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
    /// can wrap whole passes).
    ///
    /// - Parameter label: The name shown in capture tools.
    func debugGroup(_ label: String) -> some Element {
        DebugGroupModifier(label: label, content: self)
    }
}
