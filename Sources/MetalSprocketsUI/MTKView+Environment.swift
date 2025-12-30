import Metal
import MetalKit
import SwiftUI

// MARK: - MTKView Environment Configuration
//
// These view modifiers configure the underlying MTKView used by RenderView.
// Apply them to RenderView or any ancestor view.
//
// Example:
//     RenderView { context, size in ... }
//         .metalDepthStencilPixelFormat(.depth32Float)
//         .metalColorPixelFormat(.bgra8Unorm_srgb)
//         .metalClearColor(MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1))

internal extension EnvironmentValues {
    // swiftlint:disable discouraged_optional_boolean
    @Entry var metalFramebufferOnly: Bool?
    @Entry var metalDepthStencilAttachmentTextureUsage: MTLTextureUsage?
    @Entry var metalMultisampleColorAttachmentTextureUsage: MTLTextureUsage?
    @Entry var metalPresentsWithTransaction: Bool?
    @Entry var metalColorPixelFormat: MTLPixelFormat?
    @Entry var metalDepthStencilPixelFormat: MTLPixelFormat?
    @Entry var metalDepthStencilStorageMode: MTLStorageMode?
    @Entry var metalSampleCount: Int?
    @Entry var metalClearColor: MTLClearColor?
    @Entry var metalClearDepth: Double?
    @Entry var metalClearStencil: UInt32?
    @Entry var metalPreferredFramesPerSecond: Int?
    @Entry var metalEnableSetNeedsDisplay: Bool?
    @Entry var metalAutoResizeDrawable: Bool?
    @Entry var metalIsPaused: Bool?
    #if os(macOS)
    @Entry var metalColorspace: CGColorSpace?
    #endif
    // swiftlint:enable discouraged_optional_boolean
}

// MARK: - MTKView Configuration Modifiers

public extension View {
    /// Sets whether the drawable textures are used only for rendering.
    ///
    /// When `true`, Metal can optimize the textures for rendering only.
    /// Set to `false` if you need to sample from the drawable.
    func metalFramebufferOnly(_ value: Bool) -> some View {
        self.environment(\.metalFramebufferOnly, value)
    }

    /// Sets the texture usage for depth/stencil attachments.
    func metalDepthStencilAttachmentTextureUsage(_ value: MTLTextureUsage) -> some View {
        self.environment(\.metalDepthStencilAttachmentTextureUsage, value)
    }

    /// Sets the texture usage for multisample color attachments.
    func metalMultisampleColorAttachmentTextureUsage(_ value: MTLTextureUsage) -> some View {
        self.environment(\.metalMultisampleColorAttachmentTextureUsage, value)
    }

    /// Sets whether drawable presentation is synchronized with Core Animation transactions.
    func metalPresentsWithTransaction(_ value: Bool) -> some View {
        self.environment(\.metalPresentsWithTransaction, value)
    }

    /// Sets the pixel format for the color render target.
    ///
    /// Common formats:
    /// - `.bgra8Unorm`: Standard 8-bit per channel
    /// - `.bgra8Unorm_srgb`: sRGB color space (recommended for most apps)
    /// - `.rgba16Float`: HDR rendering
    ///
    /// ```swift
    /// RenderView { ... }
    ///     .metalColorPixelFormat(.bgra8Unorm_srgb)
    /// ```
    ///
    /// - Note: TODO #274 - This is so important it should be a parameter on RenderView?
    func metalColorPixelFormat(_ value: MTLPixelFormat) -> some View {
        self.environment(\.metalColorPixelFormat, value)
    }

    /// Sets the pixel format for the depth/stencil render target.
    ///
    /// Common formats:
    /// - `.depth32Float`: 32-bit floating point depth
    /// - `.depth32Float_stencil8`: Depth with 8-bit stencil
    ///
    /// Required for depth testing. Use with `.depthCompare()` on your pipeline.
    ///
    /// ```swift
    /// RenderView { ... }
    ///     .metalDepthStencilPixelFormat(.depth32Float)
    /// ```
    ///
    /// - Note: TODO #274 - This is so important it should be a parameter on RenderView?
    func metalDepthStencilPixelFormat(_ value: MTLPixelFormat) -> some View {
        self.environment(\.metalDepthStencilPixelFormat, value)
    }

