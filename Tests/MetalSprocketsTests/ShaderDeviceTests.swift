import Metal
@testable import MetalSprockets
import Testing

@Suite("Shader device selection")
struct ShaderDeviceTests {
    private final class Marker {
    }

    @Test func `matching devices report no mismatch`() {
        let marker = Marker()
        let device = ObjectIdentifier(marker)
        let stages = [(name: "vertex", device: device), (name: "fragment", device: device)]
        #expect(ShaderDeviceCheck.mismatchedStage(stages, pipelineDevice: device) == nil)
    }

    @Test func `the first mismatched stage is reported`() {
        let pipelineMarker = Marker()
        let otherMarker = Marker()
        let pipelineDevice = ObjectIdentifier(pipelineMarker)
        let otherDevice = ObjectIdentifier(otherMarker)
        let stages = [(name: "vertex", device: pipelineDevice), (name: "fragment", device: otherDevice)]
        #expect(ShaderDeviceCheck.mismatchedStage(stages, pipelineDevice: pipelineDevice) == "fragment")
    }

    @Test func `no stages means no mismatch`() {
        let marker = Marker()
        #expect(ShaderDeviceCheck.mismatchedStage([], pipelineDevice: ObjectIdentifier(marker)) == nil)
    }

    @Test func `validating shaders built on the same device passes`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let shader = try VertexShader(source: Self.source, device: device)
        try ShaderDeviceCheck.validate([("vertex", shader.function)], device: device, label: "test")
    }

    @Test func `an explicit device is used for compilation`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try ShaderLibrary(source: Self.source, device: device)
        let shader: VertexShader = try library.vertex_main
        #expect(shader.function.device === device)
    }

    @Test func `an explicit device is used when looking a function up by name`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(source: Self.source, options: nil)
        let shader = try VertexShader(library: library, name: "vertex_main", device: device)
        #expect(shader.function.device === device)
    }

    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    [[vertex]] float4 vertex_main(uint id [[vertex_id]]) {
        return float4(0, 0, 0, 1);
    }
    """
}
