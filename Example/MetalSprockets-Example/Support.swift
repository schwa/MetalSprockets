import Metal
import simd

// Swift counterpart of VertexIn in Shaders.metal.
// Layout must match exactly - alternatively, define structs in a .h file and import
// via bridging header to share between Swift and Metal.
struct Vertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
    var uv: SIMD2<Float>

    // Vertex descriptor tells Metal how to interpret the vertex buffer layout.
    // Must match the VertexIn struct in the shader.
    static let descriptor: MTLVertexDescriptor = {
        let desc = MTLVertexDescriptor()

        // position: float3 at offset 0
        desc.attributes[0].format = .float3
        desc.attributes[0].offset = 0
        desc.attributes[0].bufferIndex = 0

        // color: float4 at offset 16 (SIMD3 has stride of 16, not 12)
        desc.attributes[1].format = .float4
        desc.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        desc.attributes[1].bufferIndex = 0

        // uv: float2 at offset 32
        desc.attributes[2].format = .float2
        desc.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride
        desc.attributes[2].bufferIndex = 0

        desc.layouts[0].stride = MemoryLayout<Self>.stride
        desc.layouts[0].stepFunction = .perVertex
        return desc
    }()
}

// Generates a unit cube (-1 to 1) with RGB gradient colors based on vertex position.
// Each face has UV coordinates for edge detection in the fragment shader.
func generateCubeVertices() -> [Vertex] {
    // Map position components to RGB: (-1,1) -> (0,1)
    func colorForPosition(_ p: SIMD3<Float>) -> SIMD4<Float> {
        let r = (p.x + 1) * 0.5
        let g = (p.y + 1) * 0.5
        let b = (p.z + 1) * 0.5
        return SIMD4<Float>(r, g, b, 1)
    }

    // Each face defined by 4 corners in counter-clockwise order (for correct culling)
    let faces: [[SIMD3<Float>]] = [
        [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]],       // Front +Z
        [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]],   // Back -Z
        [[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]],       // Top +Y
        [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]],   // Bottom -Y
        [[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]],       // Right +X
        [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]]   // Left -X
    ]

    // UV corners for edge detection
    let uvs: [SIMD2<Float>] = [[0, 0], [1, 0], [1, 1], [0, 1]]

    // Build two triangles per face (6 vertices per face, 36 total)
    var vertices: [Vertex] = []
    for face in faces {
        vertices.append(Vertex(position: face[0], color: colorForPosition(face[0]), uv: uvs[0]))
        vertices.append(Vertex(position: face[1], color: colorForPosition(face[1]), uv: uvs[1]))
        vertices.append(Vertex(position: face[2], color: colorForPosition(face[2]), uv: uvs[2]))
        vertices.append(Vertex(position: face[0], color: colorForPosition(face[0]), uv: uvs[0]))
        vertices.append(Vertex(position: face[2], color: colorForPosition(face[2]), uv: uvs[2]))
        vertices.append(Vertex(position: face[3], color: colorForPosition(face[3]), uv: uvs[3]))
    }
    return vertices
}

// Creates a tumbling rotation matrix for the spinning cube animation
func cubeRotationMatrix(time: TimeInterval) -> float4x4 {
    let rotationY = float4x4(simd_quatf(angle: Float(time), axis: [0, 1, 0]))
    let rotationX = float4x4(simd_quatf(angle: Float(time) * 0.7, axis: [1, 0, 0]))
    return rotationX * rotationY
}

extension float4x4 {
    static func translation(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
        float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(x, y, z, 1)
        ))
    }

    static func scale(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
        float4x4(diagonal: SIMD4<Float>(x, y, z, 1))
    }

    // Standard perspective projection matrix
    static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let y = 1 / tan(fovY * 0.5)
        let x = y / aspect
        let z = far / (near - far)
        let w = (near * far) / (near - far)
        return float4x4(columns: (
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, -1),
            SIMD4<Float>(0, 0, w, 0)
        ))
    }
}
