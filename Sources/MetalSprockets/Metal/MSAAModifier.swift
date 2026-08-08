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
internal struct MSAAModifier<Content>: Element, BodylessContentElement, EnvironmentModifyingElement where Content: Element {
    var content: Content
    var sampleCount: Int

    @MSState
    private var multisampleTexture: MTLTexture?

    @MSState
    private var multisampleDepthTexture: MTLTexture?

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visit(content)
    }

    func configureNodeBodyless(_ node: Node) throws {
        guard sampleCount > 1 else {
            return
        }

        guard let system = System.current else {
            fatalError("MSAAModifier: No System is currently active.")
        }

        // The modifier rewrites the render pass descriptor, so it only means anything when it
        // wraps a whole pass. Placed inside one it used to be a silent no-op (see #355).
        if system.activeNodeStack.dropLast().contains(where: { $0.element is any RenderPassElement }) {
            throw MetalSprocketsError.configurationError("`.msaa(sampleCount:)` must be placed on a RenderPass (or an element containing one), not on content inside a render pass.")
        }

        // Get parent's renderPassDescriptor
        let parent = system.activeNodeStack.count >= 2 ? system.activeNodeStack[system.activeNodeStack.count - 2] : nil
        guard let renderPassDescriptor = parent?.environmentValues.renderPassDescriptor ?? node.environmentValues.renderPassDescriptor else {
            throw MetalSprocketsError.configurationError("`.msaa(sampleCount:)` must be placed on an element that renders into a render pass; no render pass descriptor was found in the environment.")
        }
        guard let targetTexture = renderPassDescriptor.colorAttachments[0].texture else {
            throw MetalSprocketsError.configurationError("`.msaa(sampleCount:)` requires a color attachment texture on the render pass descriptor.")
        }

        let device = try node.environmentValues.device.orThrow(.missingEnvironment(\.device))
        let multisampleTexture = try multisampleTexture(device: device, matching: targetTexture)

        let copy = renderPassDescriptor.copyWithType(MTLRenderPassDescriptor.self)
        // Render into the multisample texture and let the GPU resolve straight back into
        // the texture the caller supplied, so no copy-back step is needed (see #354).
        copy.colorAttachments[0].texture = multisampleTexture
        copy.colorAttachments[0].resolveTexture = targetTexture
        copy.colorAttachments[0].storeAction = .multisampleResolve

        // Depth has to match the colour attachment's sample count or the pass is invalid.
        if let depthTexture = renderPassDescriptor.depthAttachment?.texture {
            copy.depthAttachment.texture = try multisampleDepthTexture(device: device, matching: depthTexture)
            copy.depthAttachment.storeAction = .dontCare
        }

        node.environmentValues.renderPassDescriptor = copy
    }

    private func multisampleTexture(device: MTLDevice, matching targetTexture: MTLTexture) throws -> MTLTexture {
        if let existing = multisampleTexture,
            existing.width == targetTexture.width,
            existing.height == targetTexture.height,
            existing.pixelFormat == targetTexture.pixelFormat,
            existing.sampleCount == sampleCount {
            return existing
        }
        guard device.supportsTextureSampleCount(sampleCount) else {
            throw MetalSprocketsError.configurationError("Device does not support MSAA sample count \(sampleCount). Supported counts: \([2, 4, 8].filter { device.supportsTextureSampleCount($0) })")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: targetTexture.pixelFormat,
            width: targetTexture.width,
            height: targetTexture.height,
            mipmapped: false
        )
        descriptor.textureType = .type2DMultisample
        descriptor.sampleCount = sampleCount
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .private
        let texture = try device.makeTexture(descriptor: descriptor)
            .orThrow(.resourceCreationFailure("Failed to create multisample texture"))
        texture.label = "MSAA Multisample Texture (\(sampleCount)x)"
        multisampleTexture = texture
        return texture
    }

    private func multisampleDepthTexture(device: MTLDevice, matching depthTexture: MTLTexture) throws -> MTLTexture {
        if let existing = multisampleDepthTexture,
            existing.width == depthTexture.width,
            existing.height == depthTexture.height,
            existing.pixelFormat == depthTexture.pixelFormat,
            existing.sampleCount == sampleCount {
            return existing
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: depthTexture.pixelFormat,
            width: depthTexture.width,
            height: depthTexture.height,
            mipmapped: false
        )
        descriptor.textureType = .type2DMultisample
        descriptor.sampleCount = sampleCount
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .private
        let texture = try device.makeTexture(descriptor: descriptor)
            .orThrow(.resourceCreationFailure("Failed to create multisample depth texture"))
        texture.label = "MSAA Multisample Depth Texture (\(sampleCount)x)"
        multisampleDepthTexture = texture
        return texture
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
