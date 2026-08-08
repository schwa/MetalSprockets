import CoreGraphics
import Metal
@testable import MetalSprockets
import simd
import Testing

@MainActor
@Suite("Render pipeline caching and attachments")
struct RenderPipelineCacheTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn { float2 position [[attribute(0)]]; };

    [[vertex]] float4 vertex_main(const VertexIn in [[stage_in]]) {
        return float4(in.position, 0.5, 1);
    }

    [[fragment]] float4 fragment_main() {
        return float4(0, 1, 0, 1);
    }
    """

    private struct Shaders {
        var vertex: VertexShader
        var fragment: FragmentShader
    }

    /// Built once: the pipeline cache is keyed on function identity, so fresh shaders would always miss.
    private func makeShaders() throws -> Shaders {
        let library = try ShaderLibrary(source: Self.source)
        return Shaders(
            vertex: try library.function(type: VertexShader.self, named: "vertex_main"),
            fragment: try library.function(type: FragmentShader.self, named: "fragment_main")
        )
    }

    private func pass(shaders: Shaders) throws -> some Element {
        try RenderPass {
            try RenderPipeline(label: "cached", vertexShader: shaders.vertex, fragmentShader: shaders.fragment) {
                Draw { encoder in
                    let vertices: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
            .vertexDescriptor(try shaders.vertex.inferredVertexDescriptor())
            .depthCompare(function: .less, enabled: true)
        }
    }

    @Test func `a second render reuses the cached pipeline and depth stencil state`() throws {
        let shaders = try makeShaders()
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))

        _ = try renderer.render(try pass(shaders: shaders))
        // Same shader identities and same attachment formats, so setup takes the cache-hit path and restores the
        // depth-stencil state it built the first time.
        _ = try renderer.render(try pass(shaders: shaders))
    }

    @Test func `a stencil attachment contributes its pixel format to the pipeline`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let shaders = try makeShaders()

        func makeTexture(format: MTLPixelFormat) throws -> MTLTexture {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: 64, height: 64, mipmapped: false)
            descriptor.usage = [.renderTarget]
            descriptor.storageMode = .private
            return try #require(device.makeTexture(descriptor: descriptor))
        }

        let colorTexture = try makeTexture(format: .bgra8Unorm)
        let depthStencilTexture = try makeTexture(format: .depth32Float_stencil8)

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = colorTexture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.depthAttachment.texture = depthStencilTexture
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.storeAction = .dontCare
        descriptor.stencilAttachment.texture = depthStencilTexture
        descriptor.stencilAttachment.loadAction = .clear
        descriptor.stencilAttachment.storeAction = .dontCare

        let runner = try Runner(device: device)
        try runner.run(
            try pass(shaders: shaders)
                .renderPassDescriptor(descriptor)
                .drawableSize(CGSize(width: 64, height: 64))
        )
    }
}
