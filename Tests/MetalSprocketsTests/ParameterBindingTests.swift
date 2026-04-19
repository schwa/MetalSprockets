import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import simd
import Testing

@MainActor
@Suite("Parameter binding (on real reflection)")
struct ParameterBindingTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
    };

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]],
        constant float4x4 &transform [[buffer(1)]]
    ) {
        VertexOut out;
        out.position = transform * float4(in.position, 0.0, 1.0);
        out.uv = (in.position + 1.0) * 0.5;
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant float4 &color [[buffer(0)]],
        texture2d<float> tex [[texture(0)]],
        sampler smp [[sampler(0)]]
    ) {
        return color * tex.sample(smp, in.uv);
    }
    """

    private func makeBasePass() throws -> (vs: VertexShader, fs: FragmentShader, device: MTLDevice) {
        let device = MTLCreateSystemDefaultDevice()!
        let vs = try VertexShader(source: Self.source)
        let fs = try FragmentShader(source: Self.source)
        return (vs, fs, device)
    }

    private func renderPass(
        vs: VertexShader,
        fs: FragmentShader,
        @ElementBuilder body: () throws -> some Element
    ) throws -> some Element {
        try RenderPass {
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                try body()
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
        }
    }

    @Test("Fragment SIMD4 parameter binds without error")
    func testFragmentSIMD4Parameter() throws {
        let (vs, fs, _) = try makeBasePass()
        let pass = try renderPass(vs: vs, fs: fs) {
            Draw { encoder in
                let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .parameter("color", functionType: .fragment, value: SIMD4<Float>(1, 0, 0, 1))
            .parameter("transform", functionType: .vertex, value: simd_float4x4.identity)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("Texture + sampler parameter binding")
    func testTextureSamplerParameters() throws {
        let (vs, fs, device) = try makeBasePass()
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        texDesc.usage = [.shaderRead]
        texDesc.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: texDesc))
        // Fill with white pixels.
        let white = [UInt8](repeating: 255, count: 4 * 4 * 4)
        white.withUnsafeBufferPointer { buf in
            texture.replace(
                region: MTLRegionMake2D(0, 0, 4, 4),
                mipmapLevel: 0,
                withBytes: buf.baseAddress!,
                bytesPerRow: 4 * 4
            )
        }

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        let sampler = try #require(device.makeSamplerState(descriptor: samplerDesc))

        let pass = try renderPass(vs: vs, fs: fs) {
            Draw { encoder in
                let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .parameter("tex", texture: texture)
            .parameter("smp", samplerState: sampler)
            .parameter("color", value: SIMD4<Float>(1, 1, 1, 1))
            .parameter("transform", value: simd_float4x4.identity)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("Buffer parameter binding")
    func testBufferParameter() throws {
        let (vs, fs, device) = try makeBasePass()
        // transform buffer
        var transform = simd_float4x4.identity
        let buf = try #require(device.makeBuffer(bytes: &transform, length: MemoryLayout<simd_float4x4>.stride, options: .storageModeShared))

        let pass = try renderPass(vs: vs, fs: fs) {
            Draw { encoder in
                let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
            .parameter("transform", functionType: .vertex, buffer: buf, offset: 0)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

}
