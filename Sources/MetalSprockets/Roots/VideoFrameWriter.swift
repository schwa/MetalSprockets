import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Metal
import MetalSprocketsSupport
import os

/// Encodes rendered textures into a movie file. Shared by the legacy and Metal 4 video renderers so back-pressure,
/// timestamps, and finalization have one implementation.
///
/// Callers append only textures whose GPU work has completed.
internal final class VideoFrameWriter {
    let size: CGSize
    let frameRate: Double
    let outputURL: URL
    let assetWriter: AVAssetWriter
    let assetWriterInput: AVAssetWriterInput
    let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor

    /// Awaits until the input can accept another frame. Tests inject a strategy to drive back-pressure. See #321 / #336.
    let waitUntilReady: () async -> Void

    /// The default wait, run after `waitUntilReady` so an injected waiter cannot append to an input that is not ready.
    private let waitForInput: () async -> Void

    private(set) var frameNumber = 0

    init(size: CGSize, frameRate: Double, outputURL: URL, videoCodec: AVVideoCodecType, waitUntilReady: (() async -> Void)?) throws {
        self.size = size
        self.frameRate = frameRate
        self.outputURL = outputURL

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        // Frames are sRGB-encoded BGRA, so the movie is tagged Rec. 709 primaries and matrix with the sRGB transfer
        // function. Untagged movies are shown with a guessed transfer function, which shifts their gamma.
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: videoCodec,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_IEC_sRGB,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
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
            throw MetalSprocketsError.configurationError("Asset writer cannot accept the video input for \(outputURL.lastPathComponent)")
        }
        assetWriter.add(assetWriterInput)

        guard assetWriter.startWriting() else {
            throw MetalSprocketsError.configurationError("Asset writer failed to start writing to \(outputURL.lastPathComponent): \(assetWriter.error?.localizedDescription ?? "no error reported")")
        }
        assetWriter.startSession(atSourceTime: .zero)

        let input = assetWriterInput
        let writer = assetWriter
        waitForInput = { await Self.defaultWaitUntilReady(input, writer: writer) }
        self.waitUntilReady = waitUntilReady ?? waitForInput
    }

    /// Default production implementation of ``waitUntilReady``: awaits
    /// `AVAssetWriterInput.isReadyForMoreMediaData` via KVO, returning
    /// immediately if the input is already ready. It also returns when the writer leaves `.writing` (failed
    /// or cancelled), because the input then never becomes ready. `append` reads the status after this call. See #321, #532.
    static func defaultWaitUntilReady(_ input: AVAssetWriterInput, writer: AVAssetWriter) async {
        func isDone() -> Bool {
            input.isReadyForMoreMediaData || writer.status != .writing
        }
        if isDone() {
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Observations must stay alive until we resume, then be invalidated exactly once.
            //
            // With `.initial` a block can run synchronously inside `observe`, before its observation has been
            // stored, so `resumed` records that and the code after the `observe` calls invalidates whatever
            // the block couldn't. All paths go through `lock`. See #366.
            let lock = OSAllocatedUnfairLock()
            nonisolated(unsafe) var resumed = false
            nonisolated(unsafe) var observations: [NSKeyValueObservation] = []

            nonisolated(unsafe) let handleChange: () -> Void = {
                guard isDone() else {
                    return
                }
                let (justResumed, toInvalidate): (Bool, [NSKeyValueObservation]) = lock.withLockUnchecked {
                    if resumed {
                        return (false, [])
                    }
                    resumed = true
                    let current = observations
                    observations = []
                    return (true, current)
                }
                guard justResumed else {
                    return
                }
                toInvalidate.forEach { $0.invalidate() }
                continuation.resume()
            }

            let observers = [
                input.observe(\.isReadyForMoreMediaData, options: [.new, .initial]) { _, _ in handleChange() },
                writer.observe(\.status, options: [.new, .initial]) { _, _ in handleChange() }
            ]

            let alreadyResumed: Bool = lock.withLockUnchecked {
                if resumed {
                    return true
                }
                observations = observers
                return false
            }
            if alreadyResumed {
                observers.forEach { $0.invalidate() }
            }
        }
    }

    /// Copies a completed texture into a pooled pixel buffer and appends it at the next frame time.
    nonisolated(nonsending) func append(_ texture: any MTLTexture) async throws {
        guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
            throw MetalSprocketsError.resourceCreationFailure("Pixel buffer adaptor has no pixel buffer pool (frame \(frameNumber))")
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create pixel buffer from pool (frame \(frameNumber), CVReturn \(status))")
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw MetalSprocketsError.resourceCreationFailure("Pixel buffer has no base address (frame \(frameNumber))")
        }

        let region = MTLRegionMake2D(0, 0, Int(size.width), Int(size.height))
        texture.getBytes(baseAddress, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), from: region, mipmapLevel: 0)
        // The same color space as the output settings, so the encoder converts nothing.
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_sRGB, .shouldPropagate)
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)

        let presentationTime = CMTime(value: CMTimeValue(frameNumber), timescale: CMTimeScale(frameRate))

        await waitUntilReady()
        // An injected waiter may return before the input is ready, and appending then raises an Objective-C exception
        // (#548). The default wait returns at once when the input is ready.
        await waitForInput()

        if assetWriter.status == .failed || assetWriter.status == .cancelled {
            throw assetWriter.error ?? MetalSprocketsError.validationError("Asset writer stopped (status \(assetWriter.status.rawValue)) before frame \(frameNumber)")
        }
        guard assetWriterInput.isReadyForMoreMediaData else {
            throw MetalSprocketsError.validationError("Asset writer input is not ready for frame \(frameNumber) (status \(assetWriter.status.rawValue))")
        }

        guard pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            throw MetalSprocketsError.validationError("Failed to append pixel buffer for frame \(frameNumber) at \(presentationTime.seconds)s: \(assetWriter.error?.localizedDescription ?? "no error reported")")
        }

        frameNumber += 1
    }

    nonisolated(nonsending) func finalize() async throws {
        assetWriterInput.markAsFinished()

        await withCheckedContinuation { continuation in
            assetWriter.finishWriting {
                continuation.resume()
            }
        }

        if assetWriter.status == .failed {
            throw assetWriter.error ?? MetalSprocketsError.validationError("Asset writer finished in a failed state for \(outputURL.lastPathComponent)")
        }
    }

    /// Abandons the export and removes the partial file.
    func cancel() {
        assetWriter.cancelWriting()
        try? FileManager.default.removeItem(at: outputURL)
    }
}
