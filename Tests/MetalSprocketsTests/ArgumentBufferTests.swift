import Metal
@testable import MetalSprockets
import simd
import Testing

// #579: long-lived argument buffers filled by field name from pipeline reflection, bound with one address.
@MainActor
@Suite(.requiresMetal4)
struct ArgumentBufferTests {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct Material {
        float4 tint;
        texture2d<float> color;
        sampler colorSampler;
        array<texture2d<float>, 2> extras;
        constant float4 *data;
    };
    struct VertexOut { float4 position [[position]]; uint instance [[flat]]; };
    // Instance 0 covers the left half, instance 1 the right half.
    [[vertex]] VertexOut vertex_main(uint vertexID [[vertex_id]], uint instance [[instance_id]]) {
        float2 corners[6] = { {0, -1}, {1, -1}, {0, 1}, {0, 1}, {1, -1}, {1, 1} };
        VertexOut out;
        out.position = float4(corners[vertexID].x - 1 + float(instance), corners[vertexID].y, 0, 1);
        out.instance = instance;
        return out;
    }
    [[fragment]] float4 sample_material(VertexOut in [[stage_in]], constant Material &material [[buffer(0)]]) {
        return material.tint * material.color.sample(material.colorSampler, float2(0.5));
    }
    [[fragment]] float4 sample_materials(VertexOut in [[stage_in]], constant Material *materials [[buffer(0)]]) {
        constant Material &material = materials[in.instance];
        return material.tint * material.color.sample(material.colorSampler, float2(0.5));
    }
    [[fragment]] float4 read_pointer(VertexOut in [[stage_in]], constant Material &material [[buffer(0)]]) {
        return material.data[1] + material.extras[1].sample(material.colorSampler, float2(0.5));
    }
    [[fragment]] float4 plain_value(VertexOut in [[stage_in]], constant float4 &color [[buffer(0)]]) {
        return color;
    }
    """

    private let device: any MTLDevice
    private let library: any MTLLibrary
    private let sampler: any MTLSamplerState

    init() throws {
        device = try #require(MTLCreateSystemDefaultDevice())
        library = try device.makeLibrary(source: Self.source, options: nil)
        let descriptor = MTLSamplerDescriptor()
        descriptor.supportArgumentBuffers = true
        sampler = try #require(device.makeSamplerState(descriptor: descriptor))
    }

    private func texture(_ bgra: [UInt8]) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false)
        descriptor.storageMode = .shared
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: bgra, bytesPerRow: 4)
        return texture
    }

    private func scene(fragment: String, instances: Int = 2, argumentBuffer: ArgumentBuffer) throws -> some Element {
        try RenderPipeline(vertexShader: VertexShader(library: library, name: "vertex_main"), fragmentShader: FragmentShader(library: library, name: fragment)) {
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instances) }
                .parameter(fragment == "sample_materials" ? "materials" : "material", argumentBuffer: argumentBuffer)
        }
    }

    // BGRA bytes at the left and right quarter points.
    private func render(_ element: some Element) async throws -> (left: [UInt8], right: [UInt8]) {
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm)
        let texture = try await renderer.render(element).texture
        func pixel(_ x: Int) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 4)
            texture.getBytes(&bytes, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(x, 32, 1, 1), mipmapLevel: 0)
            return bytes
        }
        return (pixel(16), pixel(48))
    }

    @Test
    func layoutComesFromReflection() throws {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        descriptor.fragmentFunction = library.makeFunction(name: "sample_material")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        var reflection: MTLRenderPipelineReflection?
        _ = try device.makeRenderPipelineState(descriptor: descriptor, options: [.bindingInfo, .bufferTypeInfo], reflection: &reflection)
        let binding = try #require(reflection?.fragmentBindings.first { $0.name == "material" } as? any MTLBufferBinding)
        let layout = try #require(ArgumentBufferLayout(binding))
        #expect(layout.stride == 64)
        #expect(layout.fields["tint"] == .init(offset: 0, span: 16, kind: .bytes))
        #expect(layout.fields["color"] == .init(offset: 16, span: 8, kind: .texture))
        #expect(layout.fields["colorSampler"] == .init(offset: 24, span: 8, kind: .sampler))
        #expect(layout.fields["extras"] == .init(offset: 32, span: 16, kind: .textures(count: 2)))
        #expect(layout.fields["data"] == .init(offset: 48, span: 16, kind: .pointer))
    }

    @Test(.timeLimit(.minutes(1)))
    func shaderReadsFieldsSetByName() async throws {
        let material = ArgumentBuffer(device: device, label: "Material")
        material.set("tint", value: SIMD4<Float>(1, 1, 1, 1))
        material.set("color", texture: try texture([0, 0, 255, 255]))
        material.set("colorSampler", samplerState: sampler)
        let pixels = try await render(scene(fragment: "sample_material", argumentBuffer: material))
        #expect(pixels.left == [0, 0, 255, 255])
        #expect(pixels.right == [0, 0, 255, 255])
    }

    @Test(.timeLimit(.minutes(1)))
    func changesShowTheNextTimeTheBufferIsBound() async throws {
        let material = ArgumentBuffer(device: device)
        material.set("tint", value: SIMD4<Float>(1, 1, 1, 1))
        material.set("color", texture: try texture([0, 0, 255, 255]))
        material.set("colorSampler", samplerState: sampler)
        #expect(try await render(scene(fragment: "sample_material", argumentBuffer: material)).left == [0, 0, 255, 255])
        material.set("color", texture: try texture([0, 255, 0, 255]))
        #expect(try await render(scene(fragment: "sample_material", argumentBuffer: material)).left == [0, 255, 0, 255])
        material.set("tint", value: SIMD4<Float>(0, 0, 0, 1))
        #expect(try await render(scene(fragment: "sample_material", argumentBuffer: material)).left == [0, 0, 0, 255])
    }

    // Bindless: one draw, each instance reads its own element's texture.
    @Test(.timeLimit(.minutes(1)))
    func eachInstanceReadsItsOwnElement() async throws {
        let materials = ArgumentBuffer(device: device, count: 2)
        for (element, color) in [[0, 0, 255, 255], [255, 0, 0, 255]].enumerated() {
            materials.set("tint", value: SIMD4<Float>(1, 1, 1, 1), element: element)
            materials.set("color", texture: try texture(color.map(UInt8.init)), element: element)
            materials.set("colorSampler", samplerState: sampler, element: element)
        }
        let pixels = try await render(scene(fragment: "sample_materials", argumentBuffer: materials))
        #expect(pixels.left == [0, 0, 255, 255])
        #expect(pixels.right == [255, 0, 0, 255])
    }

    // Commands in an indirect command buffer inherit the argument buffer and reach per-instance textures through it.
    @Test(.timeLimit(.minutes(1)))
    func indirectCommandsReachTexturesThroughTheArgumentBuffer() async throws {
        let materials = ArgumentBuffer(device: device, count: 2)
        for (element, color) in [[0, 255, 0, 255], [255, 0, 0, 255]].enumerated() {
            materials.set("tint", value: SIMD4<Float>(1, 1, 1, 1), element: element)
            materials.set("color", texture: try texture(color.map(UInt8.init)), element: element)
            materials.set("colorSampler", samplerState: sampler, element: element)
        }
        let commands = try device.makeRenderIndirectCommandBuffer(commandTypes: .draw, maxCommandCount: 1, options: .storageModeShared)
        commands.indirectRenderCommandAt(0).drawPrimitives(.triangle, vertexStart: 0, vertexCount: 6, instanceCount: 2, baseInstance: 0)
        let element = try RenderPipeline(vertexShader: VertexShader(library: library, name: "vertex_main"), fragmentShader: FragmentShader(library: library, name: "sample_materials")) {
            Draw(indirectCommandBuffer: commands, range: 0 ..< 1)
                .parameter("materials", argumentBuffer: materials)
        }
        .supportsIndirectCommandBuffers()
        let pixels = try await render(element)
        #expect(pixels.left == [0, 255, 0, 255])
        #expect(pixels.right == [255, 0, 0, 255])
    }

    @Test(.timeLimit(.minutes(1)))
    func pointerAndTextureArrayFields() async throws {
        let values: [SIMD4<Float>] = [[1, 1, 1, 1], [0, 0, 1, 0]]
        let data = try #require(device.makeBuffer(bytes: values, length: MemoryLayout<SIMD4<Float>>.stride * 2, options: .storageModeShared))
        let material = ArgumentBuffer(device: device)
        material.set("data", buffer: data)
        material.set("extras", textures: [try texture([0, 0, 0, 0]), try texture([0, 255, 0, 255])])
        material.set("colorSampler", samplerState: sampler)
        // Blue from the pointed-to buffer plus green from the second array texture.
        #expect(try await render(scene(fragment: "read_pointer", argumentBuffer: material)).left == [255, 255, 0, 255])
    }

    @Test(.timeLimit(.minutes(1)))
    func mistakesAreReportedByName() async throws {
        let unknown = ArgumentBuffer(device: device)
        unknown.set("colour", texture: try texture([0, 0, 0, 255]))
        await #expect(throws: ArgumentBuffer.Failure.unknownField(name: "colour", available: ["color", "colorSampler", "data", "extras", "tint"])) {
            _ = try await render(scene(fragment: "sample_material", argumentBuffer: unknown))
        }

        let wrongKind = ArgumentBuffer(device: device)
        wrongKind.set("tint", texture: try texture([0, 0, 0, 255]))
        await #expect(throws: ArgumentBuffer.Failure.kindMismatch(name: "tint")) {
            _ = try await render(scene(fragment: "sample_material", argumentBuffer: wrongKind))
        }

        let tooLarge = ArgumentBuffer(device: device)
        tooLarge.set("tint", value: simd_float4x4(1))
        await #expect(throws: ArgumentBuffer.Failure.valueTooLarge(name: "tint", size: 64, span: 16)) {
            _ = try await render(scene(fragment: "sample_material", argumentBuffer: tooLarge))
        }

        let outOfRange = ArgumentBuffer(device: device)
        outOfRange.set("tint", value: SIMD4<Float>(1, 1, 1, 1), element: 1)
        await #expect(throws: ArgumentBuffer.Failure.elementOutOfRange(element: 1, count: 1)) {
            _ = try await render(scene(fragment: "sample_material", argumentBuffer: outOfRange))
        }

        let notAStruct = ArgumentBuffer(device: device)
        let plain = try RenderPipeline(vertexShader: VertexShader(library: library, name: "vertex_main"), fragmentShader: FragmentShader(library: library, name: "plain_value")) {
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 6) }
                .parameter("color", argumentBuffer: notAStruct)
        }
        await #expect(throws: ArgumentBuffer.Failure.notAnArgumentBuffer("color")) {
            _ = try await render(plain)
        }
    }

    // The buffer and everything its fields point to are kept alive with the contents a draw was encoded with.
    @Test
    func versionsKeepTheirResources() throws {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        descriptor.fragmentFunction = library.makeFunction(name: "read_pointer")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        var reflection: MTLRenderPipelineReflection?
        _ = try device.makeRenderPipelineState(descriptor: descriptor, options: [.bindingInfo, .bufferTypeInfo], reflection: &reflection)
        let binding = try #require(reflection?.fragmentBindings.first { $0.name == "material" } as? any MTLBufferBinding)
        let layout = try #require(ArgumentBufferLayout(binding))

        let first = try texture([0, 0, 0, 255])
        let data = try #require(device.makeBuffer(length: 32, options: .storageModeShared))
        let material = ArgumentBuffer(device: device)
        material.set("color", texture: first)
        material.set("data", buffer: data)
        material.set("colorSampler", samplerState: sampler)
        let version = try material.version(for: layout, bindingName: "material")
        #expect(try material.version(for: layout, bindingName: "material") === version)
        #expect(version.allocations.contains { $0 === first })
        #expect(version.allocations.contains { $0 === data })
        #expect(version.allocations.contains { $0 === version.buffer })
        #expect(version.objects.contains { $0 === sampler })

        let second = try texture([0, 0, 0, 255])
        material.set("color", texture: second)
        let next = try material.version(for: layout, bindingName: "material")
        #expect(next !== version)
        #expect(next.buffer !== version.buffer)
        #expect(next.allocations.contains { $0 === second })
        #expect(version.buffer.contents().load(fromByteOffset: 16, as: UInt64.self) == first.gpuResourceID._impl)
        #expect(next.buffer.contents().load(fromByteOffset: 16, as: UInt64.self) == second.gpuResourceID._impl)
        // Unchanged fields carry over from the previous version.
        #expect(!next.allocations.contains { $0 === first })
        #expect(next.allocations.contains { $0 === data })
        #expect(next.allocations.contains { $0 === next.buffer })
        #expect(!next.allocations.contains { $0 === version.buffer })
        #expect(next.objects.contains { $0 === sampler })
        let otherBytes = (0..<layout.stride).filter { !(16..<24).contains($0) }
        for offset in otherBytes {
            #expect(next.buffer.contents().load(fromByteOffset: offset, as: UInt8.self) == version.buffer.contents().load(fromByteOffset: offset, as: UInt8.self))
        }
    }
}
