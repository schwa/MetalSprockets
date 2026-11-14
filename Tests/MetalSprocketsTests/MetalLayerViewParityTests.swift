import Metal
import MetalKit
@testable import MetalSprocketsUI
import Testing

// MetalLayerView replaces MTKView in RenderView (#560). Its render pass descriptors must match MTKView's.
@MainActor
@Suite("MetalLayerView matches MTKView", .requiresMetal4)
struct MetalLayerViewParityTests {
    struct Configuration: CustomTestStringConvertible, Sendable {
        var colorPixelFormat: MTLPixelFormat = .bgra8Unorm
        var depthStencilPixelFormat: MTLPixelFormat = .invalid
        var sampleCount = 1
        var depthStencilStorageMode: MTLStorageMode = .private
        var depthStencilUsage: MTLTextureUsage = .renderTarget
        var multisampleColorUsage: MTLTextureUsage = .renderTarget

        var testDescription: String {
            "color \(colorPixelFormat.rawValue) depth \(depthStencilPixelFormat.rawValue) samples \(sampleCount) storage \(depthStencilStorageMode.rawValue) usage \(depthStencilUsage.rawValue)"
        }
    }

    struct Attachment: Equatable {
        var pixelFormat: MTLPixelFormat?
        var textureType: MTLTextureType?
        var sampleCount: Int?
        var width: Int?
        var height: Int?
        var usage: MTLTextureUsage.RawValue?
        var storageMode: MTLStorageMode?
        var hasResolve: Bool
        var loadAction: MTLLoadAction
        var storeAction: MTLStoreAction

        init(_ attachment: MTLRenderPassAttachmentDescriptor, isDrawable: Bool) {
            let texture = attachment.texture
            pixelFormat = texture?.pixelFormat
            textureType = texture?.textureType
            sampleCount = texture?.sampleCount
            width = texture?.width
            height = texture?.height
            // Drawable textures come from the layer and differ only in usage flags CoreAnimation adds.
            usage = isDrawable ? nil : texture?.usage.rawValue
            storageMode = isDrawable ? nil : texture?.storageMode
            hasResolve = attachment.resolveTexture != nil
            loadAction = attachment.loadAction
            storeAction = attachment.storeAction
        }
    }

    struct Summary: Equatable {
        var color: Attachment
        var depth: Attachment
        var stencil: Attachment
        var clearColor: [Double]
        var clearDepth: Double
        var clearStencil: UInt32
        var drawableIsColorTexture: Bool

        init(_ descriptor: MTL4RenderPassDescriptor, drawable: any MTLTexture) {
            let color = descriptor.colorAttachments[0]!
            drawableIsColorTexture = color.texture === drawable
            self.color = Attachment(color, isDrawable: drawableIsColorTexture)
            depth = Attachment(descriptor.depthAttachment, isDrawable: false)
            stencil = Attachment(descriptor.stencilAttachment, isDrawable: false)
            clearColor = [color.clearColor.red, color.clearColor.green, color.clearColor.blue, color.clearColor.alpha]
            clearDepth = descriptor.depthAttachment.clearDepth
            clearStencil = descriptor.stencilAttachment.clearStencil
        }
    }

    final class MTKCapture: NSObject, MTKViewDelegate {
        var summary: Summary?
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        func draw(in view: MTKView) {
            guard let descriptor = view.currentMTL4RenderPassDescriptor, let drawable = view.currentDrawable else {
                return
            }
            summary = Summary(descriptor, drawable: drawable.texture)
        }
    }

    final class LayerCapture: MetalLayerViewDelegate, @unchecked Sendable {
        var summary: Summary?
        func metalLayerView(_ view: MetalLayerView, drawableSizeWillChange size: CGSize) {}
        func render(on surface: MetalLayerSurface) {
            guard let drawable = surface.nextDrawable() else {
                return
            }
            summary = Summary(surface.renderPassDescriptor(for: drawable), drawable: drawable.texture)
        }
    }

    nonisolated static let configurations: [Configuration] = [
        Configuration(),
        Configuration(colorPixelFormat: .bgra8Unorm_srgb, depthStencilPixelFormat: .depth32Float),
        Configuration(colorPixelFormat: .rgba16Float, depthStencilPixelFormat: .depth32Float, sampleCount: 4),
        Configuration(depthStencilPixelFormat: .depth32Float_stencil8, sampleCount: 4),
        Configuration(depthStencilPixelFormat: .stencil8),
        Configuration(depthStencilPixelFormat: .depth32Float, depthStencilStorageMode: .memoryless),
        Configuration(depthStencilPixelFormat: .depth32Float, depthStencilUsage: [.renderTarget, .shaderRead]),
        Configuration(sampleCount: 4, multisampleColorUsage: [.renderTarget, .shaderRead])
    ]

    @Test(arguments: configurations)
    func descriptorsMatch(_ configuration: Configuration) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let size = CGSize(width: 48, height: 32)
        let clearColor = MTLClearColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)

        let reference = MTKView(frame: CGRect(x: 0, y: 0, width: 48, height: 32), device: device)
        reference.isPaused = true
        reference.enableSetNeedsDisplay = true
        reference.autoResizeDrawable = false
        reference.colorPixelFormat = configuration.colorPixelFormat
        reference.depthStencilPixelFormat = configuration.depthStencilPixelFormat
        reference.depthStencilStorageMode = configuration.depthStencilStorageMode
        reference.depthStencilAttachmentTextureUsage = configuration.depthStencilUsage
        reference.multisampleColorAttachmentTextureUsage = configuration.multisampleColorUsage
        reference.sampleCount = configuration.sampleCount
        reference.clearColor = clearColor
        reference.clearDepth = 0.5
        reference.clearStencil = 3
        reference.drawableSize = size
        let referenceCapture = MTKCapture()
        reference.delegate = referenceCapture
        reference.draw()

        let candidate = MetalLayerView(frame: CGRect(x: 0, y: 0, width: 48, height: 32), device: device)
        candidate.enableSetNeedsDisplay = true
        candidate.autoResizeDrawable = false
        candidate.colorPixelFormat = configuration.colorPixelFormat
        candidate.depthStencilPixelFormat = configuration.depthStencilPixelFormat
        candidate.depthStencilStorageMode = configuration.depthStencilStorageMode
        candidate.depthStencilAttachmentTextureUsage = configuration.depthStencilUsage
        candidate.multisampleColorAttachmentTextureUsage = configuration.multisampleColorUsage
        candidate.sampleCount = configuration.sampleCount
        candidate.clearColor = clearColor
        candidate.clearDepth = 0.5
        candidate.clearStencil = 3
        candidate.drawableSize = size
        let candidateCapture = LayerCapture()
        candidate.delegate = candidateCapture
        candidate.draw()

        let expected = try #require(referenceCapture.summary)
        let actual = try #require(candidateCapture.summary)
        #expect(actual == expected)
    }
}
