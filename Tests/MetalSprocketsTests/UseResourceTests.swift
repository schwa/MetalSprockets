import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("useResource modifier tests")
struct UseResourceTests {
    static let renderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };

    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) {
        return float4(1, 0, 0, 1);
    }
    """

    static let computeSource = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void touch(device uint *out [[buffer(0)]],
                      uint tid [[thread_position_in_grid]]) {
        out[tid] = tid;
    }
    """

    private func renderPassWithDraw(@ElementBuilder decorate: (Draw) -> some Element) throws -> some Element {
        let vs = try VertexShader(source: Self.renderSource)
        let fs = try FragmentShader(source: Self.renderSource)
        let draw = Draw { encoder in
            let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
            encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        return try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                decorate(draw)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
    }

    @Test("useResource with a single buffer")
    func testUseResource() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let buffer = try #require(device.makeBuffer(length: 32, options: .storageModeShared))
        let pass = try renderPassWithDraw { draw in
            draw.useResource(buffer, usage: .read, stages: [.vertex, .fragment])
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("useResource optional: nil is a no-op")
    func testUseResourceOptionalNil() throws {
        let pass = try renderPassWithDraw { draw in
            draw.useResource(nil, usage: .read, stages: .vertex)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("useResource optional: non-nil calls through")
    func testUseResourceOptionalSome() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let buffer: (any MTLResource)? = device.makeBuffer(length: 16, options: .storageModeShared)
        let pass = try renderPassWithDraw { draw in
            draw.useResource(buffer, usage: .read, stages: .fragment)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("useResources with multiple buffers")
    func testUseResources() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let bufs: [any MTLResource] = [
            device.makeBuffer(length: 32, options: .storageModeShared)!,
            device.makeBuffer(length: 32, options: .storageModeShared)!
        ]
        let pass = try renderPassWithDraw { draw in
            draw.useResources(bufs, usage: .read, stages: .vertex)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("useComputeResource binds for compute encoder")
    func testUseComputeResource() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.computeSource)
        let count = 8
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        let side = try #require(device.makeBuffer(length: 64, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        node.environmentValues.computeCommandEncoder!.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(
                    threadgroups: MTLSize(width: 1, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: count, height: 1, depth: 1)
                )
                .useComputeResource(side, usage: .read)
            }
        }
        .run()
    }

    @Test("useComputeResource optional: nil is a no-op")
    func testUseComputeResourceOptionalNil() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.computeSource)
        let count = 4
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        node.environmentValues.computeCommandEncoder!.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(
                    threadgroups: MTLSize(width: 1, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: count, height: 1, depth: 1)
                )
                .useComputeResource(nil, usage: .read)
            }
        }
        .run()
    }

    @Test("useComputeResource optional: non-nil calls through")
    func testUseComputeResourceOptionalSome() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let kernel = try ComputeKernel(source: Self.computeSource)
        let count = 4
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))
        let side: (any MTLResource)? = device.makeBuffer(length: 32, options: .storageModeShared)

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        node.environmentValues.computeCommandEncoder!.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(
                    threadgroups: MTLSize(width: 1, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: count, height: 1, depth: 1)
                )
                .useComputeResource(side, usage: .read)
            }
        }
        .run()
    }

    @Test("missingEnvironment(keyPath) helper")
    func testMissingEnvironmentKeyPath() {
        let err = MetalSprocketsError.missingEnvironment(\MSEnvironmentValues.device)
        #expect("\(err)".contains("device"))
    }
}
