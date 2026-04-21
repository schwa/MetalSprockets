import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Metal
import MetalSprocketsSupport
import MetalSupport
import os

public final class OffscreenVideoRenderer {
    public let size: CGSize
    public let frameRate: Double
    public let outputURL: URL
    public let pixelFormat: MTLPixelFormat
    public let videoCodec: AVVideoCodecType
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let assetWriter: AVAssetWriter
    let assetWriterInput: AVAssetWriterInput
    let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    let colorTexture: MTLTexture
    let depthTexture: MTLTexture
    let renderPassDescriptor: MTLRenderPassDescriptor

    /// Test seam: awaits until the sink is ready to accept another frame.
    /// Production uses KVO on `AVAssetWriterInput.isReadyForMoreMediaData`
    /// via ``defaultWaitUntilReady(_:)``; tests can inject a custom strategy
    /// to drive the back-pressure path deterministically. See #321 / #336.
    internal let waitUntilReady: () async -> Void

    var frameNumber: Int = 0
    let frameDuration: CMTime
    let system: System

    public convenience init(size: CGSize, frameRate: Double = 30.0, outputURL: URL, pixelFormat: MTLPixelFormat = .bgra8Unorm, videoCodec: AVVideoCodecType = .h264) throws {
        try self.init(size: size, frameRate: frameRate, outputURL: outputURL, pixelFormat: pixelFormat, videoCodec: videoCodec, waitUntilReady: nil)
    }

    /// Designated init. `waitUntilReady` is the back-pressure strategy; when
    /// `nil`, the default KVO-based implementation is used against the
    /// renderer's own `AVAssetWriterInput`.
    internal init(size: CGSize, frameRate: Double = 30.0, outputURL: URL, pixelFormat: MTLPixelFormat = .bgra8Unorm, videoCodec: AVVideoCodecType = .h264, waitUntilReady: (() async -> Void)?) throws {
        self.size = size
        self.frameRate = frameRate
        self.outputURL = outputURL
        self.pixelFormat = pixelFormat
        self.videoCodec = videoCodec

        device = _MTLCreateSystemDefaultDevice()
        commandQueue = try device._makeCommandQueue()

        let colorTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        colorTextureDescriptor.usage = [.renderTarget, .shaderRead]
        colorTexture = try device.makeTexture(descriptor: colorTextureDescriptor).orThrow(.resourceCreationFailure("Failed to create video color texture"))
        colorTexture.label = "Video Color Texture"

        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        depthTextureDescriptor.usage = [.renderTarget]
        depthTexture = try device.makeTexture(descriptor: depthTextureDescriptor).orThrow(.resourceCreationFailure("Failed to create video depth texture"))
        depthTexture.label = "Video Depth Texture"

        renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = colorTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 1
        renderPassDescriptor.depthAttachment.storeAction = .dontCare

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: videoCodec,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]

        assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        assetWriterInput.expectsMediaDataInRealTime = false

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        guard assetWriter.canAdd(assetWriterInput) else {
            throw MetalSprocketsError.generic("Cannot add input to asset writer")
        }
        assetWriter.add(assetWriterInput)

        guard assetWriter.startWriting() else {
            throw MetalSprocketsError.generic("Failed to start writing")
        }
        assetWriter.startSession(atSourceTime: .zero)

        frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        system = System()

        if let waitUntilReady {
            self.waitUntilReady = waitUntilReady
        } else {
            // Production: KVO-based wait on the renderer's own writer input.
            let input = assetWriterInput
            self.waitUntilReady = { await Self.defaultWaitUntilReady(input) }
        }
    }

    /// Default production implementation of ``waitUntilReady``: awaits
    /// `AVAssetWriterInput.isReadyForMoreMediaData` via KVO, returning
    /// immediately if the input is already ready. Replaces the 10 ms
    /// `Thread.sleep` polling loop that was carried over from the Metal 3
    /// port. See #321.
    internal static func defaultWaitUntilReady(_ input: AVAssetWriterInput) async {
        if input.isReadyForMoreMediaData {
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // `observe` returns an `NSKeyValueObservation` we need to hold
            // alive until we've resumed, and invalidate exactly once.
            nonisolated(unsafe) var observation: NSKeyValueObservation?
            let state = OSAllocatedUnfairLock<Bool>(initialState: false)
            observation = input.observe(\.isReadyForMoreMediaData, options: [.new, .initial]) { observed, _ in
                guard observed.isReadyForMoreMediaData else {
                    return
                }
                let alreadyResumed = state.withLock { resumed -> Bool in
                    if resumed {
                        return true
                    }
                    resumed = true
                    return false
                }
                if alreadyResumed {
                    return
                }
                observation?.invalidate()
                observation = nil
                continuation.resume()
            }
        }
    }

    public func render<Content>(_ element: Content) async throws where Content: Element {
        // Wrap the element with necessary environment values
        let wrappedElement = CommandBufferElement(completion: .commitAndWaitUntilCompleted) {
            element
        }
        .environment(\.device, device)
        .environment(\.commandQueue, commandQueue)
        .environment(\.renderPassDescriptor, renderPassDescriptor)
        .environment(\.drawableSize, size)

        // Update the system with the element (could be same element with mutations or new element)
        try system.update(root: wrappedElement)

        // Process the render
        try system.withCurrentSystem {
            // TODO: #220 Setup should be smart enough to skip elements that are already configured - avoid redundant setup every frame
            try system.processSetup()
            try system.processWorkload()
        }

        // Write the frame to video
        try await appendFrame()
    }

    func appendFrame() async throws {
        guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
            throw MetalSprocketsError.generic("No pixel buffer pool available")
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw MetalSprocketsError.generic("Failed to create pixel buffer")
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)

        guard let baseAddress else {
            throw MetalSprocketsError.generic("Failed to get pixel buffer base address")
        }

        let region = MTLRegionMake2D(0, 0, Int(size.width), Int(size.height))
        colorTexture.getBytes(
            baseAddress,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )

        let presentationTime = CMTime(value: CMTimeValue(frameNumber), timescale: CMTimeScale(frameRate))

        await waitUntilReady()

        guard pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            throw MetalSprocketsError.generic("Failed to append pixel buffer")
        }

        frameNumber += 1
    }

    public func finalize() async throws {
        assetWriterInput.markAsFinished()

        await withCheckedContinuation { continuation in
            assetWriter.finishWriting {
                continuation.resume()
            }
        }

        if assetWriter.status == .failed {
            throw assetWriter.error ?? MetalSprocketsError.generic("Asset writer failed")
        }
    }
}
