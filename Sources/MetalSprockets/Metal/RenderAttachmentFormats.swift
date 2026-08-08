import Metal
import MetalSprocketsSupport

/// The attachment pixel formats and sample count of the render pass currently in scope.
///
/// Descriptor producers (root runners, offscreen renderers, ``MSAAModifier``, and the
/// render-pass-descriptor modifiers) publish this alongside
/// ``MSEnvironmentValues/renderPassDescriptor`` so that pipelines can be configured without
/// reaching into the descriptor's textures. See #362.
public struct RenderAttachmentFormats: Hashable, Sendable {
    /// Colour attachment pixel formats, indexed by attachment index.
    ///
    /// Trailing unused slots are omitted; unused slots in the middle are `.invalid`.
    public var colorPixelFormats: [MTLPixelFormat]

    /// The depth attachment pixel format, or `.invalid` if there is no depth attachment.
    public var depthPixelFormat: MTLPixelFormat

    /// The stencil attachment pixel format, or `.invalid` if there is no stencil attachment.
    public var stencilPixelFormat: MTLPixelFormat

    /// The sample count of the attachments (1 when not multisampling).
    public var rasterSampleCount: Int

    public init(
        colorPixelFormats: [MTLPixelFormat] = [],
        depthPixelFormat: MTLPixelFormat = .invalid,
        stencilPixelFormat: MTLPixelFormat = .invalid,
        rasterSampleCount: Int = 1
    ) {
        self.colorPixelFormats = colorPixelFormats
        self.depthPixelFormat = depthPixelFormat
        self.stencilPixelFormat = stencilPixelFormat
        self.rasterSampleCount = rasterSampleCount
    }

    /// The pixel format of the colour attachment at `index`, or `.invalid` if there is none.
    public func colorPixelFormat(at index: Int) -> MTLPixelFormat {
        index >= 0 && index < colorPixelFormats.count ? colorPixelFormats[index] : .invalid
    }
}

public extension RenderAttachmentFormats {
    /// Maximum number of colour attachments Metal supports.
    private static let maxColorAttachments = 8

    /// Derives the formats from a render pass descriptor's attachment textures.
    init(_ descriptor: MTLRenderPassDescriptor) {
        var colorFormats: [MTLPixelFormat] = []
        var sampleCount = 1
        for index in 0..<Self.maxColorAttachments {
            let attachment = descriptor.colorAttachments[index]
            // A multisample attachment renders into `texture` and resolves into `resolveTexture`,
            // so the sample count and format always come from `texture`.
            guard let texture = attachment?.texture else {
                colorFormats.append(.invalid)
                continue
            }
            colorFormats.append(texture.pixelFormat)
            sampleCount = max(sampleCount, texture.sampleCount)
        }
        while colorFormats.last == .invalid {
            colorFormats.removeLast()
        }

        let depthTexture = descriptor.depthAttachment?.texture
        let stencilTexture = descriptor.stencilAttachment?.texture
        if let depthTexture {
            sampleCount = max(sampleCount, depthTexture.sampleCount)
        }

        self.init(
            colorPixelFormats: colorFormats,
            depthPixelFormat: depthTexture?.pixelFormat ?? .invalid,
            stencilPixelFormat: stencilTexture?.pixelFormat ?? .invalid,
            rasterSampleCount: sampleCount
        )
    }
}

public extension MSEnvironmentValues {
    /// The attachment formats of the render pass in scope. See ``RenderAttachmentFormats``.
    @MSEntry var renderAttachmentFormats: RenderAttachmentFormats?
}

public extension Element {
    /// Sets the attachment formats published to descendants.
    func renderAttachmentFormats(_ formats: RenderAttachmentFormats) -> some Element {
        environment(\.renderAttachmentFormats, formats)
    }
}
