import AVFoundation
import Foundation
@testable import MetalSprockets
import os
import simd
import Testing

// A tiny red-triangle scene reused by several tests.
private func makeTriangle(color: SIMD4<Float>) throws -> some Element {
    let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]]
    ) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant float4 &color [[buffer(0)]]
    ) {
        return color;
    }
    """
    let vertexShader = try VertexShader(source: source)
    let fragmentShader = try FragmentShader(source: source)
    return try RenderPass {
        try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
            Draw { encoder in
                let vertices: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
                encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .parameter("color", value: color)
        }
        .vertexDescriptor(vertexShader.inferredVertexDescriptor())
    }
}

/// Build a fresh per-test output URL in the system temp directory.
private func makeTempOutputURL(suffix: String) -> URL {
    let dir = FileManager.default.temporaryDirectory
    let name = "OffscreenVideoRendererTests-\(suffix)-\(UUID().uuidString).mov"
    return dir.appendingPathComponent(name)
}

/// Read back the basic properties of the produced `.mov` for assertions.
private struct RecordedVideoInfo {
    var duration: CMTime
    var videoTrackCount: Int
    var naturalSize: CGSize?
    var formatDescriptionMediaType: CMMediaType?
}

private func inspect(url: URL) async throws -> RecordedVideoInfo {
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration)
    let videoTracks = try await asset.loadTracks(withMediaType: .video)

    var naturalSize: CGSize?
    var mediaType: CMMediaType?
    if let track = videoTracks.first {
        naturalSize = try await track.load(.naturalSize)
        let formatDescriptions = try await track.load(.formatDescriptions)
        if let first = formatDescriptions.first {
            mediaType = CMFormatDescriptionGetMediaType(first)
        }
    }

    return RecordedVideoInfo(
        duration: duration,
        videoTrackCount: videoTracks.count,
        naturalSize: naturalSize,
        formatDescriptionMediaType: mediaType
    )
}

// MARK: - Content verification (#335)

@Test("Renders 30 frames and produces a valid .mov with matching duration and dimensions")
func testVideoRendererProducesValidFile() async throws {
    let outputURL = makeTempOutputURL(suffix: "valid")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    let size = CGSize(width: 640, height: 480)
    let frameRate: Double = 30.0
    let frameCount = 30

    let renderer = try OffscreenVideoRenderer(size: size, frameRate: frameRate, outputURL: outputURL)

    for frame in 0..<frameCount {
        let color: SIMD4<Float> = [Float(frame) / Float(frameCount), 0, 0, 1]
        try await renderer.render(try makeTriangle(color: color))
    }
    try await renderer.finalize()

    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    let info = try await inspect(url: outputURL)
    #expect(info.videoTrackCount == 1)
    #expect(info.formatDescriptionMediaType == kCMMediaType_Video)
    #expect(info.naturalSize == size)

    // Duration should be about frameCount / frameRate seconds. Allow some slack
    // for the encoder's handling of the final frame.
    let expectedSeconds = Double(frameCount) / frameRate
    let actualSeconds = CMTimeGetSeconds(info.duration)
    #expect(
        abs(actualSeconds - expectedSeconds) < 0.2,
        "duration \(actualSeconds)s not within 0.2s of expected \(expectedSeconds)s"
    )
}

@Test("Two sequential renders produce two distinct, valid files")
func testVideoRendererSequentialRuns() async throws {
    let urlA = makeTempOutputURL(suffix: "runA")
    let urlB = makeTempOutputURL(suffix: "runB")
    defer {
        try? FileManager.default.removeItem(at: urlA)
        try? FileManager.default.removeItem(at: urlB)
    }

    for url in [urlA, urlB] {
        let renderer = try OffscreenVideoRenderer(size: CGSize(width: 320, height: 240), outputURL: url)
        for frame in 0..<5 {
            try await renderer.render(try makeTriangle(color: [Float(frame) / 5, 0, 0, 1]))
        }
        try await renderer.finalize()
    }

    #expect(FileManager.default.fileExists(atPath: urlA.path))
    #expect(FileManager.default.fileExists(atPath: urlB.path))

    let infoA = try await inspect(url: urlA)
    let infoB = try await inspect(url: urlB)
    #expect(infoA.videoTrackCount == 1)
    #expect(infoB.videoTrackCount == 1)
    #expect(infoA.naturalSize == CGSize(width: 320, height: 240))
    #expect(infoB.naturalSize == CGSize(width: 320, height: 240))
}

// MARK: - Back-pressure seam (#321 / #336)

/// Verifies that the injected `waitUntilReady` strategy is actually awaited
/// between frames. We count invocations and gate them so the renderer has to
/// suspend on each call; if it weren't awaited the counter would stay at 0.
@Test("Injected waitUntilReady is awaited once per frame")
func testVideoRendererBackPressureSeam() async throws {
    let outputURL = makeTempOutputURL(suffix: "backpressure")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    // A counter bumped every time the seam is called. Lock-guarded because
    // the closure may be invoked from any isolation.
    let counter = OSAllocatedUnfairLock<Int>(initialState: 0)

    let renderer = try OffscreenVideoRenderer(
        size: CGSize(width: 160, height: 120),
        frameRate: 30.0,
        outputURL: outputURL
    ) {
        counter.withLock { $0 += 1 }
        // Yield once so the suspension is observable; don't spin.
        await Task.yield()
    }

    let frameCount = 4
    for frame in 0..<frameCount {
        try await renderer.render(try makeTriangle(color: [Float(frame) / Float(frameCount), 0, 0, 1]))
    }
    try await renderer.finalize()

    let calls = counter.withLock { $0 }
    #expect(calls == frameCount, "waitUntilReady was called \(calls) times, expected \(frameCount)")
}
