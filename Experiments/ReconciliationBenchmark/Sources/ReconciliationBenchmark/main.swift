// Clean-room repro for issue #486: per-frame reconciliation cost with ~200 draw elements.
// Usage: ReconciliationBenchmark [--frames N] [--half-modifiers] [--flat] [--counts 10,50,100]

import CoreGraphics
import Foundation
import Metal
import MetalSprockets
import simd

let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
};

struct Material {
    float4 tint;
    float roughness;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

[[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]], constant float4x4 &transform [[buffer(0)]]) {
    VertexOut out;
    out.position = transform * float4(in.position + in.normal * 0.0, 1.0);
    out.uv = in.uv;
    return out;
}

[[fragment]] float4 fragment_main(VertexOut in [[stage_in]], constant Material &material [[buffer(0)]], constant float &scale [[buffer(1)]], texture2d<float> albedo [[texture(0)]], sampler albedoSampler [[sampler(0)]]) {
    return albedo.sample(albedoSampler, in.uv) * material.tint * scale * material.roughness;
}
"""

struct Material {
    var tint: SIMD4<Float>
    var roughness: Float
}

struct Options {
    var frames = 60
    var halfModifiers = false
    var flat = false
    var counts = [10, 50, 100, 200, 400]

    init(arguments: [String]) {
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--frames": frames = Int(iterator.next() ?? "") ?? frames
            case "--half-modifiers": halfModifiers = true
            case "--flat": flat = true
            case "--counts": counts = (iterator.next() ?? "").split(separator: ",").compactMap { Int($0) }
            default: fatalError("Unknown argument \(argument)")
            }
        }
    }
}

struct Resources {
    var positions: MTLBuffer
    var normals: MTLBuffer
    var uvs: MTLBuffer
    var indices: MTLBuffer
    var indexCount: Int
    var texture: MTLTexture
    var sampler: MTLSamplerState
    var vertexShader: VertexShader
    var fragmentShader: FragmentShader
    var vertexDescriptor: MTLVertexDescriptor

    init(device: MTLDevice) throws {
        // A 24-vertex box: 6 faces x 4 corners.
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt16] = []
        let axes: [SIMD3<Float>] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]
        for normal in axes {
            let u = SIMD3<Float>(normal.y, normal.z, normal.x)
            let v = cross(normal, u)
            let base = UInt16(positions.count)
            for (s, t) in [(Float(-1), Float(-1)), (1, -1), (1, 1), (-1, 1)] {
                positions.append((normal + u * s + v * t) * 0.5)
                normals.append(normal)
                uvs.append([(s + 1) / 2, (t + 1) / 2])
            }
            indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        self.positions = device.makeBuffer(bytes: positions, length: MemoryLayout<SIMD3<Float>>.stride * positions.count)!
        self.normals = device.makeBuffer(bytes: normals, length: MemoryLayout<SIMD3<Float>>.stride * normals.count)!
        self.uvs = device.makeBuffer(bytes: uvs, length: MemoryLayout<SIMD2<Float>>.stride * uvs.count)!
        self.indices = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count)!
        self.indexCount = indices.count

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        textureDescriptor.usage = [.shaderRead]
        texture = device.makeTexture(descriptor: textureDescriptor)!
        texture.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0, withBytes: [UInt8](repeating: 255, count: 64), bytesPerRow: 16)
        sampler = device.makeSamplerState(descriptor: MTLSamplerDescriptor())!

        vertexShader = try VertexShader(source: shaderSource)
        fragmentShader = try FragmentShader(source: shaderSource)
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].bufferIndex = 0
        descriptor.attributes[1].format = .float3
        descriptor.attributes[1].bufferIndex = 1
        descriptor.attributes[2].format = .float2
        descriptor.attributes[2].bufferIndex = 2
        descriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        descriptor.layouts[1].stride = MemoryLayout<SIMD3<Float>>.stride
        descriptor.layouts[2].stride = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor = descriptor
    }
}

struct Item {
    var transform: simd_float4x4
    var material: Material
    var scale: Float
}

func draw(_ item: Item, resources: Resources, halfModifiers: Bool) -> AnyElement {
    let indexBuffer = resources.indices
    let indexCount = resources.indexCount
    let base = Draw { encoder in
        encoder.drawIndexedPrimitives(primitiveType: .triangle, indexCount: indexCount, indexType: .uint16, indexBuffer: indexBuffer.gpuAddress, indexBufferLength: indexBuffer.length)
    }
    .vertexBuffer(resources.positions, index: 0)
    .vertexBuffer(resources.normals, index: 1)
    .vertexBuffer(resources.uvs, index: 2)
    .parameter("transform", value: item.transform)
    .parameter("albedo", texture: resources.texture)
    .parameter("albedoSampler", samplerState: resources.sampler)
    .useResource(indexBuffer, usage: .read, stages: .vertex)
    if halfModifiers {
        // Drops material, scale and depth compare: roughly half the modifier stack.
        return base
            .parameter("material", value: item.material)
            .parameter("scale", value: item.scale)
            .eraseToAnyElement()
    }
    return base
        .parameter("material", value: item.material)
        .parameter("scale", value: item.scale)
        .depthCompare(function: .less, enabled: true)
        .depthStencilDescriptor(.init(depthCompareFunction: .less, isDepthWriteEnabled: true))
        .eraseToAnyElement()
}

func draws(_ items: [Item], resources: Resources, options: Options) throws -> AnyElement {
    if options.flat {
        return ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            draw(item, resources: resources, halfModifiers: options.halfModifiers)
        }
        .eraseToAnyElement()
    }
    let groups = stride(from: 0, to: items.count, by: 8).map { Array(items[$0 ..< min($0 + 8, items.count)]) }
    return ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
        try Group {
            ForEach(Array(group.enumerated()), id: \.offset) { _, item in
                draw(item, resources: resources, halfModifiers: options.halfModifiers)
            }
        }
        .eraseToAnyElement()
    }
    .eraseToAnyElement()
}

func root(_ items: [Item], resources: Resources, options: Options) throws -> some Element {
    try Group {
        // Pre-pass with the same draws, standing in for the offscreen pass in the original report.
        try RenderPass {
            try RenderPipeline(vertexShader: resources.vertexShader, fragmentShader: resources.fragmentShader) {
                try draws(items, resources: resources, options: options)
            }
            .vertexDescriptor(resources.vertexDescriptor)
        }
        try RenderPass {
            try RenderPipeline(vertexShader: resources.vertexShader, fragmentShader: resources.fragmentShader) {
                try draws(items, resources: resources, options: options)
            }
            .vertexDescriptor(resources.vertexDescriptor)
        }
    }
}

func makeItems(count: Int, frame: Int) -> [Item] {
    (0 ..< count).map { index in
        let angle = Float(frame) * 0.01 + Float(index)
        var transform = matrix_identity_float4x4
        transform.columns.3 = [sin(angle) * 0.8, cos(angle) * 0.8, 0.5, 1]
        transform.columns.0.x = 0.05
        transform.columns.1.y = 0.05
        transform.columns.2.z = 0.05
        return Item(transform: transform, material: Material(tint: [1, 0.5, 0.25, 1], roughness: 0.5), scale: 1)
    }
}

func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    return sorted[sorted.count / 2]
}

let options = Options(arguments: CommandLine.arguments)
let device = MTLCreateSystemDefaultDevice()!
let resources = try Resources(device: device)
let renderer = try OffscreenRenderer(size: CGSize(width: 1280, height: 800), device: device)

#if DEBUG
let configuration = "debug"
#else
let configuration = "release"
#endif
print("# config=\(configuration) frames=\(options.frames) halfModifiers=\(options.halfModifiers) flat=\(options.flat)")
print("drawsPerPass,totalDraws,medianFrameMs,minFrameMs,medianMsPerDraw,medianGpuMs")

for count in options.counts {
    var frameTimes: [Double] = []
    var gpuTimes: [Double] = []
    // A few warm-up frames so first-frame pipeline creation is not counted.
    for frame in 0 ..< (options.frames + 3) {
        let start = ContinuousClock.now
        let rendering = try renderer.render(try root(makeItems(count: count, frame: frame), resources: resources, options: options))
        let elapsed = ContinuousClock.now - start
        guard frame >= 3 else { continue }
        frameTimes.append(Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000)
        gpuTimes.append((rendering.gpuTime ?? 0) * 1000)
    }
    let medianMs = median(frameTimes)
    let totalDraws = count * 2
    print(String(format: "%d,%d,%.3f,%.3f,%.4f,%.3f", count, totalDraws, medianMs, frameTimes.min()!, medianMs / Double(totalDraws), median(gpuTimes)))
}
