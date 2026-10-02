// Embedded Metal source in multi-line string literals uses continuation alignment the rule can't account for.
// swiftlint:disable indentation_width
import Darwin
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import MetalSupport
import Testing

/// The #419 exit gate: a Metal 4 element graph traversed by `System` that computes a texture, orders it with a queue
/// barrier, renders from it, and reads the result back, across repeated overlapping submissions.
@MainActor
@Suite("Metal 4 integrated offscreen proof", .requiresMetal4)
struct Metal4IntegratedProofTests {
    private enum InjectedFailure: Error {
        case encoding
    }

    /// Throws from the middle of a render pass, after other commands were encoded.
    private struct ThrowingElement: Element, WorkloadElement {
        typealias Body = Never
        func workloadEnter(_ node: Node) throws { throw InjectedFailure.encoding }
        nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
    }

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    kernel void produce(texture2d<float, access::write> output [[texture(0)]],
                        constant uint &frame [[buffer(0)]],
                        constant uint *padding [[buffer(1)]],
                        constant uint &paddingCount [[buffer(2)]],
                        uint2 position [[thread_position_in_grid]]) {
        uint sum = 0;
        for (uint index = 0; index < paddingCount; index++) { sum += padding[index]; }
        output.write(float4(float(frame % 256) / 255.0, float(sum % 256) / 255.0, 0, 1), position);
    }
    vertex float4 fullscreen(uint id [[vertex_id]]) {
        const float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};
        return float4(positions[id], 0, 1);
    }
    fragment float4 present(float4 position [[position]], texture2d<float, access::read> source [[texture(0)]]) {
        return source.read(uint2(position.xy));
    }
    """

    static let size = 16
    // 3000 words exceed the 4 KiB initial scratch capacity, forcing scratch growth inside every frame.
    static let paddingCount = 3_000

    private struct Frame {
        let intermediate: any MTLTexture
        let target: any MTLTexture
        let pass: MTL4RenderPassDescriptor
    }

    private struct Harness {
        let device: any MTLDevice
        let context: MetalContext
        let compute: PipelineCache.ComputePipeline
        let render: PipelineCache.RenderPipeline
        let frames: [Frame]
    }

    private func makeHarness(submissionTimeout: Duration = .seconds(5)) throws -> Harness {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, submissionTimeout: submissionTimeout)
        let library = try device.makeLibrary(source: Self.source, options: nil)
        let compute = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "produce"))
        let render = try context.pipelines.renderPipeline(RenderPipelineConfiguration(vertex: VertexShader(library: library, name: "fullscreen"), fragment: FragmentShader(library: library, name: "present"), colorPixelFormats: [.bgra8Unorm]))
        // One intermediate/target pair per in-flight frame avoids overlapping writes.
        let frames = try (0..<context.maximumInFlightSubmissions).map { _ in
            let intermediateDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Self.size, height: Self.size, mipmapped: false)
            intermediateDescriptor.usage = [.shaderRead, .shaderWrite]
            intermediateDescriptor.storageMode = .private
            let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Self.size, height: Self.size, mipmapped: false)
            targetDescriptor.usage = [.renderTarget, .shaderRead]
            targetDescriptor.storageMode = .shared
            let target = try #require(device.makeTexture(descriptor: targetDescriptor))
            let pass = MTL4RenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            return Frame(intermediate: try #require(device.makeTexture(descriptor: intermediateDescriptor)), target: target, pass: pass)
        }
        return Harness(device: device, context: context, compute: compute, render: render, frames: frames)
    }

    private func frameContent(_ harness: Harness, frameNumber: Int, injectFailure: Bool = false) throws -> some Element {
        let frame = harness.frames[frameNumber % harness.frames.count]
        var computeParameters = ParameterSet()
        computeParameters.set("output", texture: frame.intermediate)
        computeParameters.set("frame", value: UInt32(frameNumber))
        computeParameters.set("padding", values: [UInt32](repeating: 1, count: Self.paddingCount))
        computeParameters.set("paddingCount", value: UInt32(Self.paddingCount))
        var renderParameters = ParameterSet()
        renderParameters.set("source", texture: frame.intermediate)
        let grid = MTLSize(width: Self.size, height: Self.size, depth: 1)
        return try Group {
            try ComputePass {
                DispatchElement(pipeline: harness.compute, parameters: computeParameters, grid: .threads(grid))
            }
            try RenderPass {
                QueueBarrier(after: .dispatch, before: .fragment)
                DrawElement(pipeline: harness.render, parameters: renderParameters) { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                if injectFailure {
                    ThrowingElement()
                }
            }.renderPassDescriptor(frame.pass)
        }
    }

    // Targets are BGRA so the retained evidence image can be written; red carries the frame number.
    private func expectedPixel(_ frameNumber: Int) -> [UInt8] {
        [0, UInt8(Self.paddingCount % 256), UInt8(frameNumber % 256), 255]
    }

    private func pixels(_ texture: any MTLTexture) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        texture.getBytes(&bytes, bytesPerRow: Self.size * 4, from: MTLRegionMake2D(0, 0, Self.size, Self.size), mipmapLevel: 0)
        return bytes
    }

    private func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        _ = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) }
        }
        return info.resident_size
    }

    /// Runs `frameCount` frames with up to `capacity` in flight, verifying every frame's full image after completion.
    private func runFrames(_ harness: Harness, system: System, frames: Range<Int>, onFrameVerified: (Int) -> Void = { _ in }) async throws {
        var pending: [(frameNumber: Int, submission: Submission)] = []
        func verifyOldest() async throws {
            let (frameNumber, submission) = pending.removeFirst()
            #expect(try await harness.context.awaitResult(submission).outcome == .completed)
            let image = pixels(harness.frames[frameNumber % harness.frames.count].target)
            let expected = expectedPixel(frameNumber)
            #expect(stride(from: 0, to: image.count, by: 4).allSatisfy { Array(image[$0..<$0 + 4]) == expected }, "Frame \(frameNumber) produced stale or wrong pixels")
            onFrameVerified(frameNumber)
        }
        for frameNumber in frames {
            if pending.count == harness.context.maximumInFlightSubmissions {
                try await verifyOldest()
            }
            pending.append((frameNumber, try harness.context.submit(try frameContent(harness, frameNumber: frameNumber), system: system)))
        }
        while !pending.isEmpty {
            try await verifyOldest()
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func computeToRenderReadbackAcrossOverlappingFrames() async throws {
        let harness = try makeHarness()
        let system = System()
        try await runFrames(harness, system: system, frames: 1..<13)
        try await harness.context.drain()
        #expect(harness.context.residentAllocationCount == 0)
        #expect(harness.context.inFlightCount == 0)
        #expect(!harness.context.isFaulted)
        // Retained output evidence for a representative frame.
        try await runFrames(harness, system: system, frames: 200..<201)
        try Golden.verify(try harness.frames[200 % harness.frames.count].target.toCGImage(), named: "Metal4IntegratedProof")
    }

    @Test(.timeLimit(.minutes(1)))
    func encodingFailureMidGraphUnwindsWithoutCommittingThenRecovers() async throws {
        let harness = try makeHarness()
        let system = System()
        try await runFrames(harness, system: system, frames: 1..<3)
        #expect(throws: InjectedFailure.encoding) {
            try harness.context.submit(try frameContent(harness, frameNumber: 3, injectFailure: true), system: system)
        }
        #expect(harness.context.inFlightCount == 0)
        #expect(harness.context.inFlightCount == 0)
        #expect(!harness.context.isFaulted)
        // The same system recovers and produces correct output afterwards.
        try await runFrames(harness, system: system, frames: 4..<8)
        try await harness.context.drain()
        #expect(harness.context.residentAllocationCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func completionTimeoutFaultsWithoutRecyclingStorage() async throws {
        let harness = try makeHarness(submissionTimeout: .milliseconds(50))
        let gate = try #require(harness.device.makeSharedEvent())
        harness.context.waitForEvent(gate, value: 1)
        let submission = try harness.context.submit(try frameContent(harness, frameNumber: 1), system: System())
        #expect(try await harness.context.awaitResult(submission).outcome == .timedOut)
        #expect(harness.context.isFaulted)
        #expect(throws: MetalSprocketsError.self) { try harness.context.submit(try frameContent(harness, frameNumber: 2), system: System()) }
        gate.signaledValue = 1
        await harness.context.completionEvent.valueSignaled(submission.identifier)
        try harness.context.retireCompletedSubmissions()
        #expect(harness.context.inFlightCount == 1)
        #expect(harness.context.residentAllocationCount > 0)
    }

    @Test(.timeLimit(.minutes(3)))
    func sustainedFramesKeepResidencyAndMemoryBounded() async throws {
        let harness = try makeHarness()
        let system = System()
        try await runFrames(harness, system: system, frames: 0..<30)
        let startBytes = residentBytes()
        var peakResident = 0
        try await runFrames(harness, system: system, frames: 30..<330) { _ in
            peakResident = max(peakResident, harness.context.residentAllocationCount)
        }
        try await harness.context.drain()
        let growth = Int64(residentBytes()) - Int64(startBytes)
        // Each in-flight frame holds its textures plus a few scratch buffers; anything near unbounded fails here.
        #expect(peakResident <= harness.context.maximumInFlightSubmissions * 8)
        #expect(harness.context.residentAllocationCount == 0)
        #expect(growth < 16 * 1_024 * 1_024, "Resident memory grew by \(growth) bytes over 300 frames (peak resident allocations \(peakResident))")
    }
}

// Engine-level elements for the integrated proof: they bind pipelines and parameters directly, below the public API.
private struct DispatchElement: Element, WorkloadElement {
    typealias Body = Never
    let pipeline: PipelineCache.ComputePipeline
    let parameters: ParameterSet
    let grid: ComputePassEncoder.Grid
    var threadsPerThreadgroup: MTLSize?

    func workloadEnter(_ node: Node) throws {
        let pass = try node.environmentValues.computePassEncoder.orThrow(.missingEnvironment("computePassEncoder"))
        try pass.dispatch(pipeline, parameters: parameters, grid: grid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

private struct DrawElement: Element, WorkloadElement {
    typealias Body = Never
    let pipeline: PipelineCache.RenderPipeline
    let parameters: ParameterSet
    let encode: (any MTL4RenderCommandEncoder) throws -> Void

    func workloadEnter(_ node: Node) throws {
        let pass = try node.environmentValues.renderPassEncoder.orThrow(.missingEnvironment("renderPassEncoder"))
        try pass.draw(pipeline, parameters: parameters, encode)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}
