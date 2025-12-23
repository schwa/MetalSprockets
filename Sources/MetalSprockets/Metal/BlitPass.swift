import Metal

// MARK: - BlitPass

/// A container element that creates a Metal blit command encoder.
///
/// Use `BlitPass` for GPU memory operations like copying textures,
/// generating mipmaps, and synchronizing resources.
///
/// ## Overview
///
/// Perform texture operations:
///
/// ```swift
/// BlitPass {
///     Blit { encoder in
///         encoder.copy(from: sourceTexture, to: destTexture)
///     }
///     Blit { encoder in
///         encoder.generateMipmaps(for: texture)
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Related Elements
/// - ``Blit``
/// - ``RenderPass``
/// - ``ComputePass``
public struct BlitPass <Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    internal let content: Content

    /// Creates a blit pass with the specified content.
    public init(@ElementBuilder content: () throws -> Content) throws {
        self.content = try content()
    }

    func workloadEnter(_ node: Node) throws {
        let commandBuffer = try node.environmentValues.commandBuffer.orThrow(.missingEnvironment(\.commandBuffer))
        let blitCommandEncoder = try commandBuffer._makeBlitCommandEncoder()
        node.environmentValues.blitCommandEncoder = blitCommandEncoder
    }

    func workloadExit(_ node: Node) throws {
        let blitCommandEncoder = try node.environmentValues.blitCommandEncoder.orThrow(.missingEnvironment(\.blitCommandEncoder))
        blitCommandEncoder.endEncoding()
    }

    nonisolated func requiresSetup(comparedTo old: BlitPass<Content>) -> Bool {
        // BlitPass only creates encoders during workload, never needs setup
        false
    }
}

// MARK: - Blit

/// Issues blit commands to a Metal blit command encoder.
///
/// `Blit` provides direct access to `MTLBlitCommandEncoder` for memory
/// operations. Place it inside a ``BlitPass``.
///
/// ## Example
///
/// ```swift
/// BlitPass {
///     Blit { encoder in
///         // Copy texture
///         encoder.copy(from: source, to: destination)
///
///         // Generate mipmaps
///         encoder.generateMipmaps(for: texture)
///     }
/// }
/// ```
public struct Blit: Element, BodylessElement {
    var block: (MTLBlitCommandEncoder) throws -> Void

    /// Creates a blit element with the specified encoding closure.
    ///
    /// - Parameter block: A closure that receives the blit command encoder.
    public init(_ block: @escaping (MTLBlitCommandEncoder) throws -> Void) {
        self.block = block
    }

    func workloadEnter(_ node: Node) throws {
        let blitCommandEncoder = try node.environmentValues.blitCommandEncoder.orThrow(.missingEnvironment(\.blitCommandEncoder))
        try block(blitCommandEncoder)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        // Blit only encodes during workload, never needs setup
        false
    }
}
