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

    // MARK: - Rejected bindings
    //
    // These drive Parameter.set(on:reflection:) against an encoder the test owns. Going through the element tree
    // instead would abort the process: a throw mid-pass skips the pass's workloadExit, the encoder is released
    // without endEncoding, and Metal asserts. See #357.

    /// A render command encoder plus the reflection of a pipeline built from the test shaders.
    private func withRenderEncoder(_ body: (MTLRenderCommandEncoder, Reflection) throws -> Void) throws {
        let (vs, fs, device) = try makeBasePass()

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 16, height: 16, mipmapped: false)
        textureDescriptor.usage = [.renderTarget]
        textureDescriptor.storageMode = .private
        let texture = try #require(device.makeTexture(descriptor: textureDescriptor))

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vs.function
        pipelineDescriptor.fragmentFunction = fs.function
        pipelineDescriptor.vertexDescriptor = try vs.inferredVertexDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = texture.pixelFormat
        let (_, rawReflection) = try device.makeRenderPipelineState(descriptor: pipelineDescriptor, options: .bindingInfo)
        let reflection = Reflection(try #require(rawReflection))

        let commandQueue = try #require(device.makeCommandQueue())
        let commandBuffer = try #require(commandQueue.makeCommandBuffer())
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        let encoder = try #require(commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor))
        defer {
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        try body(encoder, reflection)
    }

    @Test("An unknown parameter name is reported")
    func testMissingBinding() throws {
        try withRenderEncoder { encoder, reflection in
            let parameter = Parameter(name: "noSuchUniform", value: ParameterValue<Float>.value(1))
            #expect(throws: MetalSprocketsError.self) {
                try parameter.set(on: encoder, reflection: reflection)
            }
        }
    }

    @Test("Compute-only stages are rejected on a render encoder")
    func testKernelStageOnRenderEncoder() throws {
        try withRenderEncoder { encoder, reflection in
            let parameter = Parameter(name: "color", functionTypes: .kernel, value: ParameterValue<SIMD4<Float>>.value([1, 0, 0, 1]))
            #expect(throws: MetalSprocketsError.self) {
                try parameter.set(on: encoder, reflection: reflection)
            }
        }
    }

    @Test("Naming several render stages binds each one that has the parameter")
    func testMultipleRenderStages() throws {
        try withRenderEncoder { encoder, reflection in
            // "color" only exists in the fragment stage; naming both stages binds where it is found and ignores
            // the stage where it is not, rather than failing.
            let parameter = Parameter(name: "color", functionTypes: .render, value: ParameterValue<SIMD4<Float>>.value([1, 0, 0, 1]))
            try parameter.set(on: encoder, reflection: reflection)
        }
    }

    @Test("Render stages are rejected on a compute encoder")
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
        let pipelineDescriptor = MTLComputePipelineDescriptor()
        pipelineDescriptor.computeFunction = kernel.function
        let (_, rawReflection) = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: .bindingInfo)
        let reflection = Reflection(try #require(rawReflection))

        let commandQueue = try #require(device.makeCommandQueue())
        let commandBuffer = try #require(commandQueue.makeCommandBuffer())
        let encoder = try #require(commandBuffer.makeComputeCommandEncoder())
        defer {
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        let parameter = Parameter(name: "scale", functionTypes: .vertex, value: ParameterValue<Float>.value(1))
        #expect(throws: MetalSprocketsError.self) {
            try parameter.set(on: encoder, reflection: reflection)
        }

        // The same parameter is accepted once it names the kernel stage.
        let kernelParameter = Parameter(name: "scale", functionTypes: .kernel, value: ParameterValue<Float>.value(1))
        try kernelParameter.set(on: encoder, reflection: reflection)
    }

    // MARK: - Single-stage convenience overloads

    @Test("Single-stage texture, sampler and array overloads bind")
    func testSingleStageOverloads() throws {
        let (vs, fs, device) = try makeBasePass()

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: textureDescriptor))

        let samplerDescriptor = MTLSamplerDescriptor()
        let sampler = try #require(device.makeSamplerState(descriptor: samplerDescriptor))

        let pass = try renderPass(vs: vs, fs: fs) {
            Draw { encoder in
                let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .parameter("tex", functionType: .fragment, texture: texture)
            .parameter("smp", functionType: .fragment, samplerState: sampler)
            .parameter("color", functionType: .fragment, values: [SIMD4<Float>(1, 0, 0, 1)])
            .parameter("transform", functionType: .vertex, value: simd_float4x4.identity)
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

    @Test("Reflection published by a pipeline is returned unchanged")
    func testRequireReflectionInsidePipeline() throws {
        try withRenderEncoder { _, reflection in
            var environment = MSEnvironmentValues()
            environment.reflection = reflection
            let resolved = try environment.requireReflection(for: "parameter() modifiers")
            #expect(resolved.binding(forType: .fragment, name: "color") == reflection.binding(forType: .fragment, name: "color"))
        }
    }
}
