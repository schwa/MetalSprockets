import CoreGraphics
import Foundation
import ImageIO
import Metal
@testable import MetalSprockets
@testable import MetalSprocketsUI
import Testing

@MainActor
@Suite("YCbCrBillboardRenderPass Tests")
struct YCbCrBillboardRenderPassTests {
    // MARK: - Fixture loading

    private func loadPNG(named name: String) throws -> CGImage {
        let url = try #require(
            Bundle.module.url(forResource: "Fixtures/Mandrill/\(name)", withExtension: "png")
        )
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    /// Extracts a single-channel 8-bit image into a Metal texture with r8Unorm format.
    private func makeR8Texture(from cgImage: CGImage, device: MTLDevice) throws -> MTLTexture {
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height)

        // Draw into a grayscale 8bpp context.
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = try #require(CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        desc.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: desc))
        bytes.withUnsafeBufferPointer { buf in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: buf.baseAddress!,
                bytesPerRow: width
            )
        }
        return texture
    }

    /// Extracts Cb (R channel) and Cr (G channel) from an RGB image into a Metal texture
    /// with rg8Unorm format.
    private func makeRG8Texture(from cgImage: CGImage, device: MTLDevice) throws -> MTLTexture {
        let width = cgImage.width
        let height = cgImage.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)

        // Render into RGBA8 first so we can pick channels.
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let context = try #require(CGContext(
            data: &rgba,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Pack R,G into tightly packed RG8.
        var rg = [UInt8](repeating: 0, count: width * height * 2)
        for i in 0..<(width * height) {
            rg[i * 2 + 0] = rgba[i * 4 + 0]  // Cb (R channel)
            rg[i * 2 + 1] = rgba[i * 4 + 1]  // Cr (G channel)
        }

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rg8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        desc.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: desc))
        rg.withUnsafeBufferPointer { buf in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: buf.baseAddress!,
                bytesPerRow: width * 2
            )
        }
        return texture
    }

    // MARK: - Tests

    @Test("YCbCr billboard renders without error")
    func testBasicRender() throws {
        let device = MTLCreateSystemDefaultDevice()!

        let yImage = try loadPNG(named: "mandrill_Y")
        let cbcrImage = try loadPNG(named: "mandrill_CbCr")

        let textureY = try makeR8Texture(from: yImage, device: device)
        let textureCbCr = try makeRG8Texture(from: cbcrImage, device: device)

        let billboard = YCbCrBillboardRenderPass(textureY: textureY, textureCbCr: textureCbCr)
        let pass = try RenderPass { billboard }

        let renderer = try OffscreenRenderer(size: CGSize(width: 256, height: 256))
        let rendering = try renderer.render(pass)
        #expect(rendering.texture.width == 256)
    }

    @Test("YCbCr billboard with custom texture coordinates")
    func testCustomTextureCoordinates() throws {
        let device = MTLCreateSystemDefaultDevice()!

        let yImage = try loadPNG(named: "mandrill_Y")
        let cbcrImage = try loadPNG(named: "mandrill_CbCr")

        let textureY = try makeR8Texture(from: yImage, device: device)
        let textureCbCr = try makeRG8Texture(from: cbcrImage, device: device)

        // Flipped Y coords.
        let coords: [SIMD2<Float>] = [
            [0, 0],
            [1, 0],
            [0, 1],
            [1, 1]
        ]
        let billboard = YCbCrBillboardRenderPass(
            textureY: textureY,
            textureCbCr: textureCbCr,
            textureCoordinates: coords
        )
        let pass = try RenderPass { billboard }

        let renderer = try OffscreenRenderer(size: CGSize(width: 128, height: 128))
        _ = try renderer.render(pass)
    }

    @Test("YCbCr billboard produces non-black output")
    func testProducesNonBlackOutput() throws {
        let device = MTLCreateSystemDefaultDevice()!

        let yImage = try loadPNG(named: "mandrill_Y")
        let cbcrImage = try loadPNG(named: "mandrill_CbCr")

        let textureY = try makeR8Texture(from: yImage, device: device)
        let textureCbCr = try makeRG8Texture(from: cbcrImage, device: device)

        let pass = try RenderPass {
            YCbCrBillboardRenderPass(textureY: textureY, textureCbCr: textureCbCr)
        }

        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        let rendering = try renderer.render(pass)
        let cgImage = try rendering.cgImage

        // Read back a few pixels and confirm something was rendered (non-black).
        let w = cgImage.width
        let h = cgImage.height
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let context = try #require(CGContext(
            data: &rgba,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        let hasColor = rgba.chunked(into: 4).contains { pixel in
            pixel[0] > 10 || pixel[1] > 10 || pixel[2] > 10
        }
        #expect(hasColor, "Rendered image should contain non-black pixels")
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
