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
        bindTextureDefaults: Bool = true,
        @ElementBuilder body: () throws -> some Element
    ) throws -> some Element {
        // Metal 4 API Validation requires every binding a shader uses to be set. These pipeline-level defaults cover
        // the inputs a test is not about; the test's own, inner parameters override them.
        let device = vs.function.device
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        textureDescriptor.usage = .shaderRead
        let texture = try #require(device.makeTexture(descriptor: textureDescriptor))
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.supportArgumentBuffers = true
        let sampler = try #require(device.makeSamplerState(descriptor: samplerDescriptor))
        return try RenderPass {
            if bindTextureDefaults {
                try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                    try body()
                }
                .parameter("transform", functionType: .vertex, value: matrix_identity_float4x4)
                .parameter("color", functionType: .fragment, value: SIMD4<Float>(1, 1, 1, 1))
                .parameter("tex", functionType: .fragment, texture: texture)
                .parameter("smp", functionType: .fragment, samplerState: sampler)
                .vertexDescriptor(vs.inferredVertexDescriptor())
            } else {
                try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                    try body()
                }
                .parameter("transform", functionType: .vertex, value: matrix_identity_float4x4)
                .parameter("color", functionType: .fragment, value: SIMD4<Float>(1, 1, 1, 1))
                .vertexDescriptor(vs.inferredVertexDescriptor())
            }
        }
    }

    // A fragment shader that needs only the SIMD4 color parameter, so this test can exercise
    // SIMD4 binding without also having to bind the texture/sampler that `fragment_main` requires.
    static let colorOnlySource = """
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
        constant float4 &color [[buffer(0)]]
    ) {
        return color;
    }
    """

    @Test("Fragment SIMD4 parameter binds without error", .requiresMetal4)
    func testFragmentSIMD4Parameter() throws {
        let vs = try VertexShader(source: Self.colorOnlySource)
        let fs = try FragmentShader(source: Self.colorOnlySource)
        let pass = try renderPass(vs: vs, fs: fs, bindTextureDefaults: false) {
            Draw { encoder in
                encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
            .parameter("color", functionType: .fragment, value: SIMD4<Float>(1, 0, 0, 1))
            .parameter("transform", functionType: .vertex, value: matrix_identity_float4x4)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("Texture + sampler parameter binding", .requiresMetal4)
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
        // Metal 4 argument tables bind samplers by resource ID.
        samplerDesc.supportArgumentBuffers = true
        let sampler = try #require(device.makeSamplerState(descriptor: samplerDesc))

        let pass = try renderPass(vs: vs, fs: fs) {
            Draw { encoder in
                encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
            .parameter("tex", texture: texture)
            .parameter("smp", samplerState: sampler)
            .parameter("color", value: SIMD4<Float>(1, 1, 1, 1))
            .parameter("transform", value: matrix_identity_float4x4)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    @Test("Buffer parameter binding", .requiresMetal4)
    func testBufferParameter() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let vs = try VertexShader(source: Self.colorOnlySource)
        let fs = try FragmentShader(source: Self.colorOnlySource)
        // transform buffer
        var transform = matrix_identity_float4x4
        let buf = try #require(device.makeBuffer(bytes: &transform, length: MemoryLayout<simd_float4x4>.stride, options: .storageModeShared))

        let pass = try renderPass(vs: vs, fs: fs, bindTextureDefaults: false) {
            Draw { encoder in
                encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
            .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
            .parameter("transform", functionType: .vertex, buffer: buf, offset: 0)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    // MARK: - Rejected bindings
    //
    // On Metal 4 a throw mid-pass unwinds cleanly (every open encoder ends before the recording is discarded), so
    // these go through the element tree rather than an encoder the test owns (compare #357).

    private func renderFails(@ElementBuilder _ draw: () throws -> some Element) throws -> Bool {
        let (vs, fs, _) = try makeBasePass()
        let pass = try renderPass(vs: vs, fs: fs, body: draw)
        do {
            _ = try OffscreenRenderer(size: CGSize(width: 16, height: 16)).render(pass)
            return false
        } catch {
            return true
        }
    }

    private func triangle() -> some Element {
        Draw { encoder in
            encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
        }
        .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
    }

    @Test("An unknown parameter name is reported")
    func testMissingBinding() throws {
        #expect(try renderFails { triangle().parameter("noSuchUniform", value: Float(1)) })
    }

    @Test("Compute-only stages are rejected on a render pipeline")
    func testKernelStageOnRenderEncoder() throws {
        #expect(try renderFails { triangle().parameter("color", functionTypes: .kernel, value: SIMD4<Float>(1, 0, 0, 1)) })
    }

    @Test("Naming several render stages binds each one that has the parameter", .requiresMetal4)
    func testMultipleRenderStages() throws {
        // "color" only exists in the fragment stage; naming both stages binds where it is found and ignores
        // the stage where it is not, rather than failing.
        #expect(try !renderFails { triangle().parameter("color", functionTypes: .render, value: SIMD4<Float>(1, 0, 0, 1)) })
    }

    @Test("Render stages are rejected on a compute pipeline", .requiresMetal4)
    func testRenderStageOnComputeEncoder() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        [[kernel]] void kernel_main(device float *out [[buffer(0)]], constant float &scale [[buffer(1)]], uint tid [[thread_position_in_grid]]) {
            out[tid] = scale;
        }
        """
        let device = try #require(MTLCreateSystemDefaultDevice())
        let kernel = try ComputeKernel(source: source)
        let output = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        func dispatch(scaleStages: FunctionTypes) throws -> some Element {
            try ComputePass {
                try ComputePipeline(computeKernel: kernel) {
                    try ComputeDispatch(threadsPerGrid: MTLSize(width: 4, height: 1, depth: 1))
                        .parameter("out", buffer: output)
                        .parameter("scale", functionTypes: scaleStages, value: Float(3))
                }
            }
        }
        #expect(throws: (any Error).self) {
            try dispatch(scaleStages: .vertex).run()
        }
        // The same parameter is accepted once it names the kernel stage.
        try dispatch(scaleStages: .kernel).run()
        #expect(output.contents().load(as: Float.self) == 3)
    }

    // MARK: - Single-stage convenience overloads

    @Test("Single-stage texture, sampler and array overloads bind", .requiresMetal4)
    func testSingleStageOverloads() throws {
        let (vs, fs, device) = try makeBasePass()

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: textureDescriptor))

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.supportArgumentBuffers = true
        let sampler = try #require(device.makeSamplerState(descriptor: samplerDescriptor))

        let pass = try renderPass(vs: vs, fs: fs) {
            Draw { encoder in
                encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
            .parameter("tex", functionType: .fragment, texture: texture)
            .parameter("smp", functionType: .fragment, samplerState: sampler)
            .parameter("color", functionType: .fragment, values: [SIMD4<Float>(1, 0, 0, 1)])
            .parameter("transform", functionType: .vertex, value: matrix_identity_float4x4)
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(pass)
    }

    // MARK: - Reflection scope (#294)

    @Test("Resolving bindings outside a pipeline explains the scope requirement")
    func testRequireReflectionOutsidePipeline() throws {
        let environment = MSEnvironmentValues()
        #expect(throws: MetalSprocketsError.self) {
            _ = try environment.requireReflection(for: "parameter() modifiers")
        }
        do {
            _ = try environment.requireReflection(for: "parameter() modifiers")
            Issue.record("Expected a throw.")
        }
        catch let error as MetalSprocketsError {
            guard case let .withHint(underlying, hint) = error else {
                Issue.record("Expected a hinted error, got \(error).")
                return
            }
            #expect(String(describing: underlying) == "Missing environment value: reflection")
            #expect(hint.contains("parameter() modifiers"))
            #expect(hint.contains("RenderPipeline"))
        }
    }

    @Test("Reflection published by a pipeline is returned unchanged", .requiresMetal4)
    func testRequireReflectionInsidePipeline() throws {
        // RenderPipeline publishes the reflection of the pipeline it compiled.
        let (vs, fs, _) = try makeBasePass()
        final class Box: @unchecked Sendable { var reflection: Reflection? }
        let box = Box()
        let pass = try renderPass(vs: vs, fs: fs) {
            EmptyElement().onWorkloadEnter { environment in
                box.reflection = try environment.requireReflection(for: "parameter() modifiers")
            }
        }
        _ = try OffscreenRenderer(size: CGSize(width: 16, height: 16)).render(pass)
        let reflection = try #require(box.reflection)
        #expect(reflection.binding(forType: .fragment, name: "color") == 0)
        #expect(reflection.binding(forType: .vertex, name: "transform") == 1)
    }
}
