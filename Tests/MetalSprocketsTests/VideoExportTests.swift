import AVFoundation
import Darwin
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import os
import Testing

@MainActor
@Suite("Metal 4 video export", .requiresMetal4)
struct VideoExportTests {
    private enum InjectedFailure: Error {
        case encoding
    }

    private struct Throwing: Element, WorkloadElement {
        typealias Body = Never
        func workloadEnter(_ node: Node) throws { throw InjectedFailure.encoding }
        nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
    }

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    vertex float4 fullscreen(uint id [[vertex_id]]) {
        const float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};
        return float4(positions[id], 0, 1);
    }
    fragment float4 solid(constant float4 &color [[buffer(0)]]) { return color; }
    """

    private struct Scene {
        let vertex: VertexShader
        let fragment: FragmentShader

        // Frame k is pure red, green, or blue, so decoded frames identify their index despite lossy encoding.
        static func color(frame: Int) -> SIMD4<Float> {
            let channel = frame % 3
            return [channel == 0 ? 1 : 0, channel == 1 ? 1 : 0, channel == 2 ? 1 : 0, 1]
        }

        func content(frame: Int, failing: Bool = false) throws -> some Element {
            try RenderPass {
                try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                        .parameter("color", value: Self.color(frame: frame))
                    if failing {
                        Throwing()
                    }
                }
            }
        }
    }

    private func scene() throws -> Scene {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(source: Self.source, options: nil)
        return Scene(vertex: try VertexShader(library: library, name: "fullscreen"), fragment: try FragmentShader(library: library, name: "solid"))
    }

    private func outputURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("VideoExportTests-\(name)-\(UUID().uuidString).mov")
    }

    /// Decodes the exact frame at `index` and returns the index of its dominant RGB channel.
    private func dominantChannel(_ url: URL, frame index: Int, frameRate: Double) async throws -> Int {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(frameRate))
        let (image, actualTime) = try await generator.image(at: time)
        #expect(actualTime == time, "Decoded frame \(index) at \(actualTime.seconds)s instead of \(time.seconds)s")
        let context = try #require(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let channels = [data[0], data[1], data[2]]
        return try #require(channels.indices.max { channels[$0] < channels[$1] })
    }

    @Test(.timeLimit(.minutes(2)))
    func exportsOrderedTimestampedFramesWithCorrectContent() async throws {
        let scene = try scene()
        let url = outputURL("ordered")
        defer { try? FileManager.default.removeItem(at: url) }
        let frameRate = 30.0
        let frameCount = 12
        let renderer = try OffscreenVideoRenderer(size: CGSize(width: 64, height: 48), frameRate: frameRate, outputURL: url)
        for frame in 0..<frameCount {
            try await renderer.render(try scene.content(frame: frame))
        }
        try await renderer.finalize()
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await track.load(.naturalSize) == CGSize(width: 64, height: 48))
        #expect(abs(try await asset.load(.duration).seconds - Double(frameCount) / frameRate) < 0.1)
        for frame in 0..<frameCount {
            #expect(try await dominantChannel(url, frame: frame, frameRate: frameRate) == frame % 3, "Decoded frame \(frame) has the wrong content")
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func backPressureIsAwaitedOncePerFrame() async throws {
        let scene = try scene()
        let url = outputURL("backpressure")
        defer { try? FileManager.default.removeItem(at: url) }
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let renderer = try OffscreenVideoRenderer(size: CGSize(width: 32, height: 32), frameRate: 30, outputURL: url) {
            calls.withLock { $0 += 1 }
            await Task.yield()
        }
        for frame in 0..<5 {
            try await renderer.render(try scene.content(frame: frame))
        }
        try await renderer.finalize()
        #expect(calls.withLock { $0 } == 5)
    }

    @Test(.timeLimit(.minutes(1)))
    func encodingFailureAppendsNothingAndLaterFramesContinueInOrder() async throws {
        let scene = try scene()
        let url = outputURL("failure")
        defer { try? FileManager.default.removeItem(at: url) }
        let renderer = try OffscreenVideoRenderer(size: CGSize(width: 32, height: 32), frameRate: 30, outputURL: url)
        try await renderer.render(try scene.content(frame: 0))
        await #expect(throws: InjectedFailure.encoding) { try await renderer.render(try scene.content(frame: 1, failing: true)) }
        #expect(renderer.writtenFrameCount == 1)
        try await renderer.render(try scene.content(frame: 1))
        try await renderer.finalize()
        #expect(try await dominantChannel(url, frame: 0, frameRate: 30) == 0)
        #expect(try await dominantChannel(url, frame: 1, frameRate: 30) == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellationRemovesThePartialFile() async throws {
        let scene = try scene()
        let url = outputURL("cancel")
        let renderer = try OffscreenVideoRenderer(size: CGSize(width: 32, height: 32), frameRate: 30, outputURL: url)
        try await renderer.render(try scene.content(frame: 0))
        renderer.cancel()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        await #expect(throws: (any Error).self) { try await renderer.render(try scene.content(frame: 1)) }
    }

    @Test(.timeLimit(.minutes(3)))
    func sustainedExportKeepsMemoryAndResidencyBounded() async throws {
        let scene = try scene()
        let url = outputURL("sustained")
        defer { try? FileManager.default.removeItem(at: url) }
        let renderer = try OffscreenVideoRenderer(size: CGSize(width: 128, height: 96), frameRate: 60, outputURL: url)
        for frame in 0..<30 {
            try await renderer.render(try scene.content(frame: frame))
        }
        let start = residentBytes()
        for frame in 30..<330 {
            try await renderer.render(try scene.content(frame: frame))
            #expect(renderer.residentAllocationCount == 0)
        }
        try await renderer.finalize()
        let growth = Int64(residentBytes()) - Int64(start)
        #expect(growth < 32 * 1_024 * 1_024, "Resident memory grew by \(growth) bytes over 300 exported frames")
        #expect(renderer.writtenFrameCount == 330)
    }

    private func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        _ = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) }
        }
        return info.resident_size
    }
}
