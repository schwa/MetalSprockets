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

    @Test("Fragment visible function table renders", .requiresMetal4)
    func testFragmentVisibleFunctionTable() throws {
        let device = MTLCreateSystemDefaultDevice()!
        // Visible function tables need Apple GPU Family 7+.
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let redVisible = try VisibleFunction(library: library, name: "red_visible")

        // `.visibleFunctionTable` attaches to Draw (inside RenderPipeline).
        // `.linkedFunctions` carries shader provenance through the environment.
        let element = try RenderPass {
            let vs = try VertexShader(library: library, name: "vertex_main")
            let fs = try FragmentShader(library: library, name: "fragment_main")
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
                .visibleFunctionTable("colorTable", function: redVisible)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([redVisible])
        }
        // The table's only entry returns red, so the triangle has to come out red — not merely render without
        // throwing.
        try Golden.verify(element, named: "VisibleFunctionTableRed")
    }

    @Test("Explicit .fragment functionType resolves", .requiresMetal4)
    func testExplicitFragmentFunctionType() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let redVisible = try VisibleFunction(library: library, name: "red_visible")
        let greenVisible = try VisibleFunction(library: library, name: "green_visible")

        let element = try RenderPass {
            let vs = try VertexShader(library: library, name: "vertex_main")
            let fs = try FragmentShader(library: library, name: "fragment_main")
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
                // Explicitly target fragment stage + multi-function variant.
                .visibleFunctionTable("colorTable", functionType: .fragment, functions: [redVisible, greenVisible])
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([redVisible, greenVisible])
        }
        // Two functions are in the table but the shader calls index 0, so red wins and green is not drawn.
        try Golden.verify(element, named: "VisibleFunctionTableRed")
    }

    @Test("Vertex visible function table renders", .requiresMetal4)
    func testVertexVisibleFunctionTable() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.vertexTableSource, options: nil)
        let blueVisible = try VisibleFunction(library: library, name: "blue_visible")

        let element = try RenderPass {
            let vs = try VertexShader(library: library, name: "vertex_main")
            let fs = try FragmentShader(library: library, name: "fragment_main")
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
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

    @Test("Compute visible function table dispatches", .requiresMetal4)
    func testComputeVisibleFunctionTable() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.computeTableSource, options: nil)
        let plusOne = try VisibleFunction(library: library, name: "plus_one")

        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        let kernel = try ComputeKernel(library: library, name: "compute_main")

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(
                    threadsPerGrid: MTLSize(width: count, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
                )
                    .parameter("out", buffer: buffer)
                .visibleFunctionTable("transforms", function: plusOne)
            }
            .linkedFunctions([plusOne])
        }
        .run()

        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        for i in 0..<count {
            #expect(ptr[i] == UInt32(i) + 1)
        }
    }

    @Test("Compute visible function table with explicit .kernel functionType", .requiresMetal4)
    func testComputeVisibleFunctionTableExplicitKernel() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7) else { return }

        let library = try device.makeLibrary(source: Self.computeTableSource, options: nil)
        let timesTwo = try VisibleFunction(library: library, name: "times_two")

        let count = 64
        let buffer = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))

        let kernel = try ComputeKernel(library: library, name: "compute_main")

        try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(
                    threadsPerGrid: MTLSize(width: count, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
                )
                    .parameter("out", buffer: buffer)
                .visibleFunctionTable("transforms", functionType: .kernel, functions: [timesTwo])
            }
            .linkedFunctions([timesTwo])
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
        let red = try VisibleFunction(library: library, name: "red_visible")

        struct Leaf: Element, BodylessElement { var body: Never { fatalError() } }

        // No enclosing pipeline: the table is only resolved when a draw or dispatch binds it, so update and setup
        // leave it alone rather than failing.
        let system = System()
        try system.update(root: Leaf().visibleFunctionTable("table", function: red))
        try system.processSetup()
    }

    @Test("A function type the pipeline cannot serve is rejected during setup", .requiresMetal4)
    func testInvalidFunctionTypeForPipeline() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7), device.supportsFunctionPointers else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let red = try VisibleFunction(library: library, name: "red_visible")

        // A render pipeline cannot serve a `.kernel` table. The failure happens in the setup phase, before any
        // encoder exists, so it surfaces as a thrown error rather than taking the process down (see #357).
        let pass = try RenderPass {
            let vs = try VertexShader(library: library, name: "vertex_main")
            let fs = try FragmentShader(library: library, name: "fragment_main")
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
                .visibleFunctionTable("colorTable", functionType: .kernel, functions: [red])
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([red])
        }

        let message = try setupError(pass)
        #expect(message.contains("does not have"), "Unexpected error: \(message)")
    }

    /// Renders `pass` and returns the error it threw during setup, failing the test if it did not throw.
    private func setupError(_ pass: some Element, sourceLocation: SourceLocation = #_sourceLocation) throws -> String {
        let renderer = try OffscreenRenderer(size: CGSize(width: 32, height: 32))
        var caught: (any Error)?
        #expect(throws: (any Error).self, sourceLocation: sourceLocation) {
            do {
                _ = try renderer.render(pass)
            }
            catch {
                caught = error
                throw error
            }
        }
        return caught.map { "\($0)" } ?? ""
    }

    @Test("A table name that is in no binding is rejected during setup", .requiresMetal4)
    func testUnknownTableNameIsRejected() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7), device.supportsFunctionPointers else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let red = try VisibleFunction(library: library, name: "red_visible")

        // "noSuchTable" appears in neither the vertex nor the fragment bindings, so auto-detection finds nothing.
        let pass = try RenderPass {
            let vs = try VertexShader(library: library, name: "vertex_main")
            let fs = try FragmentShader(library: library, name: "fragment_main")
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
                .visibleFunctionTable("noSuchTable", function: red)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([red])
        }

        let message = try setupError(pass)
        #expect(message.contains("noSuchTable"), "Unexpected error: \(message)")
    }

    @Test("An explicit function type must match the stage the table is bound in", .requiresMetal4)
    func testExplicitFunctionTypeForWrongStageIsRejected() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7), device.supportsFunctionPointers else { return }

        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let red = try VisibleFunction(library: library, name: "red_visible")

        // `colorTable` exists, but only in the fragment stage. Asking for .vertex must not silently fall back to
        // the fragment binding.
        let pass = try RenderPass {
            let vs = try VertexShader(library: library, name: "vertex_main")
            let fs = try FragmentShader(library: library, name: "fragment_main")
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
                .visibleFunctionTable("colorTable", functionType: .vertex, functions: [red])
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([red])
        }

        let message = try setupError(pass)
        #expect(message.contains("bindings"), "Unexpected error: \(message)")
    }

    @Test("A table name bound in both stages needs an explicit function type", .requiresMetal4)
    func testAmbiguousTableNameIsRejected() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7), device.supportsFunctionPointers else { return }

        let library = try device.makeLibrary(source: Self.ambiguousTableSource, options: nil)
        let white = try VisibleFunction(library: library, name: "white_visible")

        // `colorTable` is bound in both the vertex and the fragment stage. Picking one arbitrarily would bind the
        // table to the wrong stage, so this has to be an error the caller resolves.
        let pass = try RenderPass {
            let vs = try VertexShader(library: library, name: "vertex_main")
            let fs = try FragmentShader(library: library, name: "fragment_main")
            try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .vertexValues(([[0, 0.5], [-0.5, -0.5], [0.5, -0.5]] as [SIMD2<Float>]), index: 0)
                .visibleFunctionTable("colorTable", function: white)
            }
            .vertexDescriptor(vs.inferredVertexDescriptor())
            .linkedFunctions([white])
        }

        let message = try setupError(pass)
        #expect(message.contains("multiple function types"), "Unexpected error: \(message)")
    }

    // Legacy tracked function changes through requiresSetup. On Metal 4 tables are resolved per draw from a cache keyed
    // by the function list, so a change takes effect on the next frame without setup.
    @Test("Changing a table's functions between frames changes the output", .requiresMetal4)
    func testFunctionChangesTakeEffectNextFrame() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple7), device.supportsFunctionPointers else { return }
        let library = try device.makeLibrary(source: Self.fragmentTableSource, options: nil)
        let red = try VisibleFunction(library: library, name: "red_visible")
        let green = try VisibleFunction(library: library, name: "green_visible")
        let vs = try VertexShader(library: library, name: "vertex_main")
        let fs = try FragmentShader(library: library, name: "fragment_main")
        func frame(_ function: VisibleFunction) throws -> some Element {
            try RenderPass {
                try RenderPipeline(vertexShader: vs, fragmentShader: fs) {
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                        .vertexValues(([[-1, -1], [3, -1], [-1, 3]] as [SIMD2<Float>]), index: 0)
                        .visibleFunctionTable("colorTable", function: function)
                }
                .vertexDescriptor(vs.inferredVertexDescriptor())
                .linkedFunctions([red, green])
            }
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 8, height: 8))
        func center() -> [UInt8] {
            var pixel = [UInt8](repeating: 0, count: 4)
            renderer.colorTexture.getBytes(&pixel, bytesPerRow: 8 * 4, from: MTLRegionMake2D(4, 4, 1, 1), mipmapLevel: 0)
            return pixel
        }
        _ = try renderer.render(try frame(red))
        #expect(center() == [0, 0, 255, 255])
        _ = try renderer.render(try frame(green))
        #expect(center() == [0, 255, 0, 255])
    }
}
