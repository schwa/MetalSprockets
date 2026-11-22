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

// The merged scenario: one table of transforms, each draw picks its row with base_instance.
[[vertex]] VertexOut cube_vertex_merged(VertexIn in [[stage_in]], constant float4x4 *transforms [[buffer(1)]], uint instance [[instance_id]]) {
    VertexOut out;
    out.position = transforms[instance] * float4(in.position, 1.0);
    out.color = in.color;
    return out;
}

[[fragment]] float4 cube_fragment(VertexOut in [[stage_in]], constant float &time [[buffer(0)]]) {
    return in.color * (0.75 + 0.25 * sin(time));
}
"""

struct CubeVertex: Equatable {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

struct CubeResources {
    var vertexShader: VertexShader
    var mergedVertexShader: VertexShader
    var fragmentShader: FragmentShader
    var vertexDescriptor: MTLVertexDescriptor
    var vertices: [CubeVertex]

    init(device: MTLDevice) throws {
        let library = try device.makeLibrary(source: cubeShaderSource, options: nil)
        vertexShader = try VertexShader(library: library, name: "cube_vertex")
        mergedVertexShader = try VertexShader(library: library, name: "cube_vertex_merged")
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

/// `moving`: how many cubes (the first ones) animate with `frame`. The rest use frame 0, so their transforms are the
/// same every frame. `nil` animates them all.
func cubeTransforms(count: Int, frame: Int, moving: Int? = nil) -> [simd_float4x4] {
    let animated = cubeViewProjection(count: count, frame: frame)
    let still = cubeViewProjection(count: count, frame: 0)
    return cubeCenters(count: count).enumerated().map { index, center in
        var model = matrix_identity_float4x4
        model.columns.3 = SIMD4(center, 1)
        let isMoving = moving.map { index < $0 } ?? true
        return (isMoving ? animated : still) * model
    }
}

/// Projection, view and the scene's rotation: maps a cube's grid-space position to clip space.
func cubeViewProjection(count: Int, frame: Int) -> simd_float4x4 {
    let side = Int(ceil(cbrt(Double(count))))
    var view = matrix_identity_float4x4
    view.columns.3.z = -8 * Float(side)
    let projection = perspective(fovY: .pi / 4, aspect: 1.6, near: 0.1, far: 100 * Float(side))
    return projection * view * simd_float4x4(simd_quatf(angle: Float(frame) * 0.01, axis: simd_normalize([1, 1, 0])))
}

func cubeCenters(count: Int) -> [SIMD3<Float>] {
    let side = Int(ceil(cbrt(Double(count))))
    let center = Float(side - 1) / 2
    return (0..<count).map { index in
        SIMD3(Float(index % side) - center, Float((index / side) % side) - center, Float(index / (side * side)) - center) * 3
    }
}

/// The cubes scene drawn by one element: a DrawList issues every cube's draw, each picking its transform from a
/// shared table by base instance (#586). With `cull`, every row has bounds and is frustum-culled (#591); the whole grid
/// is in view, so this measures the cost of culling, not its savings.
func mergedCubesRoot(count: Int, frame: Int, resources: CubeResources, cull: Bool = false) throws -> some Element {
    let transforms = cubeTransforms(count: count, frame: frame)
    let centers = cubeCenters(count: count)
    let culling = cull ? [cubeViewProjection(count: count, frame: frame)] : []
    let time = Float(frame) / 60
    return try RenderPass(label: "Cubes") {
        try RenderPipeline(vertexShader: resources.mergedVertexShader, fragmentShader: resources.fragmentShader) {
            DrawList(cullingViewProjections: culling, 0..<count) { index in
                DrawRow(geometry: .vertices(0..<36), instances: index..<index + 1, bounds: cull ? DrawRow.Bounds(min: centers[index] - 0.5, max: centers[index] + 0.5) : nil)
            }
            .vertexValues(resources.vertices, index: 0)
            .parameter("transforms", values: transforms)
            .parameter("time", value: time)
        }
        .vertexDescriptor(resources.vertexDescriptor)
        .depthCompare(function: .less, writes: true)
    }
}

/// One cube as an Equatable element, for `--equatable`. `vertices` is the same array every frame, so comparing it is a
/// buffer identity check.
private struct Cube: Element, Equatable {
    var transform: simd_float4x4
    var time: Float
    var vertices: [CubeVertex]

    var body: some Element {
        cube(transform: transform, time: time, vertices: vertices)
    }
}

private func cube(transform: simd_float4x4, time: Float, vertices: [CubeVertex]) -> some Element {
    Draw { encoder in
        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 36)
    }
    .vertexValues(vertices, index: 0)
    .parameter("transform", value: transform)
    .parameter("time", value: time)
}

func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let y = 1 / tan(fovY / 2)
    let x = y / aspect
    let z = far / (near - far)
    return simd_float4x4(columns: ([x, 0, 0, 0], [0, y, 0, 0], [0, 0, z, -1], [0, 0, z * near, 0]))
}

/// `moving`: see `cubeTransforms`. With a value, the shared `time` parameter is also fixed, so unchanged cubes are
/// identical to the previous frame (the static scene, #520).
func cubesRoot(count: Int, frame: Int, resources: CubeResources, moving: Int? = nil, equatable: Bool = false) throws -> some Element {
    let transforms = cubeTransforms(count: count, frame: frame, moving: moving)
    let time: Float = moving == nil ? Float(frame) / 60 : 0
    let vertices = resources.vertices
    return try RenderPass(label: "Cubes") {
        try RenderPipeline(vertexShader: resources.vertexShader, fragmentShader: resources.fragmentShader) {
            // The branch is outside the ForEach, so each item stays one element type.
            if equatable {
                ForEach(Array(transforms.enumerated()), id: \.offset) { _, transform in
                    Cube(transform: transform, time: time, vertices: vertices).equatable()
                }
            } else {
                ForEach(Array(transforms.enumerated()), id: \.offset) { _, transform in
                    cube(transform: transform, time: time, vertices: vertices)
                }
            }
        }
        .vertexDescriptor(resources.vertexDescriptor)
        .depthCompare(function: .less, writes: true)
    }
}
