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

        var body: some Element {
            get throws {
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                    draw
                }
                .vertexDescriptor(vertexShader.inferredVertexDescriptor())
                .depthCompare(function: .less, enabled: true)
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

    private func quad(corners: [SIMD2<Float>], color: SIMD4<Float>, depth: Float, depthBias: (Float, Float, Float)? = nil) throws -> Quad {
        Quad(
            vertexShader: try VertexShader(source: Self.source),
            fragmentShader: try FragmentShader(source: Self.source),
            corners: corners,
            color: color,
            depth: depth,
            depthBias: depthBias.map { (bias: $0.0, slopeScale: $0.1, clamp: $0.2) }
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

    @Test func `a parameter binds the fragment colour`() throws {
        let scene = try RenderPass {
            try quad(corners: Self.leftQuad, color: [0, 0.25, 1, 1], depth: 0.5)
        }
        try Golden.verify(scene, named: "ParameterColour")
    }
}
