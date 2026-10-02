import CoreGraphics
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

private func functionTablesSupported() -> Bool {
    guard let device = MTLCreateSystemDefaultDevice() else {
        return false
    }
    return device.supportsFamily(.metal4) && device.supportsFamily(.apple7) && device.supportsFunctionPointers
}

/// Legacy VisibleFunctionTableTests scenes and diagnostics on the Metal 4 candidate, against unchanged references.
@MainActor
@Suite("Metal 4 visible-function tables", .requiresMetal4, .enabled(if: functionTablesSupported(), "Requires Metal 4, Apple 7 and function pointers"))
struct FunctionTableTests {
    private let device = MTLCreateSystemDefaultDevice()!

    private func triangle() throws -> any MTLBuffer {
        let vertices: [SIMD2<Float>] = [[0, 0.5], [-0.5, -0.5], [0.5, -0.5]]
        return try #require(device.makeBuffer(bytes: vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, options: .storageModeShared))
    }

    private func renderScene(_ source: String, table: String, stage: MTLFunctionType? = nil, functions: [String], linked: [String] = []) throws -> some Element {
        let library = try device.makeLibrary(source: source, options: nil)
        let vertex = try VertexShader(library: library, name: "vertex_main")
        let fragment = try FragmentShader(library: library, name: "fragment_main")
        let visible = try functions.map { try VisibleFunction(library: library, name: $0) }
        let linkedFunctions = try (linked.isEmpty ? functions : linked).map { try VisibleFunction(library: library, name: $0) }
        let buffer = try triangle()
        return try RenderPipeline(vertexShader: vertex, fragmentShader: fragment) {
            Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                .vertexBuffer(buffer, index: 0)
                .visibleFunctionTable(table, functionType: stage, functions: visible)
        }.vertexDescriptor(vertex.inferredVertexDescriptor()).linkedFunctions(linkedFunctions)
    }

    private func image(_ content: some Element) async throws -> CGImage {
        try await TestOffscreenRenderer(size: CGSize(width: 256, height: 256)).render(content).cgImage
    }

    @Test(.timeLimit(.minutes(1)))
    func fragmentAndVertexTablesMatchLegacyGoldens() async throws {
        try Golden.verify(try await image(renderScene(VisibleFunctionTableTests.fragmentTableSource, table: "colorTable", functions: ["red_visible"])), named: "VisibleFunctionTableRed")
        try Golden.verify(try await image(renderScene(VisibleFunctionTableTests.fragmentTableSource, table: "colorTable", stage: .fragment, functions: ["red_visible"])), named: "VisibleFunctionTableRed")
        try Golden.verify(try await image(renderScene(VisibleFunctionTableTests.vertexTableSource, table: "vertexColorTable", functions: ["blue_visible"])), named: "VisibleFunctionTableBlue")
    }

