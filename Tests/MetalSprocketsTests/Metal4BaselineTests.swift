import Darwin
import Foundation
import Metal
@testable import MetalSprockets
import Testing

@Suite("Metal 4 migration baseline")
struct Metal4BaselineTests {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    kernel void baseline_compute(device uint *output [[buffer(0)]], uint index [[thread_position_in_grid]]) {
        output[index] = index * 3 + 7;
    }
    vertex float4 baseline_vertex(uint index [[vertex_id]]) {
        const float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};
        return float4(positions[index], 0, 1);
    }
    fragment float4 baseline_fragment() {
        return float4(1, 0, 0, 1);
    }
    """

    @Test(.enabled(if: ProcessInfo.processInfo.environment["METALSPROCKETS_BASELINE_OUTPUT"] != nil))
    func recordBaseline() throws {
        let outputPath = try #require(ProcessInfo.processInfo.environment["METALSPROCKETS_BASELINE_OUTPUT"])
        let device = try #require(MTLCreateSystemDefaultDevice())
        let shaderStart = CFAbsoluteTimeGetCurrent()
        let kernel = try ComputeKernel(source: Self.source)
        let vertex = try VertexShader(source: Self.source)
        let fragment = try FragmentShader(source: Self.source)
        let shaderLoadingSeconds = CFAbsoluteTimeGetCurrent() - shaderStart
        let elementCount = 65_536
        let buffer = try #require(device.makeBuffer(length: elementCount * MemoryLayout<UInt32>.stride, options: .storageModeShared))
        let compute = try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadgroups: MTLSize(width: elementCount / 256, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
                    .parameter("output", buffer: buffer)
            }
        }
        let computeResult = try measure(compute, device: device)
        let values = buffer.contents().bindMemory(to: UInt32.self, capacity: elementCount)
        for index in 0..<elementCount {
            #expect(values[index] == UInt32(index * 3 + 7))
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 512, height: 512, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget]
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let render = try RenderPass {
            try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
        }
        .renderPassDescriptor(pass)
        let renderResult = try measure(render, device: device)
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&pixel, bytesPerRow: 4, from: MTLRegionMake2D(256, 256, 1, 1), mipmapLevel: 0)
        #expect(pixel == [255, 0, 0, 255])

        let result: [String: Any] = [
            "device": device.name,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "shaderLoadingSeconds": shaderLoadingSeconds,
            "warmupFrames": 200,
            "measuredFrames": 2_000,
            "sustainedFrames": 10_000,
            "computeElementCount": elementCount,
            "renderSize": [512, 512],
            "compute": computeResult,
            "render": renderResult
        ]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(filePath: outputPath), options: .atomic)
    }

    // Ported from the legacy `CommandBufferElement(.none)` + manual commit to the recorded-submission token API, with
    // the same per-frame checks (completed, positive GPU time). Archived legacy measurements are not re-recorded.
    private func measure(_ content: some Element, device: MTLDevice) throws -> [String: Any] {
        let runner = try Runner(device: device)

        func frame() throws -> (System.PhaseTimings, Double) {
            try autoreleasepool {
                let submission = try runner.submit(content)
                let timings = try #require(runner.system.lastPhaseTimings)
                let result = try submission.waitUntilCompleted()
                try runner.context.retireCompletedSubmissions()
                try #require(result.outcome == .completed)
                let gpuSeconds = try #require(result.gpuDuration)
                try #require(gpuSeconds > 0)
                return (timings, gpuSeconds)
            }
        }

        let initial = try frame()
        for _ in 0..<200 {
            _ = try frame()
        }
        var encodingSeconds: [Double] = []
        var cpuFrameSeconds: [Double] = []
        var gpuSeconds: [Double] = []
        // Phase breakdown of the CPU frame; not part of the archived legacy baseline.
        var updateSeconds: [Double] = []
        var setupSeconds: [Double] = []
        encodingSeconds.reserveCapacity(2_000)
        cpuFrameSeconds.reserveCapacity(2_000)
        gpuSeconds.reserveCapacity(2_000)
        for _ in 0..<2_000 {
            let (timings, gpuTime) = try frame()
            encodingSeconds.append(timings.workload)
            cpuFrameSeconds.append(timings.total)
            gpuSeconds.append(gpuTime)
            updateSeconds.append(timings.update)
            setupSeconds.append(timings.setup)
        }
        var memory: [[String: UInt64]] = []
        for frameIndex in 0...10_000 {
            if frameIndex > 0 {
                _ = try frame()
            }
            if frameIndex.isMultiple(of: 1_000) {
                memory.append([
                    "frame": UInt64(frameIndex),
                    "residentBytes": try residentBytes(),
                    "metalAllocatedBytes": UInt64(device.currentAllocatedSize)
                ])
            }
        }
        return [
            "initialSetupSeconds": initial.0.setup,
            "initialCPUFrameSeconds": initial.0.total,
            "encodingSeconds": summary(encodingSeconds),
            "cpuFrameSeconds": summary(cpuFrameSeconds),
            "updateSeconds": summary(updateSeconds),
            "setupSeconds": summary(setupSeconds),
            "gpuSeconds": summary(gpuSeconds),
            "memory": memory
        ]
    }

    private func summary(_ values: [Double]) -> [String: Double] {
        let sorted = values.sorted()
        return [
            "median": sorted[sorted.count / 2],
            "p95": sorted[Int(Double(sorted.count - 1) * 0.95)],
            "min": sorted[0],
            "max": sorted[sorted.count - 1]
        ]
    }

    private func residentBytes() throws -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }
        try #require(result == KERN_SUCCESS)
        return info.resident_size
    }
}
