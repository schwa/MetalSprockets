import AppKit
import Combine
import GoldenImage
import MetalKit
@testable import MetalSprockets
import simd
import SwiftUI
import Testing

@Test
@MainActor
func testRenderPipelineDescriptorModifierWithoutAlphaBlending() throws {
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
            // First triangle (red, pointing up)
            Draw { encoder in
                let vertices: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .parameter("color", value: redColor)

            // Second triangle (blue, pointing down, overlapping the red triangle)
            Draw { encoder in
                let vertices: [SIMD2<Float>] = [[0, -0.5], [-0.5, 0.5], [0.5, 0.5]]
                encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .parameter("color", value: blueColor)
        }
        .vertexDescriptor(try vertexShader.inferredVertexDescriptor())
        // NO alpha blending modifier here
    }

    let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 512, height: 512))
    let rendering = try offscreenRenderer.render(renderPass)
    let cgImage = try rendering.cgImage

    let goldenImagesDir = try #require(Bundle.module.resourceURL?.appendingPathComponent("Golden Images"))
    let comparison = GoldenImageComparison(imageDirectory: goldenImagesDir, options: .none)
    let isMatch = try comparison.image(image: cgImage, matchesGoldenImageNamed: "NoAlphaBlend")
    #expect(isMatch)
}

@Test
@MainActor
func testRenderPipelineDescriptorModifierWithAlphaBlending() throws {
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
            // First triangle (red, pointing up)
            Draw { encoder in
                let vertices: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .parameter("color", value: redColor)

            // Second triangle (blue, pointing down, overlapping the red triangle)
            Draw { encoder in
                let vertices: [SIMD2<Float>] = [[0, -0.5], [-0.5, 0.5], [0.5, 0.5]]
                encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .parameter("color", value: blueColor)
        }
        .vertexDescriptor(try vertexShader.inferredVertexDescriptor())
        .renderPipelineDescriptorModifier { descriptor in
            descriptor.colorAttachments[0].isBlendingEnabled = true
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

@Test
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
                let vertices: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
                encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            .parameter("color", value: color)
        }
        .vertexDescriptor(try vertexShader.inferredVertexDescriptor())
    }
    .renderPassDescriptorModifier { descriptor in
        // Modify the render pass descriptor
        // This should work without crashing and should modify a copy, not the original
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
    }

    let offscreenRenderer = try OffscreenRenderer(size: CGSize(width: 512, height: 512))
    let rendering = try offscreenRenderer.render(renderPass)
    _ = try rendering.cgImage
}
