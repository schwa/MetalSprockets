import CoreGraphics
import GoldenImage
import Metal
import MetalKit
@testable import MetalSprockets
import Testing

/// Reproduces the legacy golden scenes on the Metal 4 candidate and compares against the same, unchanged references.
@MainActor
@Suite("Metal 4 render-state parity", .requiresMetal4)
struct RenderStateTests {
    // Same shader as GoldenRenderingTests.
    private static let quadSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]], constant float &depth [[buffer(1)]]) {
        VertexOut out;
        out.position = float4(in.position, depth, 1.0);
        return out;
    }
    [[fragment]] float4 fragment_main(constant float4 &color [[buffer(0)]]) { return color; }
    """

    // Same shader as GoldenPipelineTests.
    private static let tintSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };
    constant bool useWarmTint [[function_constant(0)]];
    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }
    [[fragment]] float4 fragment_main() { return useWarmTint ? float4(1, 0.5, 0, 1) : float4(0, 0.5, 1, 1); }
    """

    // Same shader as the blend and MSAA tests.
    private static let colorSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }
    [[fragment]] float4 fragment_main(constant float4 &color [[buffer(0)]]) { return color; }
    """

    private static let leftQuad: [SIMD2<Float>] = [[-0.8, 0.6], [-0.8, -0.6], [0.2, 0.6], [0.2, -0.6]]
    private static let rightQuad: [SIMD2<Float>] = [[-0.2, 0.6], [-0.2, -0.6], [0.8, 0.6], [0.8, -0.6]]

    private struct Shaders {
        let vertex: VertexShader
        let fragment: FragmentShader
    }

    private func shaders(_ source: String, constants: FunctionConstants = FunctionConstants()) throws -> Shaders {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(source: source, options: nil)
        return Shaders(vertex: try VertexShader(library: library, name: "vertex_main", constants: constants), fragment: try FragmentShader(library: library, name: "fragment_main", constants: constants))
    }

    private func vertexBuffer(_ vertices: [SIMD2<Float>]) throws -> any MTLBuffer {
        let device = try #require(MTLCreateSystemDefaultDevice())
        return try #require(device.makeBuffer(bytes: vertices, length: MemoryLayout<SIMD2<Float>>.stride * vertices.count, options: .storageModeShared))
    }

    private struct Quad {
        let buffer: any MTLBuffer
        let color: SIMD4<Float>
        let depth: Float
        var bias: Float?
        var compare: MTLCompareFunction = .less
    }

    private func quadScene(_ shaders: Shaders, _ quads: [Quad]) throws -> some Element {
        try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
            ForEach(Array(quads.enumerated()), id: \.offset) { _, quad in
                let draw = Draw { $0.drawPrimitives(primitiveType: .triangleStrip, vertexStart: 0, vertexCount: 4) }
                    .vertexBuffer(quad.buffer, index: 0)
                    .parameter("color", functionTypes: .fragment, value: quad.color)
                    .parameter("depth", functionTypes: .vertex, value: quad.depth)
                    .depthCompare(function: quad.compare, enabled: true)
                if let bias = quad.bias {
                    draw.depthBias(bias)
                } else {
                    draw
                }
            }
        }.vertexDescriptor(shaders.vertex.inferredVertexDescriptor())
    }

    private func render(_ content: some Element, size: CGSize = CGSize(width: 256, height: 256), renderer: TestOffscreenRenderer? = nil) async throws -> CGImage {
        let renderer = try renderer ?? TestOffscreenRenderer(size: size)
        return try await renderer.render(content).cgImage
    }

    @Test(.timeLimit(.minutes(1)))
    func depthOcclusionMatchesLegacyGoldensInEitherDrawOrder() async throws {
        let shaders = try shaders(Self.quadSource)
        let red = Quad(buffer: try vertexBuffer(Self.leftQuad), color: [1, 0, 0, 1], depth: 0.8)
        let green = Quad(buffer: try vertexBuffer(Self.rightQuad), color: [0, 1, 0, 1], depth: 0.2)
        try Golden.verify(try await render(quadScene(shaders, [red, green])), named: "DepthNearOccludesFar")
        try Golden.verify(try await render(quadScene(shaders, [green, red])), named: "DepthNearOccludesFar")
    }

    @Test(.timeLimit(.minutes(1)))
    func depthBiasAndCoplanarCasesMatchLegacyGoldens() async throws {
        let shaders = try shaders(Self.quadSource)
        let left = try vertexBuffer(Self.leftQuad)
        let right = try vertexBuffer(Self.rightQuad)
        let red = Quad(buffer: left, color: [1, 0, 0, 1], depth: 0.5)
        try Golden.verify(try await render(quadScene(shaders, [red, Quad(buffer: right, color: [0, 1, 0, 1], depth: 0.5, bias: -0.001)])), named: "DepthBiasWinsCoplanar")
        try Golden.verify(try await render(quadScene(shaders, [red, Quad(buffer: right, color: [0, 1, 0, 1], depth: 0.5)])), named: "CoplanarNoBias")
    }

    @Test(.timeLimit(.minutes(1)))
    func changingTheDepthCompareBetweenFramesTakesEffect() async throws {
        let shaders = try shaders(Self.quadSource)
        let left = try vertexBuffer(Self.leftQuad)
        let right = try vertexBuffer(Self.rightQuad)
        func scene(_ compare: MTLCompareFunction) throws -> some Element {
            try quadScene(shaders, [Quad(buffer: left, color: [1, 0, 0, 1], depth: 0.5, compare: compare), Quad(buffer: right, color: [0, 1, 0, 1], depth: 0.5, compare: compare)])
        }
        // One renderer, so both frames reuse the same System nodes and only the compare function changes.
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 256, height: 256))
        try Golden.verify(try await render(scene(.less), renderer: renderer), named: "CoplanarNoBias")
        try Golden.verify(try await render(scene(.always), renderer: renderer), named: "CoplanarDepthAlways")
        try Golden.verify(try await render(scene(.less), renderer: renderer), named: "CoplanarNoBias")
    }

    @Test(.timeLimit(.minutes(1)))
    func parameterColourAndFunctionConstantsMatchLegacyGoldens() async throws {
        let shaders = try shaders(Self.quadSource)
        try Golden.verify(try await render(quadScene(shaders, [Quad(buffer: try vertexBuffer(Self.leftQuad), color: [0, 0.25, 1, 1], depth: 0.5)])), named: "ParameterColour")
        let triangle = try vertexBuffer([[-0.9, -0.8], [0.9, -0.8], [0.9, 0.8]])
        for (warm, name) in [(false, "AliasedDiagonal"), (true, "WarmTintDiagonal")] {
            var constants = FunctionConstants()
            constants["useWarmTint"] = .bool(warm)
            let tint = try self.shaders(Self.tintSource, constants: constants)
            let scene = try RenderPipeline(vertexShader: tint.vertex, fragmentShader: tint.fragment) {
                Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                    .vertexBuffer(triangle, index: 0)
            }.vertexDescriptor(tint.vertex.inferredVertexDescriptor())
            try Golden.verify(try await render(scene), named: name)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func blendingMatchesTheLegacyBlendGoldens() async throws {
        let shaders = try shaders(Self.colorSource)
        let first = try vertexBuffer([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]])
        let second = try vertexBuffer([[0, -0.5], [-0.5, 0.5], [0.5, 0.5]])
        let directory = try #require(Bundle.module.resourceURL?.appendingPathComponent("Golden Images"))
        // The legacy blend tests compare without edge tolerance; keep the same comparison.
        let comparison = GoldenImageComparison(imageDirectory: directory, options: .none)
        for (isBlendingEnabled, name) in [(false, "NoAlphaBlend"), (true, "WithAlphaBlend")] {
            let scene = try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
                Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                    .vertexBuffer(first, index: 0)
                    .parameter("color", value: SIMD4<Float>(1, 0, 0, 0.5))
                Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                    .vertexBuffer(second, index: 0)
                    .parameter("color", value: SIMD4<Float>(0, 0, 1, 0.5))
            }
            .vertexDescriptor(shaders.vertex.inferredVertexDescriptor())
            .renderPipelineDescriptorTransformer { descriptor in
                guard isBlendingEnabled, let attachment = descriptor.colorAttachments[0] else {
                    return
                }
                attachment.blendingState = .enabled
                attachment.sourceRGBBlendFactor = .sourceAlpha
                attachment.sourceAlphaBlendFactor = .sourceAlpha
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            let image = try await render(scene, size: CGSize(width: 512, height: 512))
            #expect(try comparison.image(image: image, matchesGoldenImageNamed: name), "Blend state \(name) differs from the legacy reference")
        }
    }

    private func msaaPixels(scale: Float, renderer: TestOffscreenRenderer, shaders: Shaders) async throws -> [UInt8] {
        let triangle = try vertexBuffer([[0, 0.9 * scale], [-0.9 * scale, -0.9 * scale], [0.9 * scale, -0.5 * scale]])
        let scene = try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                .vertexBuffer(triangle, index: 0)
                .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
        }.vertexDescriptor(shaders.vertex.inferredVertexDescriptor())
        let image = try await render(scene, renderer: renderer)
        return [UInt8](try #require(image.dataProvider?.data) as Data)
    }

    private func partialCoverage(_ pixels: [UInt8]) -> Int {
        stride(from: 0, to: pixels.count, by: 4).count { pixels[$0 + 2] > 8 && pixels[$0 + 2] < 240 }
    }

    @Test(.timeLimit(.minutes(1)))
    func multisampleResolveAntiAliasesAndKeepsWorkingAfterTheFirstFrame() async throws {
        let shaders = try shaders(Self.colorSource)
        let aliased = try await msaaPixels(scale: 1, renderer: TestOffscreenRenderer(size: CGSize(width: 256, height: 256)), shaders: shaders)
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 256, height: 256), sampleCount: 4)
        let first = try await msaaPixels(scale: 1, renderer: renderer, shaders: shaders)
        let second = try await msaaPixels(scale: 0.4, renderer: renderer, shaders: shaders)
        #expect(partialCoverage(first) > partialCoverage(aliased) * 10)
        #expect(first != second)
        #expect(partialCoverage(second) > 0)
        #expect(throws: (any Error).self) { try TestOffscreenRenderer(size: CGSize(width: 8, height: 8), sampleCount: 3) }
    }

    @Test(.timeLimit(.minutes(1)))
    func viewportAndScissorApplyPerDrawAndDoNotLeakToSiblings() async throws {
        let shaders = try shaders(Self.colorSource)
        let fullscreen = try vertexBuffer([[-1, -1], [3, -1], [-1, 3]])
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm)
        let scene = try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
            // Scissored to the left half.
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                .vertexBuffer(fullscreen, index: 0)
                .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
                .scissor(MTLScissorRect(x: 0, y: 0, width: 32, height: 64))
            // Viewport to the top-right quadrant; must not inherit the sibling's scissor.
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                .vertexBuffer(fullscreen, index: 0)
                .parameter("color", value: SIMD4<Float>(0, 0, 1, 1))
                .viewport(MTLViewport(originX: 32, originY: 0, width: 32, height: 32, znear: 0, zfar: 1))
        }.vertexDescriptor(shaders.vertex.inferredVertexDescriptor())
        let texture = try await renderer.render(scene).texture
        func pixel(_ x: Int, _ y: Int) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 4)
            texture.getBytes(&bytes, bytesPerRow: 64 * 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
            return bytes
        }
        #expect(pixel(8, 48) == [0, 0, 255, 255])
        #expect(pixel(48, 8) == [255, 0, 0, 255])
        #expect(pixel(48, 48) == [0, 0, 0, 255])
    }

    // #455: rasterizer state set inside one Draw closure must not reach later siblings.
    @Test(.timeLimit(.minutes(1)), arguments: [MTLCullMode.front, .back])
    func cullAndFillModeDoNotLeakToSiblings(cullMode: MTLCullMode) async throws {
        let shaders = try shaders(Self.colorSource)
        let fullscreen = try vertexBuffer([[-1, -1], [3, -1], [-1, 3]])
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm)
        let scene = try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
            Draw { encoder in
                encoder.setTriangleFillMode(.lines)
                encoder.setCullMode(cullMode)
                encoder.setFrontFacing(.counterClockwise)
            }
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                .vertexBuffer(fullscreen, index: 0)
                .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
        }.vertexDescriptor(shaders.vertex.inferredVertexDescriptor())
        let texture = try await renderer.render(scene).texture
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&bytes, bytesPerRow: 64 * 4, from: MTLRegionMake2D(32, 32, 1, 1), mipmapLevel: 0)
        #expect(bytes == [0, 0, 255, 255])
    }

    private func centerPixel(_ texture: any MTLTexture) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&bytes, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(texture.width / 2, texture.height / 2, 1, 1), mipmapLevel: 0)
        return bytes
    }

    // #453: indexed draws from an MTLBuffer, including validation of the index range.
    @Test(.timeLimit(.minutes(1)))
    func indexedDrawFromAnIndexBuffer() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let shaders = try shaders(Self.colorSource)
        let vertices = try vertexBuffer([[-1, -1], [1, -1], [-1, 1], [1, 1]])
        // Two junk indices first, so the draw only works if the offset is honoured.
        let indices: [UInt16] = [9, 9, 0, 1, 2, 2, 1, 3]
        let indexBuffer = try #require(device.makeBuffer(bytes: indices, length: indices.count * 2, options: .storageModeShared))
        func scene(indexCount: Int) throws -> some Element {
            try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
                Draw(primitiveType: .triangle, indexBuffer: indexBuffer, indexType: .uint16, indexCount: indexCount, indexBufferOffset: 4)
                    .vertexBuffer(vertices, index: 0)
                    .parameter("color", value: SIMD4<Float>(0, 1, 0, 1))
            }.vertexDescriptor(shaders.vertex.inferredVertexDescriptor())
        }
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm)
        #expect(centerPixel(try await renderer.render(scene(indexCount: 6)).texture) == [0, 255, 0, 255])
        await #expect(throws: (any Error).self) {
            _ = try await TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm).render(scene(indexCount: 7))
        }
    }

    // #453: Draw(mesh:) with .vertexBuffers(of:) renders an MTKMesh.
    @Test(.timeLimit(.minutes(1)))
    func meshDrawRendersAnMTKMesh() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct VertexIn { float3 position [[attribute(0)]]; };
        struct VertexOut { float4 position [[position]]; };
        [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
            VertexOut out;
            out.position = float4(in.position.xy, 0.5, 1.0);
            return out;
        }
        [[fragment]] float4 fragment_main() { return float4(1, 0, 1, 1); }
        """
        let shaders = try shaders(source)
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].format = .float3
        descriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        let modelDescriptor = MTKModelIOVertexDescriptorFromMetal(descriptor)
        (modelDescriptor.attributes[0] as? MDLVertexAttribute)?.name = MDLVertexAttributePosition
        let plane = MDLMesh(planeWithExtent: [2, 2, 0], segments: [1, 1], geometryType: .triangles, allocator: MTKMeshBufferAllocator(device: device))
        plane.vertexDescriptor = modelDescriptor
        let mesh = try MTKMesh(mesh: plane, device: device)
        let scene = try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
            Draw(mesh: mesh)
                .vertexBuffers(of: mesh)
        }.vertexDescriptor(descriptor)
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm)
        #expect(centerPixel(try await renderer.render(scene).texture) == [255, 0, 255, 255])
    }

    @Test(.timeLimit(.minutes(1)))
    func stencilWritesThenMasksLaterDraws() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let shaders = try shaders(Self.colorSource)
        let fullscreen = try vertexBuffer([[-1, -1], [3, -1], [-1, 3]])
        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 64, height: 64, mipmapped: false)
        colorDescriptor.usage = .renderTarget
        let color = try #require(device.makeTexture(descriptor: colorDescriptor))
        let depthStencilDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float_stencil8, width: 64, height: 64, mipmapped: false)
        depthStencilDescriptor.usage = .renderTarget
        depthStencilDescriptor.storageMode = .private
        let depthStencil = try #require(device.makeTexture(descriptor: depthStencilDescriptor))
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = color
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = depthStencil
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.stencilAttachment.texture = depthStencil
        pass.stencilAttachment.loadAction = .clear
        pass.stencilAttachment.clearStencil = 0
        pass.stencilAttachment.storeAction = .dontCare
        let mark = StencilFace(depthStencilPass: .replace)
        let test = StencilFace(compare: .equal)
        let scene = try RenderPass {
            try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
                // Marks stencil = 7 in the left half only.
                Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                    .vertexBuffer(fullscreen, index: 0)
                    .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
                    .scissor(MTLScissorRect(x: 0, y: 0, width: 32, height: 64))
                    .depthStencil(DepthState(compare: .always, isWriteEnabled: false, frontStencil: mark, backStencil: mark), stencilReference: 7)
                // Covers everything but passes only where stencil == 7, in the top half.
                Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                    .vertexBuffer(fullscreen, index: 0)
                    .parameter("color", value: SIMD4<Float>(0, 0, 1, 1))
                    .scissor(MTLScissorRect(x: 0, y: 0, width: 64, height: 32))
                    .depthStencil(DepthState(compare: .always, isWriteEnabled: false, frontStencil: test, backStencil: test), stencilReference: 7)
            }.vertexDescriptor(shaders.vertex.inferredVertexDescriptor())
        }.renderPassDescriptor(pass)
        let result = try await FrameRunner(device: device).run(scene)
        #expect(result.outcome == .completed)
        func pixel(_ x: Int, _ y: Int) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 4)
            color.getBytes(&bytes, bytesPerRow: 64 * 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
            return bytes
        }
        #expect(pixel(8, 8) == [255, 0, 0, 255])
        #expect(pixel(8, 48) == [0, 0, 255, 255])
        #expect(pixel(48, 8) == [0, 0, 0, 255])
        #expect(pixel(48, 48) == [0, 0, 0, 255])
    }

    // ImmersiveRenderPass lets the compositor draw a stencil mask with a pipeline-free RenderCommand, then content is
    // stencil-tested with the reference from `.stencilReferenceValue`. This models that without the compositor.
    @Test(.timeLimit(.minutes(1)))
    func renderCommandNeedsNoPipelineAndStencilReferenceReachesDraws() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let shaders = try shaders(Self.colorSource)
        let fullscreen = try vertexBuffer([[-1, -1], [3, -1], [-1, 3]])
        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 16, height: 16, mipmapped: false)
        colorDescriptor.usage = .renderTarget
        colorDescriptor.storageMode = .shared
        let color = try #require(device.makeTexture(descriptor: colorDescriptor))
        let stencilDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .stencil8, width: 16, height: 16, mipmapped: false)
        stencilDescriptor.usage = .renderTarget
        stencilDescriptor.storageMode = .private
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = color
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let stencil = try #require(device.makeTexture(descriptor: stencilDescriptor))
        pass.stencilAttachment.texture = stencil
        pass.stencilAttachment.loadAction = .clear
        pass.stencilAttachment.clearStencil = 200
        let equal = MTLStencilDescriptor()
        equal.stencilCompareFunction = .equal
        let depthStencil = MTLDepthStencilDescriptor()
        depthStencil.frontFaceStencil = equal
        depthStencil.backFaceStencil = equal
        func frame(reference: UInt32) throws -> some Element {
            try RenderPass {
                RenderCommand { $0.setViewport(MTLViewport(originX: 0, originY: 0, width: 16, height: 16, znear: 0, zfar: 1)) }
                try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                        .vertexBuffer(fullscreen, index: 0)
                        .parameter("color", value: SIMD4<Float>(0, 1, 0, 1))
                        .depthStencilDescriptor(depthStencil)
                }
                .vertexDescriptor(shaders.vertex.inferredVertexDescriptor())
                .stencilReferenceValue(reference)
            }
            .renderPassDescriptor(pass)
        }
        func center() -> [UInt8] {
            var pixel = [UInt8](repeating: 0, count: 4)
            color.getBytes(&pixel, bytesPerRow: 16 * 4, from: MTLRegionMake2D(8, 8, 1, 1), mipmapLevel: 0)
            return pixel
        }
        let runner = try Runner(device: device)
        try runner.run(try frame(reference: 200))
        #expect(center() == [0, 255, 0, 255])
        try runner.run(try frame(reference: 7))
        #expect(center() == [0, 0, 0, 255])
        #expect(throws: (any Error).self) {
            try RenderCommand { _ in }.run()
        }
    }

    // RenderView makes MTKView's depth texture memoryless by default; residency sets reject memoryless resources.
    @Test(.timeLimit(.minutes(1)))
    func memorylessAttachmentsRenderWithoutEnteringTheResidencySet() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 32, height: 32, mipmapped: false)
        colorDescriptor.usage = .renderTarget
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: 32, height: 32, mipmapped: false)
        depthDescriptor.usage = .renderTarget
        depthDescriptor.storageMode = .memoryless
        let pass = MTL4RenderPassDescriptor()
        let color = try #require(device.makeTexture(descriptor: colorDescriptor))
        let depth = try #require(device.makeTexture(descriptor: depthDescriptor))
        pass.colorAttachments[0].texture = color
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        let shaders = try shaders(Self.quadSource)
        let runner = try Runner(device: device)
        try runner.run(try RenderPass {
            try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
                Draw { $0.drawPrimitives(primitiveType: .triangleStrip, vertexStart: 0, vertexCount: 4) }
                    .vertexValues(Self.leftQuad, index: 0)
                    .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
                    .parameter("depth", value: Float(0.5))
                    .depthCompare(function: .less, enabled: true)
            }
            .vertexDescriptor(shaders.vertex.inferredVertexDescriptor())
        }
        .renderPassDescriptor(pass))
    }

    @Test(.timeLimit(.minutes(1)))
    func floatingPointTargetsRecompileAndRenderExactValues() async throws {
        let shaders = try shaders(Self.colorSource)
        let fullscreen = try vertexBuffer([[-1, -1], [3, -1], [-1, 3]])
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 8, height: 8), pixelFormat: .rgba16Float)
        let scene = try RenderPipeline(vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                .vertexBuffer(fullscreen, index: 0)
                .parameter("color", value: SIMD4<Float>(2.5, -1, 0.25, 1))
        }.vertexDescriptor(shaders.vertex.inferredVertexDescriptor())
        let texture = try await renderer.render(scene).texture
        var value = [Float16](repeating: 0, count: 4)
        texture.getBytes(&value, bytesPerRow: 8 * 8, from: MTLRegionMake2D(4, 4, 1, 1), mipmapLevel: 0)
        #expect(value == [2.5, -1, 0.25, 1])
    }
}
