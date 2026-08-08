import CoreGraphics
import Metal
@testable import MetalSprockets
import simd
import Testing

@MainActor
@Suite("Golden image rendering")
struct GoldenRenderingTests {
    /// Draws a screen-space quad at a fixed depth in a flat colour.
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]], constant float &depth [[buffer(1)]]) {
        VertexOut out;
        out.position = float4(in.position, depth, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(constant float4 &color [[buffer(0)]]) {
        return color;
    }
    """

    private struct Quad: Element {
        var vertexShader: VertexShader
        var fragmentShader: FragmentShader
        var corners: [SIMD2<Float>]
        var color: SIMD4<Float>
        var depth: Float
        var depthBias: (bias: Float, slopeScale: Float, clamp: Float)?
        var depthCompareFunction: MTLCompareFunction = .less

        var body: some Element {
            get throws {
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                    draw
                }
                .vertexDescriptor(vertexShader.inferredVertexDescriptor())
                .depthCompare(function: depthCompareFunction, enabled: true)
            }
        }

        @ElementBuilder
        private var draw: some Element {
            let geometry = Draw { encoder in
                let vertices = corners
                encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * vertices.count, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
            }
            .parameter("color", functionType: .fragment, value: color)
            .parameter("depth", functionType: .vertex, value: depth)

            if let depthBias {
                geometry.depthBias(depthBias.bias, slopeScale: depthBias.slopeScale, clamp: depthBias.clamp)
            }
            else {
                geometry
            }
        }
    }

    private func quad(corners: [SIMD2<Float>], color: SIMD4<Float>, depth: Float, depthBias: (Float, Float, Float)? = nil, shaders: Shaders? = nil, depthCompareFunction: MTLCompareFunction = .less) throws -> Quad {
        let shaders = try shaders ?? Self.makeShaders()
        return Quad(
            vertexShader: shaders.vertex,
            fragmentShader: shaders.fragment,
            corners: corners,
            color: color,
            depth: depth,
            depthBias: depthBias.map { (bias: $0.0, slopeScale: $0.1, clamp: $0.2) },
            depthCompareFunction: depthCompareFunction
        )
    }

    /// The pipeline cache keys on `MTLFunction` identity, so reaching second-frame behaviour means building the
    /// shaders once and reusing them.
    private struct Shaders {
        var vertex: VertexShader
        var fragment: FragmentShader
    }

    private static func makeShaders() throws -> Shaders {
        let library = try ShaderLibrary(source: Self.source)
        return Shaders(
            vertex: try library.function(type: VertexShader.self, named: "vertex_main"),
            fragment: try library.function(type: FragmentShader.self, named: "fragment_main")
        )
    }

    private static let leftQuad: [SIMD2<Float>] = [[-0.8, 0.6], [-0.8, -0.6], [0.2, 0.6], [0.2, -0.6]]
    private static let rightQuad: [SIMD2<Float>] = [[-0.2, 0.6], [-0.2, -0.6], [0.8, 0.6], [0.8, -0.6]]

    @Test func `a nearer quad occludes a farther one`() throws {
        // Red is drawn first and farther away; green is nearer, so green wins where they overlap.
        let scene = try RenderPass {
            try quad(corners: Self.leftQuad, color: [1, 0, 0, 1], depth: 0.8)
            try quad(corners: Self.rightQuad, color: [0, 1, 0, 1], depth: 0.2)
        }
        try Golden.verify(scene, named: "DepthNearOccludesFar")
    }

    @Test func `a farther quad does not occlude a nearer one`() throws {
        // Same scene, drawn in the other order: depth testing, not draw order, decides the overlap.
        let scene = try RenderPass {
            try quad(corners: Self.rightQuad, color: [0, 1, 0, 1], depth: 0.2)
            try quad(corners: Self.leftQuad, color: [1, 0, 0, 1], depth: 0.8)
        }
        try Golden.verify(scene, named: "DepthNearOccludesFar")
    }

    @Test func `depth bias pushes coplanar geometry in front`() throws {
        // Both quads sit at the same depth; without a bias the second loses the `.less` test entirely. A negative
        // bias pulls it nearer, so the overlap turns green.
        let scene = try RenderPass {
            try quad(corners: Self.leftQuad, color: [1, 0, 0, 1], depth: 0.5)
            try quad(corners: Self.rightQuad, color: [0, 1, 0, 1], depth: 0.5, depthBias: (-0.001, 0, 0))
        }
        try Golden.verify(scene, named: "DepthBiasWinsCoplanar")
    }

    @Test func `coplanar geometry without a bias loses the depth test`() throws {
        let scene = try RenderPass {
            try quad(corners: Self.leftQuad, color: [1, 0, 0, 1], depth: 0.5)
            try quad(corners: Self.rightQuad, color: [0, 1, 0, 1], depth: 0.5)
        }
        try Golden.verify(scene, named: "CoplanarNoBias")
    }

    @Test func `changing the depth compare function between frames takes effect`() throws {
        // One renderer, so both frames share a `System` and the same nodes. The tree shape never changes — only the
        // compare function does — which is exactly the case where a depth-stencil state cached on the first frame
        // could be left in place and silently ignore the new function.
        let shaders = try Self.makeShaders()
        func scene(_ compare: MTLCompareFunction) throws -> some Element {
            try RenderPass {
                try quad(corners: Self.leftQuad, color: [1, 0, 0, 1], depth: 0.5, shaders: shaders, depthCompareFunction: compare)
                try quad(corners: Self.rightQuad, color: [0, 1, 0, 1], depth: 0.5, shaders: shaders, depthCompareFunction: compare)
            }
        }

        // A fresh renderer establishes what `.always` is supposed to look like: the later draw always passes, so
        // green covers the overlap.
        let fresh = try OffscreenRenderer(size: CGSize(width: 256, height: 256))
        try Golden.verify(try fresh.render(try scene(.always)).cgImage, named: "CoplanarDepthAlways")

        let renderer = try OffscreenRenderer(size: CGSize(width: 256, height: 256))
        // `.less`: the green quad is coplanar with the red one, so it loses the overlap.
        try Golden.verify(try renderer.render(try scene(.less)).cgImage, named: "CoplanarNoBias")
        // The same scene again with `.always` has to produce the same image as the fresh renderer did.
        try Golden.verify(try renderer.render(try scene(.always)).cgImage, named: "CoplanarDepthAlways")
    }

    @Test func `a parameter binds the fragment colour`() throws {
        let scene = try RenderPass {
            try quad(corners: Self.leftQuad, color: [0, 0.25, 1, 1], depth: 0.5)
        }
        try Golden.verify(scene, named: "ParameterColour")
    }
}
