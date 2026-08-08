import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

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

    // A shader whose visible_function_table name is bound in *both* stages, so auto-detection has two matches
    // and has to ask for an explicit function type.
    static let ambiguousTableSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; float4 color; };

    using ColorFn = float4();

    [[visible]] float4 white_visible() { return float4(1.0, 1.0, 1.0, 1.0); }

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]],
        visible_function_table<ColorFn> colorTable [[buffer(1)]]
    ) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        out.color = colorTable[0]();
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        visible_function_table<ColorFn> colorTable [[buffer(0)]]
    ) {
        return in.color * colorTable[0]();
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
        // The table's only entry returns red, so the triangle has to come out red — not merely render without
        // throwing.
        try Golden.verify(element, named: "VisibleFunctionTableRed")
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
        // Two functions are in the table but the shader calls index 0, so red wins and green is not drawn.
        try Golden.verify(element, named: "VisibleFunctionTableRed")
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
        // The colour is produced in the *vertex* stage and interpolated, so a blue triangle proves the table was
        // bound with setVertexVisibleFunctionTable and not silently ignored.
        try Golden.verify(element, named: "VisibleFunctionTableBlue")
    }

    // A compute kernel with a visible_function_table<uint(uint)> in buffer(1).
    // `plus_one` is a [[visible]] function that can be plugged into the table.
    static let computeTableSource = """
    #include <metal_stdlib>
    using namespace metal;

    using TransformFn = uint(uint);

    [[visible]] uint plus_one(uint v) { return v + 1; }
    [[visible]] uint times_two(uint v) { return v * 2; }

    kernel void compute_main(
        device uint *out [[buffer(0)]],
        visible_function_table<TransformFn> transforms [[buffer(1)]],
        uint tid [[thread_position_in_grid]]
    ) {
        out[tid] = transforms[0](tid);
    }
    """

    @Test("Compute visible function table dispatches")
    func testComputeVisibleFunctionTable() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.computeTableSource, options: nil)
        let plusOne = library.makeFunction(name: "plus_one")!

        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        let kernel = ComputeKernel(library.makeFunction(name: "compute_main")!)

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        let encoder = node.environmentValues.computeCommandEncoder!
                        encoder.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(
                    threadsPerGrid: MTLSize(width: count, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
                )
                .visibleFunctionTable("transforms", function: plusOne)
            }
            .environment(\.linkedFunctions, {
                let lf = MTLLinkedFunctions()
                lf.functions = [plusOne]
                return lf
            }())
        }
        .run()

        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for i in 0..<count {
            #expect(ptr[i] == UInt32(i) + 1)
        }
    }

    @Test("Compute visible function table with explicit .kernel functionType")
    func testComputeVisibleFunctionTableExplicitKernel() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.computeTableSource, options: nil)
        let timesTwo = library.makeFunction(name: "times_two")!

        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        let kernel = ComputeKernel(library.makeFunction(name: "compute_main")!)

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                AnyBodylessElement()
                    .onWorkloadEnter { (node: Node) in
                        let encoder = node.environmentValues.computeCommandEncoder!
                        encoder.setBuffer(buffer, offset: 0, index: 0)
                    }
                try ComputeDispatch(
                    threadsPerGrid: MTLSize(width: count, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
                )
                .visibleFunctionTable("transforms", functionType: .kernel, functions: [timesTwo])
            }
            .environment(\.linkedFunctions, {
                let lf = MTLLinkedFunctions()
                lf.functions = [timesTwo]
                return lf
            }())
        }
        .run()

        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for i in 0..<count {
            #expect(ptr[i] == UInt32(i) * 2)
        }
    }

    @Test("Setup before any pipeline has published reflection is a no-op")
    func testSetupWithoutReflection() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let red = try #require(library.makeFunction(name: "red_visible"))

        struct Leaf: Element, BodylessElement { var body: Never { fatalError() } }

        // No enclosing pipeline, so there is no reflection yet. Setup has to leave the table for later rather than
        // failing. Only the setup phase runs here: no encoder is ever created.
        let system = System()
        try system.update(root: VisibleFunctionTableModifier(name: "table", functions: [red], functionType: nil, content: Leaf()))
        try system.processSetup()
    }

    @Test("A function type the pipeline cannot serve is rejected during setup")
    func testInvalidFunctionTypeForPipeline() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7), device.supportsFunctionPointers else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let red = try #require(library.makeFunction(name: "red_visible"))

        // A render pipeline cannot serve a `.kernel` table. The failure happens in the setup phase, before any
        // encoder exists, so it surfaces as a thrown error rather than taking the process down (see #357).
        let pass = try RenderPass {
            let vs = VertexShader(try #require(library.makeFunction(name: "vertex_main")))
            let fs = FragmentShader(try #require(library.makeFunction(name: "fragment_main")))
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .visibleFunctionTable("colorTable", functionType: .kernel, functions: [red])
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([red])
        }

        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        #expect(throws: MetalSprocketsError.self) {
            _ = try renderer.render(pass)
        }
    }

    /// Renders `pass` and returns the error it threw during setup, failing the test if it did not throw.
    private func setupError(_ pass: some Element, sourceLocation: SourceLocation = #_sourceLocation) throws -> String {
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        var caught: MetalSprocketsError?
        #expect(throws: MetalSprocketsError.self, sourceLocation: sourceLocation) {
            do {
                _ = try renderer.render(pass)
            }
            catch let error as MetalSprocketsError {
                caught = error
                throw error
            }
        }
        return caught.map { "\($0)" } ?? ""
    }

    @Test("A table name that is in no binding is rejected during setup")
    func testUnknownTableNameIsRejected() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7), device.supportsFunctionPointers else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let red = try #require(library.makeFunction(name: "red_visible"))

        // "noSuchTable" appears in neither the vertex nor the fragment bindings, so auto-detection finds nothing.
        let pass = try RenderPass {
            let vs = VertexShader(try #require(library.makeFunction(name: "vertex_main")))
            let fs = FragmentShader(try #require(library.makeFunction(name: "fragment_main")))
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .visibleFunctionTable("noSuchTable", function: red)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([red])
        }

        let message = try setupError(pass)
        #expect(message.contains("noSuchTable"), "Unexpected error: \(message)")
    }

    @Test("An explicit function type must match the stage the table is bound in")
    func testExplicitFunctionTypeForWrongStageIsRejected() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7), device.supportsFunctionPointers else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let red = try #require(library.makeFunction(name: "red_visible"))

        // `colorTable` exists, but only in the fragment stage. Asking for .vertex must not silently fall back to
        // the fragment binding.
        let pass = try RenderPass {
            let vs = VertexShader(try #require(library.makeFunction(name: "vertex_main")))
            let fs = FragmentShader(try #require(library.makeFunction(name: "fragment_main")))
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .visibleFunctionTable("colorTable", functionType: .vertex, functions: [red])
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([red])
        }

        let message = try setupError(pass)
        #expect(message.contains("bindings"), "Unexpected error: \(message)")
    }

    @Test("A table name bound in both stages needs an explicit function type")
    func testAmbiguousTableNameIsRejected() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7), device.supportsFunctionPointers else { return }

        let library = try device.makeLibrary(source: Self.ambiguousTableSource, options: nil)
        let white = try #require(library.makeFunction(name: "white_visible"))

        // `colorTable` is bound in both the vertex and the fragment stage. Picking one arbitrarily would bind the
        // table to the wrong stage, so this has to be an error the caller resolves.
        let pass = try RenderPass {
            let vs = VertexShader(try #require(library.makeFunction(name: "vertex_main")))
            let fs = FragmentShader(try #require(library.makeFunction(name: "fragment_main")))
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    let verts: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
                    encoder.setVertexBytes(verts, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .visibleFunctionTable("colorTable", function: white)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([white])
        }

        let message = try setupError(pass)
        #expect(message.contains("multiple function types"), "Unexpected error: \(message)")
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
