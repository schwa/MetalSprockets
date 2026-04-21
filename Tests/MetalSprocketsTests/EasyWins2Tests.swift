import Metal
@testable import MetalSprockets
@testable import MetalSprocketsSupport
import Testing

/// A grab-bag of tiny tests that pick up 1–3 uncovered lines each in
/// otherwise mostly-covered files.
@Suite("Easy Wins 2")
struct EasyWins2Tests {
    // MARK: ShaderNamespace dynamic member lookups

    static let namespacedSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    namespace NS {
        [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
            VertexOut out;
            out.position = float4(in.position, 0.0, 1.0);
            return out;
        }
        [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) {
            return float4(1.0, 0.0, 0.0, 1.0);
        }
    }
    """

    @Test("ShaderNamespace.vertex_main/fragment_main dynamic member lookups")
    func shaderNamespaceDynamicLookups() throws {
        let library = try ShaderLibrary(source: Self.namespacedSource)
        let ns = library.namespaced("NS")
        let vs: VertexShader = try ns.vertex_main
        let fs: FragmentShader = try ns.fragment_main
        #expect(vs.function.functionType == .vertex)
        #expect(fs.function.functionType == .fragment)
    }

    // MARK: BaseSupport.isPOD

    @Test("isPOD returns true for primitive types and false for classes")
    func isPODValues() {
        #expect(isPOD(Int.self))
        #expect(isPOD(Float.self))
        #expect(isPOD(SIMD4<Float>.self))

        final class Box {}
        #expect(isPOD(Box.self) == false)
    }

    // MARK: ComputePipeline.requiresSetup

    @Test("ComputePipeline.requiresSetup is false when kernel and invalidationKey match")
    func computePipelineRequiresSetup() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void noop(uint tid [[thread_position_in_grid]]) {}
        """
        let kernel = try ComputeKernel(source: kernelSource)
        let a = try ComputePipeline(computeKernel: kernel) { EmptyElement() }
        let b = try ComputePipeline(computeKernel: kernel) { EmptyElement() }
        #expect(a.requiresSetup(comparedTo: b) == false)
    }

    @Test("ComputePipeline.requiresSetup is true when kernel changes")
    func computePipelineRequiresSetupOnKernelChange() throws {
        let sourceA = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void noop(uint tid [[thread_position_in_grid]]) {}
        """
        let sourceB = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void noop2(uint tid [[thread_position_in_grid]]) {}
        """
        let kernelA = try ComputeKernel(source: sourceA)
        let kernelB = try ComputeKernel(source: sourceB)
        let a = try ComputePipeline(computeKernel: kernelA) { EmptyElement() }
        let b = try ComputePipeline(computeKernel: kernelB) { EmptyElement() }
        #expect(a.requiresSetup(comparedTo: b) == true)
    }

    @Test("ComputePipeline.requiresSetup is true when invalidationKey changes")
    func computePipelineRequiresSetupOnInvalidationKeyChange() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void noop(uint tid [[thread_position_in_grid]]) {}
        """
        let kernel = try ComputeKernel(source: kernelSource)
        let a = try ComputePipeline(computeKernel: kernel, invalidationKey: "v1") { EmptyElement() }
        let b = try ComputePipeline(computeKernel: kernel, invalidationKey: "v2") { EmptyElement() }
        #expect(a.requiresSetup(comparedTo: b) == true)

        // And stable when the key matches.
        let c = try ComputePipeline(computeKernel: kernel, invalidationKey: "v1") { EmptyElement() }
        #expect(a.requiresSetup(comparedTo: c) == false)
    }

    // MARK: EnvironmentReader.requiresSetup

    @Test("EnvironmentReader.requiresSetup is always true")
    func environmentReaderRequiresSetup() {
        let a = EnvironmentReader(keyPath: \MSEnvironmentValues.device) { _ in EmptyElement() }
        let b = EnvironmentReader(keyPath: \MSEnvironmentValues.device) { _ in EmptyElement() }
        #expect(a.requiresSetup(comparedTo: b) == true)
    }

    // MARK: RenderPassDescriptorModifier.requiresSetup

    @Test("RenderPassDescriptorModifier.requiresSetup is false")
    func renderPassDescriptorModifierRequiresSetup() {
        let a = RenderPassDescriptorModifier(content: EmptyElement()) { _ in }
        let b = RenderPassDescriptorModifier(content: EmptyElement()) { _ in }
        #expect(a.requiresSetup(comparedTo: b) == false)
    }

    // MARK: Parameter on a ComputePipeline — covers compute-encoder set path

    @Test("Parameter on a ComputePipeline dispatches via the compute encoder")
    func computePipelineParameter() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void multiply_kernel(
            device float *out [[buffer(0)]],
            constant float &scale [[buffer(1)]],
            uint tid [[thread_position_in_grid]]
        ) {
            out[tid] = float(tid) * scale;
        }
        """
        let device = try #require(MTLCreateSystemDefaultDevice())
        let kernel = try ComputeKernel(source: kernelSource)
        let count = 16
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<Float>.stride * count, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        let encoder = node.environmentValues.computeCommandEncoder!
                        encoder.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(
                    threadgroups: MTLSize(width: count / 8, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
                )
                .parameter("scale", value: Float(2.0))
            }
        }
        .run()

        let ptr = buffer.contents().bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            #expect(ptr[i] == Float(i) * 2.0)
        }
    }
}
