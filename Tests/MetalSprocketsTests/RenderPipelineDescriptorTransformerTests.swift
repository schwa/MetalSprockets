import AppKit
import Combine
import GoldenImage
import MetalKit
@testable import MetalSprockets
import simd
import SwiftUI
import Testing

@Test(.requiresMetal4)
@MainActor
func testRenderPipelineDescriptorTransformerWithoutAlphaBlending() throws {
    let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]]
    ) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant float4 &color [[buffer(0)]]
    ) {
        return color;
    }
    """

    let vertexShader = try VertexShader(source: source)
    let fragmentShader = try FragmentShader(source: source)

    // Draw two overlapping semi-transparent triangles WITHOUT alpha blending
    let redColor: SIMD4<Float> = [1, 0, 0, 0.5]
    let blueColor: SIMD4<Float> = [0, 0, 1, 0.5]

    let renderPass = try RenderPass {
        try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
            Draw { encoder in
                encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
            .parameter("color", value: redColor)

            Draw { encoder in
                encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .vertexValues(([[0, -0.5], [-0.5, 0.5], [0.5, 0.5]] as [SIMD2<Float>]), index: 0)
            .parameter("color", value: blueColor)
        }
        .vertexDescriptor(vertexShader.inferredVertexDescriptor())
    }

    let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 512, height: 512))
    let rendering = try offscreenRenderer.render(renderPass)
    let cgImage = try rendering.cgImage

    let goldenImagesDir = try #require(Bundle.module.resourceURL?.appendingPathComponent("Golden Images"))
    let comparison = GoldenImageComparison(imageDirectory: goldenImagesDir, options: .none)
    let isMatch = try comparison.image(image: cgImage, matchesGoldenImageNamed: "NoAlphaBlend")
    #expect(isMatch)
}

@Test(.requiresMetal4)
@MainActor
func testRenderPipelineDescriptorTransformerWithAlphaBlending() throws {
    let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]]
    ) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant float4 &color [[buffer(0)]]
    ) {
        return color;
    }
    """

    let vertexShader = try VertexShader(source: source)
    let fragmentShader = try FragmentShader(source: source)

    // Draw two overlapping semi-transparent triangles WITH alpha blending
    let redColor: SIMD4<Float> = [1, 0, 0, 0.5]
    let blueColor: SIMD4<Float> = [0, 0, 1, 0.5]

    let renderPass = try RenderPass {
        try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
            Draw { encoder in
                encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
            .parameter("color", value: redColor)

            Draw { encoder in
                encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .vertexValues(([[0, -0.5], [-0.5, 0.5], [0.5, 0.5]] as [SIMD2<Float>]), index: 0)
            .parameter("color", value: blueColor)
        }
        .vertexDescriptor(vertexShader.inferredVertexDescriptor())
        .renderPipelineDescriptorTransformer { descriptor in
            descriptor.colorAttachments[0].blendingState = .enabled
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
    }

    let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 512, height: 512))
    let rendering = try offscreenRenderer.render(renderPass)
    let cgImage = try rendering.cgImage

    let goldenImagesDir = try #require(Bundle.module.resourceURL?.appendingPathComponent("Golden Images"))
    let comparison = GoldenImageComparison(imageDirectory: goldenImagesDir, options: .none)
    let isMatch = try comparison.image(image: cgImage, matchesGoldenImageNamed: "WithAlphaBlend")
    #expect(isMatch)
}

