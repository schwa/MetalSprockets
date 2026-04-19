import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

// Helper: set MTLLinkedFunctions via the environment, matching the pattern used
// in the MetalSprocketsShaderGraph demo.
private extension Element {
    func linkedFunctions(_ functions: [MTLFunction]) -> some Element {
        let linked = MTLLinkedFunctions()
        linked.functions = functions
        return environment(\.linkedFunctions, linked)
    }
}

@MainActor
@Suite("VisibleFunctionTable Tests")
struct VisibleFunctionTableTests {
    // A shader with a visible_function_table<float4()> bound in the fragment stage.
    // `red_visible` and `green_visible` are [[visible]] functions that can be plugged
    // into the table at index 0.
    static let fragmentTableSource = """
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

    [[visible]] float4 red_visible() { return float4(1.0, 0.0, 0.0, 1.0); }
    [[visible]] float4 green_visible() { return float4(0.0, 1.0, 0.0, 1.0); }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        visible_function_table<ColorFn> colorTable [[buffer(0)]]
    ) {
        return colorTable[0]();
    }
    """

    // Same shader but the visible_function_table is in the vertex stage — lets us
    // exercise the `.vertex` auto-resolve and `setVertexVisibleFunctionTable` branch.
    static let vertexTableSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; float4 color; };

    using ColorFn = float4();

    [[visible]] float4 blue_visible() { return float4(0.0, 0.0, 1.0, 1.0); }

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]],
        visible_function_table<ColorFn> vertexColorTable [[buffer(1)]]
    ) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        out.color = vertexColorTable[0]();
        return out;
    }

    [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) {
        return in.color;
    }
    """

    @Test("Fragment visible function table renders")
    func testFragmentVisibleFunctionTable() throws {
        let device = MTLCreateSystemDefaultDevice()!
        // Visible function tables need Apple GPU Family 7+.
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let redVisible = library.makeFunction(name: "red_visible")!

        // `.visibleFunctionTable` attaches to Draw (inside RenderPipeline).
        // `.linkedFunctions` (local helper above) sets MTLLinkedFunctions via env.
        let element = try RenderPass {
            let vs = VertexShader(library.makeFunction(name: "vertex_main")!)
            let fs = FragmentShader(library.makeFunction(name: "fragment_main")!)
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .visibleFunctionTable("colorTable", function: redVisible)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([redVisible])
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(element)
    }

    @Test("Explicit .fragment functionType resolves")
    func testExplicitFragmentFunctionType() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let redVisible = library.makeFunction(name: "red_visible")!
        let greenVisible = library.makeFunction(name: "green_visible")!

        let element = try RenderPass {
            let vs = VertexShader(library.makeFunction(name: "vertex_main")!)
            let fs = FragmentShader(library.makeFunction(name: "fragment_main")!)
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                // Explicitly target fragment stage + multi-function variant.
                .visibleFunctionTable("colorTable", functionType: .fragment, functions: [redVisible, greenVisible])
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([redVisible, greenVisible])
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(element)
    }

    @Test("Vertex visible function table renders")
    func testVertexVisibleFunctionTable() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.vertexTableSource, options: nil)
        let blueVisible = library.makeFunction(name: "blue_visible")!

        let element = try RenderPass {
            let vs = VertexShader(library.makeFunction(name: "vertex_main")!)
            let fs = FragmentShader(library.makeFunction(name: "fragment_main")!)
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                // Table is in the vertex shader; let auto-detection pick .vertex.
                .visibleFunctionTable("vertexColorTable", function: blueVisible)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([blueVisible])
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64))
        _ = try renderer.render(element)
    }

    @Test("requiresSetup tracks name + functions")
    func testRequiresSetup() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let red = library.makeFunction(name: "red_visible")!
        let green = library.makeFunction(name: "green_visible")!

        struct Leaf: Element, BodylessElement { var body: Never { fatalError() } }

        let a = VisibleFunctionTableModifier(name: "t", functions: [red], functionType: nil, content: Leaf())
        let aSame = VisibleFunctionTableModifier(name: "t", functions: [red], functionType: nil, content: Leaf())
        let diffName = VisibleFunctionTableModifier(name: "other", functions: [red], functionType: nil, content: Leaf())
        let diffCount = VisibleFunctionTableModifier(name: "t", functions: [red, green], functionType: nil, content: Leaf())
        let diffFunction = VisibleFunctionTableModifier(name: "t", functions: [green], functionType: nil, content: Leaf())

        #expect(a.requiresSetup(comparedTo: aSame) == false)
        #expect(a.requiresSetup(comparedTo: diffName) == true)
        #expect(a.requiresSetup(comparedTo: diffCount) == true)
        #expect(a.requiresSetup(comparedTo: diffFunction) == true)
    }
}
