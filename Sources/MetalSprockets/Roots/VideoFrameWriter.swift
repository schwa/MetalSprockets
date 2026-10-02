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

    private(set) var frameNumber = 0

    init(size: CGSize, frameRate: Double, outputURL: URL, videoCodec: AVVideoCodecType, waitUntilReady: (() async -> Void)?) throws {
        self.size = size
        self.frameRate = frameRate
        self.outputURL = outputURL

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
            throw MetalSprocketsError.configurationError("Asset writer cannot accept the video input for \(outputURL.lastPathComponent)")
        }
        assetWriter.add(assetWriterInput)

        guard assetWriter.startWriting() else {
            throw MetalSprocketsError.configurationError("Asset writer failed to start writing to \(outputURL.lastPathComponent): \(assetWriter.error?.localizedDescription ?? "no error reported")")
        }
        assetWriter.startSession(atSourceTime: .zero)

        if let waitUntilReady {
            self.waitUntilReady = waitUntilReady
        } else {
            let input = assetWriterInput
            self.waitUntilReady = { await Self.defaultWaitUntilReady(input) }
        }
    }

    /// Default production implementation of ``waitUntilReady``: awaits
    /// `AVAssetWriterInput.isReadyForMoreMediaData` via KVO, returning
    /// immediately if the input is already ready. See #321.
    static func defaultWaitUntilReady(_ input: AVAssetWriterInput) async {
        if input.isReadyForMoreMediaData {
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // `observe` returns an `NSKeyValueObservation` we need to hold
            // alive until we've resumed, and invalidate exactly once.
            //
            // With `.initial` the block can run synchronously inside `observe`,
            // before the returned observation has been stored, so the block
            // records that it resumed and the code after `observe` invalidates
            // whatever the block couldn't. Both paths go through `lock`. See #366.
            let lock = OSAllocatedUnfairLock()
            nonisolated(unsafe) var resumed = false
            nonisolated(unsafe) var observation: NSKeyValueObservation?

            let observer = input.observe(\.isReadyForMoreMediaData, options: [.new, .initial]) { observed, _ in
                guard observed.isReadyForMoreMediaData else {
                    return
                }
                let justResumed: Bool = lock.withLockUnchecked {
                    if resumed {
                        return false
                    }
                    resumed = true
                    return true
                }
                guard justResumed else {
                    return
                }
                let toInvalidate: NSKeyValueObservation? = lock.withLockUnchecked {
                    let current = observation
                    observation = nil
                    return current
                }
                toInvalidate?.invalidate()
                continuation.resume()
            }

            let alreadyResumed: Bool = lock.withLockUnchecked {
                if resumed {
                    return true
                }
                observation = observer
                return false
            }
            if alreadyResumed {
                observer.invalidate()
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

        let presentationTime = CMTime(value: CMTimeValue(frameNumber), timescale: CMTimeScale(frameRate))

        await waitUntilReady()

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
