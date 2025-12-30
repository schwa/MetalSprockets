import Metal
import MetalSprocketsSupport

// MARK: - MSAA Modifier

/// A modifier that enables multisample anti-aliasing (MSAA) for render-to-texture scenarios.
///
/// This modifier creates the necessary multisample and resolve textures, configures the
/// render pass descriptor for MSAA rendering, and handles the resolve step automatically.
///
/// ## Overview
///
/// Apply the `.msaa()` modifier to a `RenderPass` to enable anti-aliasing:
///
/// ```swift
/// RenderPass {
///     RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///         Draw { encoder in
///             // Draw commands
///         }
///     }
/// }
/// .msaa(sampleCount: 4)
/// ```
///
/// ## How It Works
///
/// MSAA requires two textures:
/// - A **multisample texture** with `sampleCount > 1` as the render target
/// - A **resolve texture** with `sampleCount = 1` for the final output
///
/// The modifier:
/// 1. Creates both textures (cached and recreated when size changes)
/// 2. Configures the render pass to render to the multisample texture
/// 3. Sets the resolve texture and store action to `.multisampleResolve`
/// 4. After rendering, the GPU resolves the multisample data to the resolve texture
///
/// ## Topics
///
/// ### Related Modifiers
/// - ``View/metalSampleCount(_:)`` - For MTKView-based MSAA (simpler, preferred for on-screen rendering)
internal struct MSAAModifier<Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    var content: Content
    var sampleCount: Int

    @MSState
    private var multisampleTexture: MTLTexture?

    @MSState
    private var resolveTexture: MTLTexture?

    @MSState
    private var lastSize: CGSize?

    @MSState
    private var lastPixelFormat: MTLPixelFormat?

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func setupEnter(_ node: Node) throws {
        guard sampleCount > 1 else { return }

        let device = try node.environmentValues.device.orThrow(.missingEnvironment(\.device))
        guard let renderPassDescriptor = node.environmentValues.renderPassDescriptor else {
            return
        }

        // Get the current size and pixel format from the existing render pass
        guard let existingTexture = renderPassDescriptor.colorAttachments[0].texture else {
            return
        }

        let size = CGSize(width: existingTexture.width, height: existingTexture.height)
        let pixelFormat = existingTexture.pixelFormat

        // Check if we need to recreate textures
        let needsRecreate = multisampleTexture == nil
            || resolveTexture == nil
            || lastSize != size
            || lastPixelFormat != pixelFormat

        if needsRecreate {
            // Validate sample count is supported by device
            guard device.supportsTextureSampleCount(sampleCount) else {
                throw MetalSprocketsError.configurationError("Device does not support MSAA sample count \(sampleCount). Supported counts: \([2, 4, 8].filter { device.supportsTextureSampleCount($0) })")
            }

            // Create multisample texture
            let msDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: pixelFormat,
                width: Int(size.width),
                height: Int(size.height),
                mipmapped: false
            )
            msDesc.textureType = .type2DMultisample
            msDesc.sampleCount = sampleCount
            msDesc.usage = [.renderTarget]
            msDesc.storageMode = .private

            multisampleTexture = try device.makeTexture(descriptor: msDesc)
                .orThrow(.resourceCreationFailure("Failed to create multisample texture"))
            multisampleTexture?.label = "MSAA Multisample Texture (\(sampleCount)x)"

            // Create resolve texture
            let resolveDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: pixelFormat,
                width: Int(size.width),
                height: Int(size.height),
                mipmapped: false
            )
            resolveDesc.usage = [.renderTarget, .shaderRead]
            resolveDesc.storageMode = .private

            resolveTexture = try device.makeTexture(descriptor: resolveDesc)
                .orThrow(.resourceCreationFailure("Failed to create resolve texture"))
            resolveTexture?.label = "MSAA Resolve Texture"

            lastSize = size
            lastPixelFormat = pixelFormat
        }
    }

    func configureNodeBodyless(_ node: Node) throws {
        guard sampleCount > 1, let multisampleTexture, let resolveTexture else { return }

        guard let system = System.current else {
            fatalError("MSAAModifier: No System is currently active.")
        }

        // Get parent's renderPassDescriptor
        let parent = system.activeNodeStack.count >= 2 ? system.activeNodeStack[system.activeNodeStack.count - 2] : nil
        guard let renderPassDescriptor = parent?.environmentValues.renderPassDescriptor ?? node.environmentValues.renderPassDescriptor else {
            return
        }

        let copy = renderPassDescriptor.copyWithType(MTLRenderPassDescriptor.self)

        // Configure for MSAA
        copy.colorAttachments[0].texture = multisampleTexture
        copy.colorAttachments[0].resolveTexture = resolveTexture
        copy.colorAttachments[0].storeAction = .multisampleResolve

        node.environmentValues.renderPassDescriptor = copy
    }

    nonisolated func requiresSetup(comparedTo old: MSAAModifier<Content>) -> Bool {
        sampleCount != old.sampleCount
    }
}

// MARK: - Element Extension

public extension Element {
    /// Enables multisample anti-aliasing (MSAA) for render-to-texture rendering.
    ///
    /// Use this modifier when rendering to a custom texture and you want anti-aliasing.
    /// For on-screen rendering with `RenderView`, prefer using `.metalSampleCount()` on
    /// the SwiftUI view instead, as MTKView handles texture management automatically.
    ///
    /// - Parameter sampleCount: The number of samples per pixel (typically 2, 4, or 8).
    ///   Use 1 to disable MSAA.
    ///
    /// ## Example
    ///
    /// ```swift
    /// RenderPass {
    ///     RenderPipeline(vertexShader: vs, fragmentShader: fs) {
    ///         Draw { encoder in
    ///             encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    ///         }
    ///     }
    /// }
    /// .msaa(sampleCount: 4)
    /// ```
    ///
    /// - Note: MSAA increases memory usage and has a performance cost. Higher sample
    ///   counts provide better quality but at greater cost. 4x is a common balance.
    func msaa(sampleCount: Int) -> some Element {
        MSAAModifier(content: self, sampleCount: sampleCount)
    }
}
