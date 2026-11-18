import Metal
import MetalSprockets
import simd

// Per-draw material binding (#579): four textures, a sampler and a tint per draw, bound slot by slot or through one
// argument buffer per material.

let materialsShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut { float4 position [[position]]; };

struct Material {
    float4 tint;
    texture2d<float> baseColor;
    texture2d<float> normal;
    texture2d<float> roughness;
    texture2d<float> emissive;
    sampler textureSampler;
};

[[vertex]] VertexOut materials_vertex(uint vertexID [[vertex_id]], constant float4x4 &transform [[buffer(0)]]) {
    float2 corners[3] = { {-1, -1}, {1, -1}, {0, 1} };
    VertexOut out;
    out.position = transform * float4(corners[vertexID], 0.5, 1);
    return out;
}

[[fragment]] float4 materials_slots(VertexOut in [[stage_in]], constant float4 &tint [[buffer(0)]],
        texture2d<float> baseColor [[texture(0)]], texture2d<float> normal [[texture(1)]],
        texture2d<float> roughness [[texture(2)]], texture2d<float> emissive [[texture(3)]],
        sampler textureSampler [[sampler(0)]]) {
    float2 uv = float2(0.5);
    return tint * (baseColor.sample(textureSampler, uv) + normal.sample(textureSampler, uv)
        + roughness.sample(textureSampler, uv) + emissive.sample(textureSampler, uv));
}

[[fragment]] float4 materials_argument_buffer(VertexOut in [[stage_in]], constant Material &material [[buffer(0)]]) {
    float2 uv = float2(0.5);
    return material.tint * (material.baseColor.sample(material.textureSampler, uv) + material.normal.sample(material.textureSampler, uv)
        + material.roughness.sample(material.textureSampler, uv) + material.emissive.sample(material.textureSampler, uv));
}
"""

struct MaterialsResources {
    struct Material {
        var tint: SIMD4<Float>
        var textures: [MTLTexture]
        var argumentBuffer: ArgumentBuffer
    }

    let materials: [Material]
    let sampler: MTLSamplerState
    let vertexShader: VertexShader
    let slotsShader: FragmentShader
    let argumentBufferShader: FragmentShader

    init(device: MTLDevice, materialCount: Int = 16) throws {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.supportArgumentBuffers = true
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)!
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        textureDescriptor.usage = [.shaderRead]
        let sampler = sampler
        materials = (0 ..< materialCount).map { index in
            let textures = (0 ..< 4).map { _ in device.makeTexture(descriptor: textureDescriptor)! }
            let tint = SIMD4<Float>(Float(index) / Float(materialCount), 0.5, 0.25, 1)
            let argumentBuffer = ArgumentBuffer(device: device, label: "Material \(index)")
            argumentBuffer.set("tint", value: tint)
            for (name, texture) in zip(["baseColor", "normal", "roughness", "emissive"], textures) {
                argumentBuffer.set(name, texture: texture)
            }
            argumentBuffer.set("textureSampler", samplerState: sampler)
            return Material(tint: tint, textures: textures, argumentBuffer: argumentBuffer)
        }
        let library = try device.makeLibrary(source: materialsShaderSource, options: nil)
        vertexShader = try VertexShader(library: library, name: "materials_vertex")
        slotsShader = try FragmentShader(library: library, name: "materials_slots")
        argumentBufferShader = try FragmentShader(library: library, name: "materials_argument_buffer")
    }
}

func materialDraw(index: Int, frame: Int, resources: MaterialsResources, argumentBuffers: Bool) -> AnyElement {
    let material = resources.materials[index % resources.materials.count]
    let angle = Float(frame) * 0.01 + Float(index)
    var transform = matrix_identity_float4x4
    transform.columns.0.x = 0.02
    transform.columns.1.y = 0.02
    transform.columns.3 = [sin(angle) * 0.8, cos(angle) * 0.8, 0, 1]
    let draw = Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
        .parameter("transform", value: transform)
    if argumentBuffers {
        return draw
            .parameter("material", argumentBuffer: material.argumentBuffer)
            .eraseToAnyElement()
    }
    return draw
        .parameter("tint", value: material.tint)
        .parameter("baseColor", texture: material.textures[0])
        .parameter("normal", texture: material.textures[1])
        .parameter("roughness", texture: material.textures[2])
        .parameter("emissive", texture: material.textures[3])
        .parameter("textureSampler", samplerState: resources.sampler)
        .eraseToAnyElement()
}

func materialsRoot(count: Int, frame: Int, resources: MaterialsResources, argumentBuffers: Bool) throws -> some Element {
    try RenderPass {
        try RenderPipeline(vertexShader: resources.vertexShader, fragmentShader: argumentBuffers ? resources.argumentBufferShader : resources.slotsShader) {
            ForEach(Array(0 ..< count), id: \.self) { index in
                materialDraw(index: index, frame: frame, resources: resources, argumentBuffers: argumentBuffers)
            }
        }
    }
}
