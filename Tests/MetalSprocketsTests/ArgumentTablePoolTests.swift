import Metal
@testable import MetalSprockets
import Testing

@MainActor
@Suite("Metal 4 argument table reuse", .requiresMetal4)
struct ArgumentTablePoolTests {
    @Test
    func `compatible tables reuse storage only after reset`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let pool = ArgumentTablePool(device: device)
        let sizes = PipelineBindings.TableSizes(buffers: 2, textures: 3, samplers: 1)
        let first = try pool.acquire(sizes: sizes, label: nil)
        let second = try pool.acquire(sizes: sizes, label: nil)
        #expect(first !== second)
        for _ in 0..<20 {
            pool.reset()
            #expect(try pool.acquire(sizes: sizes, label: nil) === first)
            #expect(try pool.acquire(sizes: sizes, label: nil) === second)
        }
    }

    @Test
    func `labels survive reuse without leaking between pipelines`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let pool = ArgumentTablePool(device: device)
        let sizes = PipelineBindings.TableSizes(buffers: 1)
        let first = try pool.acquire(sizes: sizes, label: "Cube: Vertex Arguments")
        pool.reset()
        let second = try pool.acquire(sizes: sizes, label: "Lighting: Fragment Arguments")
        #expect(first !== second)
        #expect(first.label == "Cube: Vertex Arguments")
        #expect(second.label == "Lighting: Fragment Arguments")
        pool.reset()
        let unlabeled = try pool.acquire(sizes: sizes, label: nil)
        #expect(unlabeled !== first)
        #expect(unlabeled !== second)
        #expect(unlabeled.label == nil)
        for _ in 0..<3 {
            pool.reset()
            #expect(try pool.acquire(sizes: sizes, label: "Cube: Vertex Arguments") === first)
            #expect(try pool.acquire(sizes: sizes, label: "Lighting: Fragment Arguments") === second)
            #expect(try pool.acquire(sizes: sizes, label: nil) === unlabeled)
        }
    }

    @Test
    func `each binding count contributes to compatibility`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let pool = ArgumentTablePool(device: device)
        let sizes = [
            PipelineBindings.TableSizes(buffers: 1, textures: 1, samplers: 1),
            PipelineBindings.TableSizes(buffers: 2, textures: 1, samplers: 1),
            PipelineBindings.TableSizes(buffers: 1, textures: 2, samplers: 1),
            PipelineBindings.TableSizes(buffers: 1, textures: 1, samplers: 2)
        ]
        let tables = try sizes.map { try pool.acquire(sizes: $0, label: nil) }
        #expect(Set(tables.map(ObjectIdentifier.init)).count == sizes.count)
        pool.reset()
        for (size, table) in zip(sizes.reversed(), tables.reversed()) {
            #expect(try pool.acquire(sizes: size, label: nil) === table)
        }
    }

    @Test
    func `encoding failure recycles argument tables`() throws {
        enum Failure: Error { case expected }
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let sizes = PipelineBindings.TableSizes(buffers: 1)
        var first: (any MTL4ArgumentTable)?
        #expect(throws: Failure.expected) {
            try context.submit { scope in
                first = try scope.argumentTable(sizes: sizes, label: nil)
                throw Failure.expected
            }
        }
        let submission = try context.submit { scope in
            let table = try scope.argumentTable(sizes: sizes, label: nil)
            #expect(table === first)
        }
        try context.waitForResult(submission)
        try context.retireCompletedSubmissions()
        #expect(context.inFlightCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func `in flight tables are not recycled into another command buffer`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 2)
        let gate = try #require(device.makeSharedEvent())
        context.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        let sizes = PipelineBindings.TableSizes(buffers: 1)
        var first: (any MTL4ArgumentTable)?
        let submission = try context.submit { first = try $0.argumentTable(sizes: sizes, label: nil) }
        let firstTable = try #require(first)
        let overlapping = try context.submit { scope in
            let table = try scope.argumentTable(sizes: sizes, label: nil)
            #expect(table !== firstTable)
        }
        #expect(submission.resolvedResult == nil)
        gate.signaledValue = 1
        #expect(try await context.awaitResult(submission).outcome == .completed)
        #expect(try await context.awaitResult(overlapping).outcome == .completed)
        try await context.drain()
        #expect(context.inFlightCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func `completed submissions rebind buffers and clear unused texture bindings`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 1)
        let library = try await device.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;
        kernel void inspect(
            device uint *output [[buffer(0)]],
            device const uint *input [[buffer(2)]],
            array<texture2d<float>, 3> images [[texture(0)]]) {
            output[0] = *input;
            for (uint index = 0; index < 3; ++index) {
                output[index + 1] = is_null_texture(images[index]) ? 0 : 1;
            }
        }
        """, options: nil)
        let pipeline = try context.pipelines.computePipeline(kernel: ComputeKernel(library: library, name: "inspect"))
        let output = try #require(device.makeBuffer(length: 16, options: .storageModeShared))
        let inputs = try [UInt32(42), 7].map { value in
            var value = value
            return try #require(device.makeBuffer(bytes: &value, length: MemoryLayout<UInt32>.size, options: .storageModeShared))
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        descriptor.usage = .shaderRead
        let image = try #require(device.makeTexture(descriptor: descriptor))
        var previous: (any MTL4ArgumentTable)?
        for frame in 0..<6 {
            var parameters = ParameterSet()
            parameters.set("output", buffer: output)
            parameters.set("input", buffer: inputs[frame % inputs.count])
            if frame.isMultiple(of: 2) {
                parameters.set("images", textures: [image, image, image])
            } else {
                parameters.set("images", textures: [image])
            }
            let submission = try context.submit { scope in
                let tables = try parameters.makeTables(for: pipeline.bindings, stages: [.kernel], scope: scope)
                let table = try #require(tables[.kernel])
                if let previous {
                    #expect(table === previous)
                }
                previous = table
                try scope.withComputeEncoder { encoder in
                    encoder.setComputePipelineState(pipeline.state)
                    encoder.setArgumentTable(table)
                    encoder.dispatchThreads(threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
                }
            }
            #expect(try await context.awaitResult(submission).outcome == .completed)
            let values = output.contents().bindMemory(to: UInt32.self, capacity: 4)
            let expected: [UInt32] = frame.isMultiple(of: 2) ? [42, 1, 1, 1] : [7, 1, 0, 0]
            #expect((0..<4).map { values[$0] } == expected)
        }
        try await context.drain()
    }
}
