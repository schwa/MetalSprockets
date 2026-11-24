import CoreGraphics
import Metal
@testable import MetalSprockets
import simd
import Testing

@MainActor
@Suite("DrawList")
struct DrawListTests {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float4 color;
    };

    [[vertex]] VertexOut vertex_main(uint vertex_id [[vertex_id]], uint instance [[instance_id]], constant float2 *positions [[buffer(0)]], constant float4 *colors [[buffer(1)]]) {
        VertexOut out;
        out.position = float4(positions[vertex_id], 0, 1);
        out.color = colors[instance];
        return out;
    }

    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) {
        return in.color;
    }
    """

    // Left half quad (vertices 0..<6), right half quad (vertices 6..<10, indexed), full-screen triangle (10..<13).
    static let positions: [SIMD2<Float>] = [
        [-1, -1], [0, -1], [0, 1], [-1, -1], [0, 1], [-1, 1],
        [0, -1], [1, -1], [1, 1], [0, 1],
        [-1, -1], [3, -1], [-1, 3]
    ]
    static let colors: [SIMD4<Float>] = [[1, 0, 0, 1], [0, 1, 0, 1], [0, 0, 1, 1]]

    private func render(_ rows: [DrawRow], cachesCommands: Bool = false) async throws -> (left: [UInt8], right: [UInt8]) {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let indices: [UInt16] = [0, 1, 2, 0, 2, 3]
        let indexBuffer = try #require(device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count))
        let element = try RenderPipeline(vertexShader: VertexShader(source: Self.source), fragmentShader: FragmentShader(source: Self.source)) {
            DrawList(indexBuffer: indexBuffer, indexType: .uint16, cachesCommands: cachesCommands, rows: rows)
                .parameter("positions", values: Self.positions)
                .parameter("colors", values: Self.colors)
        }
        .supportsIndirectCommandBuffers()
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm)
        let texture = try await renderer.render(element).texture
        func pixel(_ x: Int) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 4)
            texture.getBytes(&bytes, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(x, 32, 1, 1), mipmapLevel: 0)
            return bytes
        }
        return (pixel(16), pixel(48))
    }

    @Test(.requiresMetal4, arguments: [false, true]) func `rows pick per-draw data by base instance`(cachesCommands: Bool) async throws {
        let pixels = try await render([
            DrawRow(geometry: .vertices(0..<6), instances: 0..<1),
            DrawRow(geometry: .indexed(0..<6, baseVertex: 6), instances: 1..<2)
        ], cachesCommands: cachesCommands)
        #expect(pixels.left == [0, 0, 255, 255])
        #expect(pixels.right == [0, 255, 0, 255])
    }

    @Test(.requiresMetal4, arguments: [false, true]) func `cull mode and winding apply per row`(cachesCommands: Bool) async throws {
        // The full-screen triangle is counter-clockwise, so a clockwise front face culls it as a back face.
        let culled = try await render([
            DrawRow(geometry: .vertices(0..<6), instances: 0..<1),
            DrawRow(geometry: .vertices(10..<13), instances: 2..<3, cullMode: .back, winding: .clockwise)
        ], cachesCommands: cachesCommands)
        #expect(culled.left == [0, 0, 255, 255])
        let drawn = try await render([
            DrawRow(geometry: .vertices(0..<6), instances: 0..<1),
            DrawRow(geometry: .vertices(10..<13), instances: 2..<3, cullMode: .back, winding: .counterClockwise)
        ], cachesCommands: cachesCommands)
        #expect(drawn.left == [255, 0, 0, 255])
    }

    @Test(.requiresMetal4) func `command cache re-encodes only when rows change`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let cache = DrawListCommandCache()
        let rows = [
            DrawRow(geometry: .vertices(0..<3), cullMode: .back),
            DrawRow(geometry: .vertices(3..<6), cullMode: .back),
            DrawRow(geometry: .vertices(6..<6)),
            DrawRow(geometry: .vertices(6..<9), cullMode: .none)
        ]
        let first = try cache.commands(device: device, rows: rows, indexBuffer: nil, indexType: .uint32)
        let second = try cache.commands(device: device, rows: rows, indexBuffer: nil, indexType: .uint32)
        #expect(cache.encodeCount == 1)
        #expect(first.buffer === second.buffer)
        #expect(first.segments.map(\.range) == [0..<2, 2..<3])
        _ = try cache.commands(device: device, rows: Array(rows.prefix(1)), indexBuffer: nil, indexType: .uint32)
        #expect(cache.encodeCount == 2)
    }

    static let amplifiedSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float4 color;
    };

    [[vertex]] VertexOut amplified_vertex(uint vertex_id [[vertex_id]], ushort view [[amplification_id]], constant float2 *positions [[buffer(0)]]) {
        VertexOut out;
        out.position = float4(positions[vertex_id], 0, 1);
        out.color = view == 0 ? float4(1, 0, 0, 1) : float4(0, 1, 0, 1);
        return out;
    }

    [[fragment]] float4 amplified_fragment(VertexOut in [[stage_in]]) {
        return in.color;
    }
    """

    @Test(.requiresMetal4) func `stereo views draw every row to each view`() async throws {
        let left = MTLViewport(originX: 0, originY: 0, width: 32, height: 64, znear: 0, zfar: 1)
        let right = MTLViewport(originX: 32, originY: 0, width: 32, height: 64, znear: 0, zfar: 1)
        let views = StereoViews(viewMatrices: [matrix_identity_float4x4, matrix_identity_float4x4], projectionMatrices: [matrix_identity_float4x4, matrix_identity_float4x4], viewports: [left, right])
        let element = try RenderPipeline(vertexShader: VertexShader(source: Self.amplifiedSource), fragmentShader: FragmentShader(source: Self.amplifiedSource)) {
            DrawList(stereoViews: views, rows: [DrawRow(geometry: .vertices(10..<13))])
                .parameter("positions", values: Self.positions)
        }
        .vertexAmplification(count: 2)
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm)
        let texture = try await renderer.render(element).texture
        func pixel(_ x: Int) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 4)
            texture.getBytes(&bytes, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(x, 32, 1, 1), mipmapLevel: 0)
            return bytes
        }
        #expect(pixel(16) == [0, 0, 255, 255])
        #expect(pixel(48) == [0, 255, 0, 255])
    }

    @Test func `culling keeps rows inside any frustum and rows without bounds`() {
        func row(_ instance: Int, _ bounds: DrawRow.Bounds?) -> DrawRow {
            DrawRow(geometry: .vertices(0..<3), instances: instance..<instance + 1, bounds: bounds)
        }
        var shifted = matrix_identity_float4x4
        shifted.columns.3 = [-4, 0, 0, 1]
        let rows = [
            row(0, DrawRow.Bounds(min: [-0.5, -0.5, 0.2], max: [0.5, 0.5, 0.4])),
            row(1, DrawRow.Bounds(min: [1.5, -0.5, 0.2], max: [2.5, 0.5, 0.4])),
            row(2, DrawRow.Bounds(min: [3.5, -0.5, 0.2], max: [4.5, 0.5, 0.4])),
            row(3, DrawRow.Bounds(min: [-0.5, -0.5, 2], max: [0.5, 0.5, 3])),
            row(4, nil)
        ]
        let identity = DrawList(cullingViewProjections: [matrix_identity_float4x4], rows: rows)
        #expect(identity.visibleRows.map(\.instances.lowerBound) == [0, 4])
        let both = DrawList(cullingViewProjections: [matrix_identity_float4x4, shifted], rows: rows)
        #expect(both.visibleRows.map(\.instances.lowerBound) == [0, 2, 4])
        #expect(DrawList(rows: rows).visibleRows.count == 5)
    }

    @Test(.requiresMetal4) func `culled rows are not drawn`() async throws {
        let outside = DrawRow.Bounds(min: [2, 2, 0.5], max: [3, 3, 0.5])
        let element = try RenderPipeline(vertexShader: VertexShader(source: Self.source), fragmentShader: FragmentShader(source: Self.source)) {
            DrawList(cullingViewProjections: [matrix_identity_float4x4], rows: [
                DrawRow(geometry: .vertices(0..<6), instances: 0..<1),
                DrawRow(geometry: .vertices(10..<13), instances: 2..<3, bounds: outside)
            ])
            .parameter("positions", values: Self.positions)
            .parameter("colors", values: Self.colors)
        }
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 64, height: 64), pixelFormat: .bgra8Unorm)
        let texture = try await renderer.render(element).texture
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&bytes, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(16, 32, 1, 1), mipmapLevel: 0)
        #expect(bytes == [0, 0, 255, 255])
    }

    @Test(.requiresMetal4) func `indexed rows without an index buffer throw`() async throws {
        let element = try RenderPipeline(vertexShader: VertexShader(source: Self.source), fragmentShader: FragmentShader(source: Self.source)) {
            DrawList(rows: [DrawRow(geometry: .indexed(0..<3))])
                .parameter("positions", values: Self.positions)
                .parameter("colors", values: Self.colors)
        }
        let renderer = try TestOffscreenRenderer(size: CGSize(width: 8, height: 8), pixelFormat: .bgra8Unorm)
        await #expect(throws: (any Error).self) {
            _ = try await renderer.render(element)
        }
    }
}
