// Mirrors the Example app's Render demo at high cube counts: one non-instanced Draw per cube inside a ForEach, each
// with vertexValues and two parameters (DemoCubeRenderPipeline).

import Metal
import MetalSprockets
import simd

let cubeShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

[[vertex]] VertexOut cube_vertex(VertexIn in [[stage_in]], constant float4x4 &transform [[buffer(1)]]) {
    VertexOut out;
    out.position = transform * float4(in.position, 1.0);
    out.color = in.color;
    return out;
}

[[fragment]] float4 cube_fragment(VertexOut in [[stage_in]], constant float &time [[buffer(0)]]) {
    return in.color * (0.75 + 0.25 * sin(time));
}
"""

struct CubeVertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

struct CubeResources {
    var vertexShader: VertexShader
    var fragmentShader: FragmentShader
    var vertexDescriptor: MTLVertexDescriptor
    var vertices: [CubeVertex]

    init(device: MTLDevice) throws {
        let library = try device.makeLibrary(source: cubeShaderSource, options: nil)
        vertexShader = try VertexShader(library: library, name: "cube_vertex")
        fragmentShader = try FragmentShader(library: library, name: "cube_fragment")
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0
        descriptor.attributes[1].format = .float4
        descriptor.attributes[1].offset = MemoryLayout<CubeVertex>.offset(of: \.color)!
        descriptor.attributes[1].bufferIndex = 0
        descriptor.layouts[0].stride = MemoryLayout<CubeVertex>.stride
        vertexDescriptor = descriptor
        vertices = Self.makeVertices()
    }

    // 36 vertices, two triangles per face, coloured by position.
    static func makeVertices() -> [CubeVertex] {
        let axes: [SIMD3<Float>] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]
        var vertices: [CubeVertex] = []
        for normal in axes {
            let u = SIMD3<Float>(normal.y, normal.z, normal.x)
            let v = cross(normal, u)
            let corners = [(Float(-1), Float(-1)), (1, -1), (1, 1), (-1, 1)].map { s, t in (normal + u * s + v * t) * 0.5 }
            for index in [0, 1, 2, 0, 2, 3] {
                let position = corners[index]
                vertices.append(CubeVertex(position: position, color: SIMD4(position + 0.5, 1)))
            }
        }
        return vertices
    }
}

func cubeTransforms(count: Int, frame: Int) -> [simd_float4x4] {
    let side = Int(ceil(cbrt(Double(count))))
    let center = Float(side - 1) / 2
    let angle = Float(frame) * 0.01
    let rotation = simd_float4x4(simd_quatf(angle: angle, axis: simd_normalize([1, 1, 0])))
    var view = matrix_identity_float4x4
    view.columns.3.z = -8 * Float(side)
    let projection = perspective(fovY: .pi / 4, aspect: 1.6, near: 0.1, far: 100 * Float(side))
    return (0..<count).map { index in
        var model = matrix_identity_float4x4
        model.columns.3 = SIMD4(SIMD3(Float(index % side) - center, Float((index / side) % side) - center, Float(index / (side * side)) - center) * 3, 1)
        return projection * view * rotation * model
    }
}

func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let y = 1 / tan(fovY / 2)
    let x = y / aspect
    let z = far / (near - far)
    return simd_float4x4(columns: ([x, 0, 0, 0], [0, y, 0, 0], [0, 0, z, -1], [0, 0, z * near, 0]))
}

func cubesRoot(count: Int, frame: Int, resources: CubeResources) throws -> some Element {
    let transforms = cubeTransforms(count: count, frame: frame)
    let time = Float(frame) / 60
    let vertices = resources.vertices
    return try RenderPass(label: "Cubes") {
        try RenderPipeline(vertexShader: resources.vertexShader, fragmentShader: resources.fragmentShader) {
            ForEach(Array(transforms.enumerated()), id: \.offset) { _, transform in
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 36)
                }
                .vertexValues(vertices, index: 0)
                .parameter("transform", value: transform)
                .parameter("time", value: time)
            }
        }
        .vertexDescriptor(resources.vertexDescriptor)
        .depthCompare(function: .less, enabled: true)
    }
}
