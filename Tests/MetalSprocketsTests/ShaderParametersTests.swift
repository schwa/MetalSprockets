import Metal
@testable import MetalSprockets
import Testing

// #480: several parameters bound by one modifier.
@MainActor
@Suite
struct ShaderParametersTests {
    static let kernelSource = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void affine_kernel(
        device uint *out [[buffer(0)]],
        constant uint &scale [[buffer(1)]],
        constant uint *offsets [[buffer(2)]],
        uint tid [[thread_position_in_grid]]
    ) {
        out[tid] = tid * scale + offsets[tid];
    }
    """

    @Test(.requiresMetal4)
    func `one parameters modifier binds several parameters`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 8
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))
        let offsets = (0..<count).map { UInt32($0 * 100) }

        let dispatch = try ComputeDispatch(
            threadgroups: MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: count, height: 1, depth: 1)
        )
        .parameters { parameters in
            parameters.set("out", buffer: buffer)
            parameters.set("scale", value: UInt32(3))
            parameters.set("offsets", values: offsets)
        }
        #expect(dispatch is ParameterModifier<ComputeDispatch>)

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                dispatch
            }
        }
        .run()

        let contents = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for index in 0..<count {
            #expect(contents[index] == UInt32(index * 3 + index * 100))
        }
    }

    @Test(.requiresMetal4)
    func `an inner parameter overrides one from a parameters modifier`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let kernel = try ComputeKernel(source: Self.kernelSource)
        let count = 4
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(
                    threadgroups: MTLSize(width: 1, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: count, height: 1, depth: 1)
                )
                .parameter("scale", value: UInt32(5))
            }
            .parameters { parameters in
                parameters.set("out", buffer: buffer)
                parameters.set("scale", value: UInt32(1))
                parameters.set("offsets", values: [UInt32](repeating: 0, count: count))
            }
        }
        .run()

        let contents = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for index in 0..<count {
            #expect(contents[index] == UInt32(index * 5))
        }
    }
}