@Test(.requiresMetal4)
@MainActor
func testRenderPassDescriptorModifierWithOffscreenRenderer() throws {
    let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]]
    ) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant float4 &color [[buffer(0)]]
    ) {
        return color;
    }
    """

    let color: SIMD4<Float> = [0, 1, 0, 1] // Green triangle
    let vertexShader = try VertexShader(source: source)
    let fragmentShader = try FragmentShader(source: source)

    let renderPass = try RenderPass {
        try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
            Draw { encoder in
                encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .vertexValues(([[0, 0.75], [-0.75, -0.75], [0.75, -0.75]] as [SIMD2<Float>]), index: 0)
            .parameter("color", value: color)
        }
        .vertexDescriptor(vertexShader.inferredVertexDescriptor())
    }
    .renderPassDescriptorModifier { descriptor in
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
    }

    let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 512, height: 512))
    let rendering = try offscreenRenderer.render(renderPass)
    _ = try rendering.cgImage
}

/// The pipeline cache key hashes the fully configured `MTLRenderPipelineDescriptor`, so anything a
/// `renderPipelineDescriptorTransformer` does is part of it. Turning blending on between frames has to be observable,
/// or the second frame silently reuses the first frame's PSO. See #359.
@Test(.requiresMetal4)
@MainActor
func testBlendStateChangeBetweenFramesTakesEffect() throws {
    let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out; out.position = float4(in.position, 0.0, 1.0); return out;
    }
    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]], constant float4 &color [[buffer(0)]]) {
        return color;
    }
    """

    // Built once: the cache keys on MTLFunction identity, so fresh shaders would miss every frame and hide the
    // question being asked here.
    let library = try ShaderLibrary(source: source)
    let vertexShader = try library.function(type: VertexShader.self, named: "vertex_main")
    let fragmentShader = try library.function(type: FragmentShader.self, named: "fragment_main")

    let redColor: SIMD4<Float> = [1, 0, 0, 0.5]
    let blueColor: SIMD4<Float> = [0, 0, 1, 0.5]

    // The tree shape is identical either way — the modifier is always present, only what it does changes.
    func scene(blending: Bool) throws -> some Element {
        try RenderPass {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
                .parameter("color", value: redColor)

                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, -0.5], [-0.5, 0.5], [0.5, 0.5]] as [SIMD2<Float>]), index: 0)
                .parameter("color", value: blueColor)
            }
            .vertexDescriptor(vertexShader.inferredVertexDescriptor())
            .renderPipelineDescriptorTransformer { descriptor in
                descriptor.colorAttachments[0].blendingState = blending ? .enabled : .disabled
                descriptor.colorAttachments[0].rgbBlendOperation = .add
                descriptor.colorAttachments[0].alphaBlendOperation = .add
                descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
                descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
        }
    }

    let size = CGSize(width: 512, height: 512)
    let renderer = try OffscreenRenderer(size: size)

    try Golden.verify(try renderer.render(try scene(blending: false)).cgImage, named: "NoAlphaBlend")
    try Golden.verify(try renderer.render(try scene(blending: true)).cgImage, named: "WithAlphaBlend")
}

/// Regression test for #342: verifies PSO cache hits on frames 2+ when
/// a renderPipelineDescriptorTransformer is present.
@Test(.requiresMetal4)
@MainActor
func testPSOCacheStableWithDescriptorModifier() throws {
    let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out; out.position = float4(in.position, 0.0, 1.0); return out;
    }
    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) { return float4(1,0,0,1); }
    """
    let vertexShader = try VertexShader(source: source)
    let fragmentShader = try FragmentShader(source: source)

    let device = try #require(MTLCreateSystemDefaultDevice())
    let commandQueue = try #require(device.makeMTL4CommandQueue())

    let colorDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: 64, height: 64, mipmapped: false)
    colorDesc.usage = [.renderTarget, .shaderRead, .shaderWrite]
    let colorTexture = try #require(device.makeTexture(descriptor: colorDesc))
    let depthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: 64, height: 64, mipmapped: false)
    depthDesc.usage = [.renderTarget, .shaderRead]
    let depthTexture = try #require(device.makeTexture(descriptor: depthDesc))

    let rpd = MTL4RenderPassDescriptor()
    rpd.colorAttachments[0].texture = colorTexture
    rpd.colorAttachments[0].loadAction = .clear
    rpd.colorAttachments[0].storeAction = .store
    rpd.depthAttachment.texture = depthTexture
    rpd.depthAttachment.loadAction = .clear
    rpd.depthAttachment.clearDepth = 1
    rpd.depthAttachment.storeAction = .store

    let runner = try Runner(device: device, commandQueue: commandQueue)
    var pipelineStates: [any MTLRenderPipelineState] = []

    for _ in 0..<3 {
        let root = try Group {
            try RenderPass {
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                    Draw { encoder in
                        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                    .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
                }
                .vertexDescriptor(vertexShader.inferredVertexDescriptor())
                .renderPipelineDescriptorTransformer { descriptor in
                    descriptor.colorAttachments[0].blendingState = .enabled
                    descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                    descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                }
            }
        }
        .renderPassDescriptor(rpd)
        .environment(\.drawableSize, CGSize(width: 64, height: 64))

        try runner.run(root)

        let frameStates = runner.system.nodes.values.compactMap(\.environmentValues.renderPipelineState)
        #expect(!frameStates.isEmpty)
        pipelineStates.append(contentsOf: frameStates)
    }

    // A descriptor modifier that does the same thing every frame must not defeat the cache: the modified descriptor
    // is part of the cache key (#359), so it has to hash equal frame to frame.
    #expect(Set(pipelineStates.map(ObjectIdentifier.init)).count == 1)
}