    /// Sets the storage mode for depth/stencil textures.
    func metalDepthStencilStorageMode(_ value: MTLStorageMode) -> some View {
        self.environment(\.metalDepthStencilStorageMode, value)
    }

    /// Sets the number of samples for MSAA (multisample anti-aliasing).
    ///
    /// Common values: 1 (no MSAA), 2, 4, 8
    func metalSampleCount(_ value: Int) -> some View {
        self.environment(\.metalSampleCount, value)
    }

    /// Sets the color used to clear the drawable at the start of each frame.
    ///
    /// ```swift
    /// RenderView { ... }
    ///     .metalClearColor(MTLClearColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0))
    /// ```
    func metalClearColor(_ value: MTLClearColor) -> some View {
        self.environment(\.metalClearColor, value)
    }

    /// Sets the value used to clear the depth buffer (default: 1.0).
    func metalClearDepth(_ value: Double) -> some View {
        self.environment(\.metalClearDepth, value)
    }

    /// Sets the value used to clear the stencil buffer.
    func metalClearStencil(_ value: UInt32) -> some View {
        self.environment(\.metalClearStencil, value)
    }

    /// Sets the preferred frame rate for rendering.
    ///
    /// The system will attempt to render at this rate but may throttle
    /// based on device capabilities and power state.
    func metalPreferredFramesPerSecond(_ value: Int) -> some View {
        self.environment(\.metalPreferredFramesPerSecond, value)
    }

    /// Sets whether the view uses `setNeedsDisplay` for drawing.
    ///
    /// When `true`, you must call `setNeedsDisplay()` to trigger redraws.
    /// When `false` (default), the view redraws continuously.
    func metalEnableSetNeedsDisplay(_ value: Bool) -> some View {
        self.environment(\.metalEnableSetNeedsDisplay, value)
    }

    /// Sets whether the drawable automatically resizes with the view.
    func metalAutoResizeDrawable(_ value: Bool) -> some View {
        self.environment(\.metalAutoResizeDrawable, value)
    }

    /// Pauses or resumes rendering.
    ///
    /// When `true`, the render loop stops and no frames are drawn.
    func metalIsPaused(_ value: Bool) -> some View {
        self.environment(\.metalIsPaused, value)
    }

    #if os(macOS)
    /// Sets the color space for the drawable (macOS only).
    func metalColorspace(_ value: CGColorSpace?) -> some View {
        self.environment(\.metalColorspace, value)
    }
    #endif
}

extension MTKView {
    // swiftlint:disable:next cyclomatic_complexity
    func configure(from environment: EnvironmentValues) {
        if let value = environment.metalFramebufferOnly {
            self.framebufferOnly = value
        }
        if let value = environment.metalDepthStencilAttachmentTextureUsage {
            self.depthStencilAttachmentTextureUsage = value
        }
        if let value = environment.metalMultisampleColorAttachmentTextureUsage {
            self.multisampleColorAttachmentTextureUsage = value
        }
        if let value = environment.metalPresentsWithTransaction {
            self.presentsWithTransaction = value
        }
        if let value = environment.metalColorPixelFormat {
            self.colorPixelFormat = value
        }
        if let value = environment.metalDepthStencilPixelFormat {
            self.depthStencilPixelFormat = value
        }
        if let value = environment.metalDepthStencilStorageMode {
            self.depthStencilStorageMode = value
        }
        if let value = environment.metalSampleCount {
            self.sampleCount = value
        }
        if let value = environment.metalClearColor {
            self.clearColor = value
        }
        if let value = environment.metalClearDepth {
            self.clearDepth = value
        }
        if let value = environment.metalClearStencil {
            self.clearStencil = value
        }
        if let value = environment.metalPreferredFramesPerSecond {
            self.preferredFramesPerSecond = value
        }
        if let value = environment.metalEnableSetNeedsDisplay {
            self.enableSetNeedsDisplay = value
        }
        if let value = environment.metalAutoResizeDrawable {
            self.autoResizeDrawable = value
        }
        if let value = environment.metalIsPaused {
            self.isPaused = value
        }
        #if os(macOS)
        if let value = environment.metalColorspace {
            self.colorspace = value
        }
        #endif
    }
}