    private func computeRun(runner: FrameRunner, kernel: ComputeKernel, linked: [VisibleFunction], table: [VisibleFunction], stage: MTLFunctionType? = nil) async throws -> [UInt32] {
        let count = 64
        let output = try #require(device.makeBuffer(length: MemoryLayout<UInt32>.stride * count, options: .storageModeShared))
        let content = try ComputePass {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: count, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1))
                    .parameter("out", buffer: output)
                    .visibleFunctionTable("transforms", functionType: stage, functions: table)
            }.linkedFunctions(linked)
        }
        let result = try await runner.run(content)
        #expect(result.outcome == .completed)
        return Array(UnsafeBufferPointer(start: output.contents().bindMemory(to: UInt32.self, capacity: count), count: count))
    }

    @Test(.timeLimit(.minutes(1)))
    func computeTablesDispatchAndFollowFunctionChangesAcrossFrames() async throws {
        let library = try await device.makeLibrary(source: VisibleFunctionTableTests.computeTableSource, options: nil)
        let kernel = try ComputeKernel(library: library, name: "compute_main")
        let plusOne = try VisibleFunction(library: library, name: "plus_one")
        let timesTwo = try VisibleFunction(library: library, name: "times_two")
        let runner = try FrameRunner(device: device)
        let expectedPlusOne = (0..<64).map { UInt32($0) + 1 }
        let expectedTimesTwo = (0..<64).map { UInt32($0) * 2 }
        #expect(try await computeRun(runner: runner, kernel: kernel, linked: [plusOne, timesTwo], table: [plusOne]) == expectedPlusOne)
        #expect(try await computeRun(runner: runner, kernel: kernel, linked: [plusOne, timesTwo], table: [plusOne], stage: .kernel) == expectedPlusOne)
        #expect(try await computeRun(runner: runner, kernel: kernel, linked: [plusOne, timesTwo], table: [timesTwo]) == expectedTimesTwo)
        #expect(try await computeRun(runner: runner, kernel: kernel, linked: [plusOne, timesTwo], table: [plusOne]) == expectedPlusOne)

        // One pipeline; the two distinct function lists each built one table, reused on later frames.
        let pipeline = try runner.context.pipelines.computePipeline(kernel: kernel, linkedFunctions: [plusOne, timesTwo])
        #expect(runner.context.pipelines.compilationCount == 1)
        #expect(pipeline.functionTables.creationCount == 2)
        // Completed work retires; the cached tables stay owned by the pipeline, not the residency set.
        #expect(runner.context.inFlightCount == 0)
        #expect(!runner.context.residencySet.containsAllocation(try pipeline.functionTables.table(named: "transforms", stage: .kernel, functions: [plusOne])))
    }

    @Test(.timeLimit(.minutes(1)))
    func tablesStayResidentForTheirPipelineLifetime() async throws {
        let library = try await device.makeLibrary(source: VisibleFunctionTableTests.computeTableSource, options: nil)
        let plusOne = try VisibleFunction(library: library, name: "plus_one")
        let context = try MetalContext(device: device)
        let pipeline = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "compute_main"), linkedFunctions: [plusOne])
        let output = try #require(device.makeBuffer(length: 64 * MemoryLayout<UInt32>.stride, options: .storageModeShared))
        var parameters = ParameterSet()
        parameters.set("out", buffer: output)
        parameters.setFunctionTable("transforms", functions: [plusOne])
        let recording = try context.submit { scope in
            let tables = try parameters.makeTables(for: pipeline.bindings, stages: [.kernel], functionTables: pipeline.functionTables, scope: scope)
            try scope.withComputeEncoder { encoder in
                encoder.setComputePipelineState(pipeline.state)
                encoder.setArgumentTable(tables[.kernel])
                encoder.dispatchThreads(threadsPerGrid: MTLSize(width: 64, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1))
            }
        }
        let table = try pipeline.functionTables.table(named: "transforms", stage: .kernel, functions: [plusOne])
        let resources = try #require(pipeline.functionTables.resources)
        #expect(resources.residencySet.containsAllocation(table))
        #expect(!context.residencySet.containsAllocation(table))
        #expect(try await context.awaitResult(recording).outcome == .completed)
        try context.retireCompletedSubmissions()
        #expect(!context.residencySet.containsAllocation(table))
        #expect(resources.residencySet.containsAllocation(table))
        #expect(output.contents().load(fromByteOffset: 4 * 10, as: UInt32.self) == 11)
    }

    @Test(.timeLimit(.minutes(1)))
    func namedSpecializationsOfOneFunctionResolveDistinctHandles() async throws {
        let library = try await device.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;
        constant uint offset [[function_constant(0)]];
        using TransformFn = uint(uint);
        [[visible]] uint transform(uint v) { return v + offset; }
        kernel void compute_main(device uint *out [[buffer(0)]], visible_function_table<TransformFn> transforms [[buffer(1)]], uint tid [[thread_position_in_grid]]) {
            out[tid] = transforms[0](tid) * 1000 + transforms[1](tid);
        }
        """, options: nil)
        var constants = FunctionConstants()
        constants["offset"] = .uint32(11)
        let eleven = try VisibleFunction(library: library, name: "transform", constants: constants, specializedName: "transformEleven")
        constants["offset"] = .uint32(19)
        let nineteen = try VisibleFunction(library: library, name: "transform", constants: constants, specializedName: "transformNineteen")
        let kernel = try ComputeKernel(library: library, name: "compute_main")
        let output = try await computeRun(runner: try FrameRunner(device: device), kernel: kernel, linked: [eleven, nineteen], table: [eleven, nineteen])
        let expected: [UInt32] = (0..<64).map { (index: Int) -> UInt32 in UInt32(index + 11) * 1_000 + UInt32(index + 19) }
        #expect(output == expected)

        // Two different specializations exported under one name would make handle lookup ambiguous.
        constants["offset"] = .uint32(23)
        let clash = try VisibleFunction(library: library, name: "transform", constants: constants, specializedName: "transformEleven")
        await #expect(throws: MetalSprocketsError.self) {
            _ = try await computeRun(runner: try FrameRunner(device: device), kernel: kernel, linked: [eleven, clash], table: [eleven])
        }
    }

    private func renderFailure(_ content: some Element) async -> (any Error)? {
        do {
            _ = try await image(content)
            return nil
        } catch {
            return error
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func invalidBindingsProduceSpecificDiagnostics() async throws {
        let fragmentSource = VisibleFunctionTableTests.fragmentTableSource
        let unknown = await renderFailure(try renderScene(fragmentSource, table: "noSuchTable", functions: ["red_visible"]))
        #expect(unknown as? ParameterSet.Failure == .functionTableNotFound("noSuchTable"))

        let wrongStage = await renderFailure(try renderScene(fragmentSource, table: "colorTable", stage: .vertex, functions: ["red_visible"]))
        #expect(wrongStage as? ParameterSet.Failure == .functionTableNotFound("colorTable"))

        let unsupported = await renderFailure(try renderScene(fragmentSource, table: "colorTable", stage: .kernel, functions: ["red_visible"]))
        #expect(unsupported as? ParameterSet.Failure == .unsupportedFunctionTableStage(name: "colorTable", stage: .kernel))

        let ambiguous = await renderFailure(try renderScene(VisibleFunctionTableTests.ambiguousTableSource, table: "colorTable", functions: ["white_visible"]))
        #expect(ambiguous as? ParameterSet.Failure == .ambiguousFunctionTable(name: "colorTable", stages: [.vertex, .fragment]))

        // The table names a function that was never linked into the pipeline.
        let unlinked = await renderFailure(try renderScene(fragmentSource, table: "colorTable", functions: ["green_visible"], linked: ["red_visible"]))
        #expect(unlinked as? ParameterSet.Failure == .unlinkedFunction(table: "colorTable", function: "green_visible"))
    }
}
