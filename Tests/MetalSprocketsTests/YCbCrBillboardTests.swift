import CoreGraphics
import CoreVideo
import ImageIO
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
@testable import MetalSprocketsUI
import os
import Testing

private final class OwnerProbe {
    let onRelease: () -> Void
    init(onRelease: @escaping () -> Void) { self.onRelease = onRelease }
    deinit { onRelease() }
}

private final class EventLog: Sendable {
    private let events = OSAllocatedUnfairLock<[String]>(initialState: [])
    var values: [String] { events.withLock { $0 } }
    func append(_ event: String) { events.withLock { $0.append(event) } }
}

@MainActor
@Suite("Metal 4 YCbCr billboard", .requiresMetal4)
struct YCbCrBillboardTests {
    private let device = MTLCreateSystemDefaultDevice()!

    private func plane(_ format: MTLPixelFormat, width: Int, height: Int, bytes: [UInt8]) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let bytesPerPixel = format == .r8Unorm ? 1 : 2
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * bytesPerPixel)
        return texture
    }

    private func pixels(_ texture: any MTLTexture) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(&bytes, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        return bytes
    }

    @Test(.timeLimit(.minutes(1)))
    func matchesTheLegacyBillboardOnTheMandrillFixture() async throws {
        let yImage = try loadFixture("mandrill_Y")
        let cbcrImage = try loadFixture("mandrill_CbCr")
        let textureY = try lumaTexture(yImage)
        let textureCbCr = try chromaTexture(cbcrImage)
        let legacy = try OffscreenRenderer(size: CGSize(width: 256, height: 256)).render(try RenderPass { YCbCrBillboardRenderPass(textureY: textureY, textureCbCr: textureCbCr) })
        let candidate = try await TestOffscreenRenderer(size: CGSize(width: 256, height: 256)).render(YCbCrBillboard(textureY: textureY, textureCbCr: textureCbCr))
        let legacyPixels = pixels(legacy.texture)
        let candidatePixels = pixels(candidate.texture)
        let maximumDifference = zip(legacyPixels, candidatePixels).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(maximumDifference <= 1, "Candidate differs from legacy by up to \(maximumDifference)")
        #expect(legacyPixels.contains { $0 > 10 })
    }

    @Test(.timeLimit(.minutes(1)))
    func convertsKnownPlanesWithBT601() async throws {
        // Y = 0.5, Cb = 0.5, Cr = 0.75 -> RGB = (0.8505, 0.3214, 0.5) in the shader's BT.601 matrix.
        let textureY = try plane(.r8Unorm, width: 4, height: 4, bytes: [UInt8](repeating: 128, count: 16))
        let textureCbCr = try plane(.rg8Unorm, width: 2, height: 2, bytes: [128, 191, 128, 191, 128, 191, 128, 191])
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 8, height: 8), pixelFormat: .bgra8Unorm)
        let bytes = pixels(try await renderer.render(YCbCrBillboard(textureY: textureY, textureCbCr: textureCbCr)).texture)
        let center = Array(bytes[(4 * 8 + 4) * 4..<(4 * 8 + 4) * 4 + 4])
        // BGRA order.
        #expect(abs(Int(center[2]) - 217) <= 2)
        #expect(abs(Int(center[1]) - 82) <= 2)
        #expect(abs(Int(center[0]) - 128) <= 2)
        #expect(center[3] == 255)
    }

    /// Camera-style planes: an IOSurface-backed 4:2:0 pixel buffer wrapped through a CVMetalTextureCache.
    private func cameraPlanes(y: UInt8, cb: UInt8, cr: UInt8) throws -> (any MTLTexture, any MTLTexture, [AnyObject]) {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:]]
        CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attributes as CFDictionary, &pixelBuffer)
        let buffer = try #require(pixelBuffer)
        CVPixelBufferLockBaseAddress(buffer, [])
        for (planeIndex, values) in [(0, [y]), (1, [cb, cr])] {
            let base = try #require(CVPixelBufferGetBaseAddressOfPlane(buffer, planeIndex)).assumingMemoryBound(to: UInt8.self)
            let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, planeIndex)
            for row in 0..<CVPixelBufferGetHeightOfPlane(buffer, planeIndex) {
                for column in 0..<CVPixelBufferGetWidthOfPlane(buffer, planeIndex) * values.count {
                    base[row * rowBytes + column] = values[column % values.count]
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        let textureCache = try #require(cache)
        var lumaOwner: CVMetalTexture?
        var chromaOwner: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, buffer, nil, .r8Unorm, 16, 16, 0, &lumaOwner)
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, buffer, nil, .rg8Unorm, 8, 8, 1, &chromaOwner)
        let luma = try #require(lumaOwner)
        let chroma = try #require(chromaOwner)
        return (try #require(CVMetalTextureGetTexture(luma)), try #require(CVMetalTextureGetTexture(chroma)), [luma, chroma, buffer])
    }

    @Test(.timeLimit(.minutes(1)))
    func cameraPlanesFromATextureCacheConvert() async throws {
        let (luma, chroma, owners) = try cameraPlanes(y: 128, cb: 128, cr: 191)
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 8, height: 8), pixelFormat: .bgra8Unorm)
        let bytes = pixels(try await renderer.render(YCbCrBillboard(textureY: luma, textureCbCr: chroma, owners: owners)).texture)
        #expect(abs(Int(bytes[2]) - 217) <= 2)
        #expect(abs(Int(bytes[1]) - 82) <= 2)
        #expect(abs(Int(bytes[0]) - 128) <= 2)
    }

    @Test(.timeLimit(.minutes(1)))
    func ownersLiveUntilEveryOverlappingSubmissionRetires() async throws {
        let context = try MetalContext(device: device)
        let system = System()
        let target = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 8, height: 8, mipmapped: false)
        target.usage = .renderTarget
        target.storageMode = .shared
        var submissions: [Submission] = []
        var outputs: [any MTLTexture] = []
        let events = EventLog()
        for (index, cr) in [UInt8(191), 64].enumerated() {
            // Each frame's owners exist only inside this loop body, like a camera frame that the next one replaces.
            let owner = OwnerProbe { events.append("released \(index)") }
            let (luma, chroma, planeOwners) = try cameraPlanes(y: 128, cb: 128, cr: cr)
            let output = try #require(device.makeTexture(descriptor: target))
            outputs.append(output)
            let pass = MTL4RenderPassDescriptor()
            pass.colorAttachments[0].texture = output
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            let content = try RenderPass {
                YCbCrBillboard(textureY: luma, textureCbCr: chroma, owners: planeOwners + [owner])
            }.renderPassDescriptor(pass)
            let submission = try context.submit(content, system: system)
            submission.onTerminated { _ in events.append("terminated \(index)") }
            submissions.append(submission)
        }
        for submission in submissions {
            #expect(try await context.awaitResult(submission).outcome == .completed)
        }
        try context.retireCompletedSubmissions()
        // The frames must not share state: each shows its own Cr.
        #expect(abs(Int(pixels(outputs[0])[2]) - 217) <= 2)
        #expect(abs(Int(pixels(outputs[1])[2]) - 38) <= 3)
        // The last frame's element is still in the tree; the next frame replaces it and so releases its owners.
        submissions.removeAll()
        _ = try await context.awaitResult(try context.submit(EmptyElement(), system: system))
        try context.retireCompletedSubmissions()
        let log = events.values
        for index in 0..<2 {
            let terminated = try #require(log.firstIndex(of: "terminated \(index)"), "\(log)")
            let released = try #require(log.firstIndex(of: "released \(index)"), "\(log)")
            // Never released while the GPU might still read the planes.
            #expect(terminated < released, "\(log)")
        }
    }

    // MARK: - Fixture loading (same Mandrill planes as YCbCrBillboardRenderPassTests)

    private func loadFixture(_ name: String) throws -> CGImage {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/Mandrill/\(name)", withExtension: "png"))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func lumaTexture(_ image: CGImage) throws -> any MTLTexture {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height)
        let context = try #require(CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return try plane(.r8Unorm, width: image.width, height: image.height, bytes: bytes)
    }

    private func chromaTexture(_ image: CGImage) throws -> any MTLTexture {
        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(data: &rgba, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let rg = (0..<image.width * image.height).flatMap { [rgba[$0 * 4], rgba[$0 * 4 + 1]] }
        return try plane(.rg8Unorm, width: image.width, height: image.height, bytes: rg)
    }
}
