import CoreGraphics
import Metal
@testable import MetalSprockets
import Testing

private func meshCapability() -> Bool {
    guard let device = MTLCreateSystemDefaultDevice() else {
        return false
    }
    return device.supportsFamily(.metal4) && (device.supportsFamily(.apple7) || device.supportsFamily(.mac2))
}

/// Legacy MeshRenderPipelineTests scenes on the Metal 4 candidate, compared against the same, unchanged references.
@MainActor
@Suite("Metal 4 mesh pipeline parity", .requiresMetal4, .enabled(if: meshCapability(), "Requires Metal 4 and mesh shaders (Apple 7 / Mac 2 family)"))
struct MeshPipelineTests {
    private struct Shaders {
        var object: ObjectShader
        var mesh: MeshShader
        var fragment: FragmentShader
    }

    private func makeShaders(_ source: String = MeshRenderPipelineTests.objectMeshSource) throws -> Shaders {
        let library = try ShaderLibrary(source: source)
        return Shaders(
            object: try library.function(type: ObjectShader.self, named: "object_main"),
            mesh: try library.function(type: MeshShader.self, named: "mesh_main"),
            fragment: try library.function(type: FragmentShader.self, named: "fragment_main")
        )
    }

    private static func dispatch(_ encoder: any MTL4RenderCommandEncoder) {
        encoder.drawMeshThreadgroups(threadgroupsPerGrid: MTLSize(width: 1, height: 1, depth: 1), threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1), threadsPerMeshThreadgroup: MTLSize(width: 3, height: 1, depth: 1))
    }

    private func scene(_ shaders: Shaders, scale: Float, tint: SIMD4<Float>, depthCompare: Bool = false, scaleStages: FunctionTypes = .object) throws -> some Element {
        try MeshRenderPipeline(label: "object+mesh", objectShader: shaders.object, meshShader: shaders.mesh, fragmentShader: shaders.fragment) {
            let draw = Draw(encodeGeometry: Self.dispatch)
                .parameter("scale", functionTypes: scaleStages, value: scale)
                .parameter("tint", functionTypes: .fragment, value: tint)
            if depthCompare {
                draw.depthCompare(function: .less, enabled: true)
            } else {
                draw
            }
        }
    }

    private func image(_ content: some Element, renderer: TestOffscreenRenderer? = nil) async throws -> CGImage {
        let renderer = try renderer ?? TestOffscreenRenderer(size: CGSize(width: 128, height: 128))
        return try await renderer.render(content).cgImage
    }

    @Test(.timeLimit(.minutes(1)))
    func objectStageFeedsMeshStageAndMatchesLegacyGoldens() async throws {
        let shaders = try makeShaders()
        try Golden.verify(try await image(scene(shaders, scale: 1, tint: [0, 1, 0, 1])), named: "MeshTriangle")
        try Golden.verify(try await image(scene(shaders, scale: 0.5, tint: [1, 0, 1, 1])), named: "MeshTriangleHalfScale")
        try Golden.verify(try await image(scene(shaders, scale: 1, tint: [0, 1, 0, 1], depthCompare: true)), named: "MeshTriangle")
    }

    @Test(.timeLimit(.minutes(1)))
    func meshOnlyPipelineRendersWithoutAnObjectStage() async throws {
        let library = try ShaderLibrary(source: MeshRenderPipelineTests.meshSource)
        let mesh = try library.function(type: MeshShader.self, named: "mesh_main")
        let fragment = try library.function(type: FragmentShader.self, named: "fragment_main")
        let content = try MeshRenderPipeline(meshShader: mesh, fragmentShader: fragment) {
            Draw(encodeGeometry: Self.dispatch)
        }
        // Same geometry and green as the object+mesh fixture.
        try Golden.verify(try await image(content), named: "MeshTriangle")
    }

    @Test(.timeLimit(.minutes(1)))
    func repeatedFramesReuseThePipelineAndIdentityChangesRecompile() async throws {
        let shaders = try makeShaders()
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 128, height: 128))
        let pipelines = renderer.runner.context.pipelines
        for frame in 0..<5 {
            // Parameters change per frame without recompiling; output follows the new values.
            let scale: Float = frame.isMultiple(of: 2) ? 1 : 0.5
            try Golden.verify(try await image(scene(shaders, scale: scale, tint: frame.isMultiple(of: 2) ? [0, 1, 0, 1] : [1, 0, 1, 1]), renderer: renderer), named: frame.isMultiple(of: 2) ? "MeshTriangle" : "MeshTriangleHalfScale")
        }
        #expect(pipelines.compilationCount == 1)

        // A different library with identical source is a different identity and must not reuse the pipeline.
        _ = try await image(scene(try makeShaders(), scale: 1, tint: [0, 1, 0, 1]), renderer: renderer)
        #expect(pipelines.compilationCount == 2)

        // A different attachment layout (4x MSAA) compiles its own pipeline and still resolves to the same picture.
        let multisampled = try TestOffscreenRenderer(size: CGSize(width: 128, height: 128), sampleCount: 4)
        _ = try await image(scene(shaders, scale: 1, tint: [0, 1, 0, 1]), renderer: multisampled)
        #expect(multisampled.runner.context.pipelines.compilationCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func reflectionCoversObjectMeshAndFragmentStagesAndLabels() throws {
        let shaders = try makeShaders()
        let context = try MetalContext(device: try #require(MTLCreateSystemDefaultDevice()))
        let pipeline = try context.pipelines.meshRenderPipeline(MeshRenderPipelineConfiguration(object: shaders.object, mesh: shaders.mesh, fragment: shaders.fragment, colorPixelFormats: [.bgra8Unorm], label: "reflected"))
        #expect(pipeline.stages == [.object, .mesh, .fragment])
        #expect(pipeline.bindings.index(of: "scale", stage: .object) == 0)
        #expect(pipeline.bindings.index(of: "tint", stage: .fragment) == 0)
        #expect(pipeline.bindings.index(of: "scale", stage: .fragment) == nil)
        #expect(pipeline.bindings.tableSizes(stage: .object).buffers == 1)
        #expect(pipeline.bindings.tableSizes(stage: .mesh) == .init())
        #expect(pipeline.state.label == "reflected")
    }

    @Test(.timeLimit(.minutes(1)))
    func stageFiltersAreEnforced() async throws {
        let shaders = try makeShaders()
        // "scale" exists only in the object stage; filtering it to the fragment stage is a missing binding.
        await #expect(throws: ParameterSet.Failure.self) {
            _ = try await image(scene(shaders, scale: 1, tint: [0, 1, 0, 1], scaleStages: .fragment))
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func combinedDepthStencilAttachmentMatchesLegacyGolden() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: 128, height: 128, mipmapped: false)
        colorDescriptor.usage = [.renderTarget, .shaderRead]
        let color = try #require(device.makeTexture(descriptor: colorDescriptor))
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float_stencil8, width: 128, height: 128, mipmapped: false)
        depthDescriptor.usage = .renderTarget
        depthDescriptor.storageMode = .private
        let depthStencil = try #require(device.makeTexture(descriptor: depthDescriptor))
        let pass = MTL4RenderPassDescriptor()
        pass.colorAttachments[0].texture = color
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = depthStencil
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        pass.stencilAttachment.texture = depthStencil
        pass.stencilAttachment.loadAction = .clear
        let shaders = try makeShaders()
        let content = try RenderPass {
            try scene(shaders, scale: 1, tint: [0, 1, 0, 1], depthCompare: true)
        }.renderPassDescriptor(pass)
        let result = try await FrameRunner(device: device).run(content)
        #expect(result.outcome == .completed)
        try Golden.verify(try OffscreenRenderer.Rendering(texture: color).cgImage, named: "MeshTriangle")
    }
}
