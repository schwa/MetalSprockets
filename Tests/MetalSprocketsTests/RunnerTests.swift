import Metal
@testable import MetalSprockets
@testable import MetalSprocketsSupport
import Testing

@Suite("Runner")
struct RunnerTests {
    static let kernelSource = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void add_kernel(
        device float *out [[buffer(0)]],
        constant float &offset [[buffer(1)]],
        uint tid [[thread_position_in_grid]]
    ) {
        out[tid] = float(tid) + offset;
    }
    """

    // Every root takes the same configuration (#483).
    @Test("Roots apply a shared MetalContextConfiguration", .requiresMetal4)
    func rootsApplySharedConfiguration() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeMTL4CommandQueue())
        let configuration = MetalContextConfiguration(device: device, commandQueue: queue, shaderLogging: .disabled, maximumInFlightSubmissions: 1)
        let runner = try Runner(configuration: configuration)
        #expect(runner.commandQueue === queue)
        #expect(runner.maximumInFlightSubmissions == 1)
        #expect(runner.context.logState == nil)
        let renderer = try OffscreenRenderer(size: CGSize(width: 8, height: 8), configuration: configuration)
        #expect(renderer.commandQueue === queue)
    }

    @Test("Runner runs a single element tree", .requiresMetal4)
    func runsSingleElementTree() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 8
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<Float>.stride * count, options: .storageModeShared))

        let runner = try Runner(configuration: MetalContextConfiguration(device: device))

        let element = try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(
                    threadgroups: MTLSize(width: count / 4, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 4, height: 1, depth: 1)
                )
                    .parameter("out", buffer: buffer)
                .parameter("offset", value: Float(10.0))
            }
        }
        try runner.run(element)

        let ptr = buffer.contents().bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            #expect(ptr[i] == Float(i) + 10.0)
        }
    }

    @Test("Runner can run the same element tree repeatedly", .requiresMetal4)
    func runsRepeatedly() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 8
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<Float>.stride * count, options: .storageModeShared))

        let runner = try Runner(configuration: MetalContextConfiguration(device: device))

        let element = try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(
                    threadgroups: MTLSize(width: count / 4, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 4, height: 1, depth: 1)
                )
                    .parameter("out", buffer: buffer)
                .parameter("offset", value: Float(1.0))
            }
        }
        for _ in 0..<5 {
            try runner.run(element)
        }

        let ptr = buffer.contents().bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            #expect(ptr[i] == Float(i) + 1.0)
        }
    }

    @Test("Runner uses the supplied device and command queue", .requiresMetal4)
    func usesSuppliedDeviceAndQueue() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeMTL4CommandQueue())
        let runner = try Runner(configuration: MetalContextConfiguration(device: device, commandQueue: queue))
        #expect(runner.device === device)
        #expect(runner.commandQueue === queue)
    }
}
