// MPSNDArray's MTL4ComputeCommandEncoder encode overload only exists in the SDK 27 Metal
// module (version 382). Older SDKs (e.g. Xcode 26.6 on CI) lack it, so gate the whole file.
#if canImport(Metal, _version: 382)
import Metal
import MetalPerformanceShaders
@testable import MetalSprockets
import Testing

// #451: MPSNDArray kernels encode into an MTL4ComputeCommandEncoder, so they run inside a ComputeCommand.
@MainActor
@Suite(.requiresMetal4)
struct MPSInteropTests {
    @Test
    func ndArrayMatrixMultiplyRunsInsideAComputeCommandAfterAnEarlierDispatch() throws {
        guard #available(macOS 27, iOS 27, tvOS 27, *) else {
            return
        }
        let device = try #require(MTLCreateSystemDefaultDevice())
        let length = MemoryLayout<Float>.stride * 4
        let aBuffer = try #require(device.makeBuffer(length: length, options: .storageModeShared))
        let identity: [Float] = [1, 0, 0, 1]
        let bBuffer = try #require(device.makeBuffer(bytes: identity, length: length, options: .storageModeShared))
        let dBuffer = try #require(device.makeBuffer(length: length, options: .storageModeShared))
        let descriptor = MPSNDArrayDescriptor(dataType: .float32, shape: [2, 2])
        // Otherwise MPS pads rows and the 16-byte buffers are too small.
        descriptor.preferPackedRows = true
        let a = MPSNDArray(buffer: aBuffer, offset: 0, descriptor: descriptor)
        let b = MPSNDArray(buffer: bBuffer, offset: 0, descriptor: descriptor)
        let d = MPSNDArray(buffer: dBuffer, offset: 0, descriptor: descriptor)
        let multiply = MPSNDArrayMatrixMultiplication(device: device, sourceCount: 2)

        // A is written by a kernel in the same pass, so the result is only right if the barrier orders MPS after it.
        let fill = try ComputeKernel(source: """
        #include <metal_stdlib>
        using namespace metal;
        kernel void fill(device float *out [[buffer(0)]], uint tid [[thread_position_in_grid]]) { out[tid] = float(tid + 1); }
        """)
        try ComputePass {
            try ComputePipeline(computeKernel: fill) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 4, height: 1, depth: 1))
                    .parameter("out", buffer: aBuffer)
            }
            EncoderBarrier(after: .dispatch, before: .dispatch)
            ComputeCommand { encoder in
                multiply.encode(withMTL4CommandEncoder: encoder, sourceArrays: [a, b], destinationArray: d)
            }
            .useComputeResources([aBuffer, bBuffer, dBuffer], usage: [.read, .write])
        }
        .run()

        let result = Array(UnsafeBufferPointer(start: dBuffer.contents().bindMemory(to: Float.self, capacity: 4), count: 4))
        #expect(result == [1, 2, 3, 4])
    }
}
#endif
