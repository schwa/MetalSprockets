import Foundation
import Metal
@testable import MetalSprockets
@testable import MetalSprocketsSupport
@testable import MetalSprocketsUI
import SwiftUI
import Testing

// MARK: - AnyElement

@MainActor
@Suite("AnyElement")
struct AnyElementTests {
    struct Leaf: Element, WorkloadElement {
        var value: Int
        var body: Never { fatalError() }
        func workloadEnter(_ node: Node) throws {
            TestMonitor.shared.logUpdate("leaf-\(value)")
        }
    }

    @Test("eraseToAnyElement wraps and forwards visit")
    func testEraseWrapsBase() throws {
        TestMonitor.shared.reset()
        let system = System()
        try system.update(root: Leaf(value: 42).eraseToAnyElement())
        try system.processWorkload()
        #expect(TestMonitor.shared.updates == ["leaf-42"])
    }

    // See #343: AnyElement only requires setup when the wrapped type changes.
    @Test("AnyElement requiresSetup tracks the wrapped type")
    func testRequiresSetupTracksWrappedType() {
        let a = AnyElement(Leaf(value: 1))
        let b = AnyElement(Leaf(value: 1))
        let other = AnyElement(EmptyElement())
        #expect(a.requiresSetup(comparedTo: b) == false)
        #expect(a.requiresSetup(comparedTo: other) == true)
    }
}

// MARK: - ComputeDispatch init errors + requiresSetup

@MainActor
@Suite("ComputeDispatch additional tests")
struct ComputeDispatchMoreTests {
    @Test("threadsPerGrid succeeds on supported GPUs")
    func testThreadsPerGrid() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple4) else { return }
        _ = try ComputeDispatch(
            threadsPerGrid: MTLSize(width: 16, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
        )
    }

    @Test("requiresSetup is false")
    func testRequiresSetupIsFalse() throws {
        let a = try ComputeDispatch(
            threadgroups: MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
        )
        let b = try ComputeDispatch(
            threadgroups: MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
        )
        #expect(a.requiresSetup(comparedTo: b) == false)
    }
}

// MARK: - ProcessInfo isTruthy parsing

@Suite("ProcessInfo environment flags")
struct ProcessInfoExtensionsTests {
    @Test("All getter properties return Bool without crashing")
    func testFlagsReadable() {
        let info = ProcessInfo.processInfo
        _ = info.loggingEnabled
        _ = info.verboseLoggingEnabled
        _ = info.fatalErrorOnThrow
        _ = info.metalLoggingEnabled
        _ = info.dumpSnapshotsEnabled
        _ = info.renderViewLogFrameEnabled
    }

    // isTruthy is private. It accepts ["yes", "true", "y", "1", "on"] regardless of case or
    // whitespace, and is exercised through the public API above.
}

// MARK: - CommandBufferLogging

@Suite("CommandBufferLogging")
struct CommandBufferLoggingTests {
    @Test(
        "addMetalSprocketsLogging attaches a log state", .requiresMetal4,
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Metal log state unavailable on CI runners")
    )
    func testAddMetalSprocketsLogging() throws {
        let descriptor = MTLCommandBufferDescriptor()
        #expect(descriptor.logState == nil)
        try descriptor.addMetalSprocketsLogging(device: MTLCreateSystemDefaultDevice()!)
        #expect(descriptor.logState != nil)
    }
}

// MARK: - SwiftUI Color parameter

@MainActor
@Suite("Parameter+SwiftUI")
struct ParameterSwiftUITests {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; };
    [[vertex]] VertexOut vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
        VertexOut out;
        out.position = float4(positions[id], 0, 1);
        return out;
    }
    [[fragment]] float4 fragment_main(constant float4 &tint [[buffer(0)]]) { return tint; }
    """

    /// Renders a full-screen triangle whose fragment color is the `tint` parameter; returns the center pixel (BGRA).
    private func render(_ tinted: (Draw) -> some Element) throws -> [UInt8] {
        let library = try ShaderLibrary(source: Self.source)
        let renderer = try OffscreenRenderer(size: CGSize(width: 8, height: 8))
        let pass = try RenderPass {
            try RenderPipeline(vertexShader: library.function(type: VertexShader.self, named: "vertex_main"), fragmentShader: library.function(type: FragmentShader.self, named: "fragment_main")) {
                tinted(Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) })
            }
        }
        let texture = try renderer.render(pass).texture
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&pixel, bytesPerRow: 8 * 4, from: MTLRegionMake2D(4, 4, 1, 1), mipmapLevel: 0)
        return pixel
    }

    @Test(".parameter(name:color:) binds the color's device RGB components", .requiresMetal4)
    func testColorParameterRendersColor() throws {
        #expect(try render { $0.parameter("tint", color: Color(red: 1, green: 0, blue: 0)) } == [0, 0, 255, 255])
    }

    @Test(".parameter(name:color:functionType:) binds only the fragment stage", .requiresMetal4)
    func testColorParameterWithFunctionType() throws {
        #expect(try render { $0.parameter("tint", color: Color(red: 0, green: 0, blue: 1), functionType: .fragment) } == [255, 0, 0, 255])
        // The vertex stage has no `tint`, so filtering to it is a missing binding.
        #expect(throws: (any Error).self) {
            _ = try render { $0.parameter("tint", color: .red, functionType: .vertex) }
        }
    }
}
