import CoreGraphics
import Metal
@testable import MetalSprockets
import Testing

/// Render pipelines binary-link functions that come from other libraries and from stitched libraries (#546).
/// Run these under `MTL_DEBUG_LAYER=1` and `MTL_CAPTURE_ENABLED=1` too (Scripts/test-metal-layers.sh).
@MainActor
@Suite("Render binary linking", .requiresMetal4)
struct RenderBinaryLinkingTests {
    private let device = MTLCreateSystemDefaultDevice()!

    private static let hostSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };

    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    using ColorFn = float4();

    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]], visible_function_table<ColorFn> colorTable [[buffer(0)]]) {
        return colorTable[0]();
    }
    """

    private static let visibleSource = """
    #include <metal_stdlib>
    using namespace metal;
    [[visible]] float4 green_visible() { return float4(0.0, 1.0, 0.0, 1.0); }
    """

    private static let stitchableSource = """
    #include <metal_stdlib>
    using namespace metal;
    [[stitchable]] float4 make_blue() { return float4(0.0, 0.0, 1.0, 1.0); }
    """

    private func centerPixel(linking function: VisibleFunction) async throws -> [UInt8] {
        let host = try await device.makeLibrary(source: Self.hostSource, options: nil)
        let vertex = try VertexShader(library: host, name: "vertex_main")
        let fragment = try FragmentShader(library: host, name: "fragment_main")
        let vertices: [SIMD2<Float>] = [[-1, -1], [3, -1], [-1, 3]]
        let buffer = try #require(device.makeBuffer(bytes: vertices, length: MemoryLayout<SIMD2<Float>>.stride * vertices.count, options: .storageModeShared))
        let content = try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                .vertexBuffer(buffer, index: 0)
                .visibleFunctionTable("colorTable", functionType: .fragment, functions: [function])
        }
        .vertexDescriptor(vertex.inferredVertexDescriptor())
        .linkedFunctions([function])
        let image = try await TestOffscreenRenderer(size: CGSize(width: 8, height: 8)).render(content).cgImage
        return try Self.pixel(of: image, x: 4, y: 4)
    }

    private static func pixel(of image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return bytes
    }

    @Test(.timeLimit(.minutes(1)))
    func functionFromAnotherLibrary() async throws {
        let library = try await device.makeLibrary(source: Self.visibleSource, options: nil)
        let green = try VisibleFunction(library: library, name: "green_visible")
        #expect(try await centerPixel(linking: green) == [0, 255, 0, 255])
    }

    @Test(.timeLimit(.minutes(1)))
    func stitchedFunction() async throws {
        let source = try await device.makeLibrary(source: Self.stitchableSource, options: nil)
        let makeBlue = try #require(source.makeFunction(name: "make_blue"))
        let node = MTLFunctionStitchingFunctionNode(name: "make_blue", arguments: [], controlDependencies: [])
        let descriptor = MTLStitchedLibraryDescriptor()
        descriptor.functionGraphs = [MTLFunctionStitchingGraph(functionName: "stitched_blue", nodes: [], outputNode: node, attributes: [])]
        descriptor.functions = [makeBlue]
        let stitched = try await device.makeLibrary(stitchedDescriptor: descriptor)
        let blue = try VisibleFunction(library: stitched, name: "stitched_blue")
        #expect(try await centerPixel(linking: blue) == [0, 0, 255, 255])
    }

    // Shows the tests above take the binary path: both functions extend one base pipeline instead of each compiling one.
    @Test(.disabledUnderCapture("Binary linking is off under GPU frame capture (#542)"))
    func bothFunctionKindsExtendOneBasePipeline() async throws {
        let host = try await device.makeLibrary(source: Self.hostSource, options: nil)
        let vertex = try VertexShader(library: host, name: "vertex_main")
        let fragment = try FragmentShader(library: host, name: "fragment_main")
        let green = try VisibleFunction(library: try await device.makeLibrary(source: Self.visibleSource, options: nil), name: "green_visible")
        let source = try await device.makeLibrary(source: Self.stitchableSource, options: nil)
        let descriptor = MTLStitchedLibraryDescriptor()
        descriptor.functionGraphs = [MTLFunctionStitchingGraph(functionName: "stitched_blue", nodes: [], outputNode: MTLFunctionStitchingFunctionNode(name: "make_blue", arguments: [], controlDependencies: []), attributes: [])]
        descriptor.functions = [try #require(source.makeFunction(name: "make_blue"))]
        let blue = try VisibleFunction(library: try await device.makeLibrary(stitchedDescriptor: descriptor), name: "stitched_blue")
        let context = try MetalContext(device: device)
        for function in [green, blue] {
            let configuration = RenderPipelineConfiguration(vertex: vertex, fragment: fragment, colorPixelFormats: [.bgra8Unorm], vertexDescriptor: vertex.inferredVertexDescriptor(), fragmentLinkedFunctions: [function])
            _ = try context.pipelines.renderPipeline(configuration)
        }
        #expect(context.pipelines.compilationCount == 1)
    }
}
