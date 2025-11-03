import Metal
import MetalSprockets
import MetalSprocketsSupport
import simd

struct ExampleTriangleElement: Element {
    @MSState private var vertexShader: VertexShader
    @MSState private var fragmentShader: FragmentShader

    let transform: float4x4

    init(time: TimeInterval) throws {
        self.transform = float4x4(simd_quatf(angle: Float(time), axis: [0, 0, 1]))

        let source = """
            #include <metal_stdlib>
            using namespace metal;

            struct VertexIn {
                float2 position [[attribute(0)]];
                float4 color [[attribute(1)]];
            };

            struct VertexOut {
                float4 position [[position]];
                float4 color;
            };

            [[vertex]] VertexOut vertex_main(
                const VertexIn in [[stage_in]],
                constant float4x4 &transform [[buffer(1)]]
            ) {
                VertexOut out;
                out.position = transform * float4(in.position, 0.0, 1.0);
                out.color = in.color;
                return out;
            }

            [[fragment]] float4 fragment_main(
                VertexOut in [[stage_in]]
            ) {
                return in.color;
            }
        """
        vertexShader = try VertexShader(source: source)
        fragmentShader = try FragmentShader(source: source)
    }

    struct Vertex {
        var position: SIMD2<Float>
        var color: SIMD4<Float>
    }

    var body: some Element {
        get throws {
            try RenderPass {
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                    Draw { encoder in
                        struct Vertex {
                            var position: SIMD2<Float>
                            var color: SIMD4<Float>
                        }

                        let vertices: [Vertex] = [
                            Vertex(position: [0, 0.375], color: [1, 0, 0, 1]),                                      // Top: Red
                            Vertex(position: [-0.375 * Float(sqrt(3.0) / 2.0), -0.1875], color: [0, 1, 0, 1]),    // Bottom-left: Green
                            Vertex(position: [0.375 * Float(sqrt(3.0) / 2.0), -0.1875], color: [0, 0, 1, 1])      // Bottom-right: Blue
                        ]
                        encoder.setVertexBytes(vertices, length: MemoryLayout<Vertex>.stride * 3, index: 0)
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                    .parameter("transform", value: transform)
                }
                .vertexDescriptor(MTLVertexDescriptor(reflection: Vertex.self))
            }
        }
    }
}
