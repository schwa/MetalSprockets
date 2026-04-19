// swiftlint:disable indentation_width
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

@MainActor
@Suite("Reflection Tests")
struct ReflectionTests {
    static let renderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn { float2 position [[attribute(0)]]; };
    struct VertexOut { float4 position [[position]]; };

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]],
        constant float4x4 &transform [[buffer(1)]]
    ) {
        VertexOut out;
        out.position = transform * float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant float4 &color [[buffer(0)]]
    ) {
        return color;
    }
    """

    static let computeSource = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void compute_main(device float *out [[buffer(0)]],
                             constant float &scale [[buffer(1)]],
                             uint tid [[thread_position_in_grid]]) {
        out[tid] = float(tid) * scale;
    }
    """

    @Test("Render reflection captures vertex + fragment bindings")
    func testRenderReflection() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(source: Self.renderSource, options: nil)
        let vertexFn = library.makeFunction(name: "vertex_main")!
        let fragmentFn = library.makeFunction(name: "fragment_main")!

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFn
        desc.fragmentFunction = fragmentFn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        // Set up a minimal vertex descriptor.
        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float2
        vd.attributes[0].offset = 0
        vd.attributes[0].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride
        desc.vertexDescriptor = vd

        let (_, rpReflection) = try device.makeRenderPipelineState(descriptor: desc, options: .bindingInfo)
        let reflection = Reflection(rpReflection!)

        #expect(reflection.binding(forType: .vertex, name: "transform") != nil)
        #expect(reflection.binding(forType: .fragment, name: "color") != nil)
        #expect(reflection.binding(forType: .vertex, name: "color") == nil)
        #expect(reflection.binding(forType: .fragment, name: "doesNotExist") == nil)
    }

    @Test("Compute reflection captures kernel bindings")
    func testComputeReflection() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(source: Self.computeSource, options: nil)
        let fn = library.makeFunction(name: "compute_main")!
        let desc = MTLComputePipelineDescriptor()
        desc.computeFunction = fn
        let (_, cpReflection) = try device.makeComputePipelineState(descriptor: desc, options: .bindingInfo)
        let reflection = Reflection(cpReflection!)

        #expect(reflection.binding(forType: .kernel, name: "out") != nil)
        #expect(reflection.binding(forType: .kernel, name: "scale") != nil)
        #expect(reflection.binding(forType: .kernel, name: "ghost") == nil)
    }

    @Test("Reflection debugDescription contains bindings")
    func testDebugDescription() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(source: Self.computeSource, options: nil)
        let fn = library.makeFunction(name: "compute_main")!
        let desc = MTLComputePipelineDescriptor()
        desc.computeFunction = fn
        let (_, cpReflection) = try device.makeComputePipelineState(descriptor: desc, options: .bindingInfo)
        let reflection = Reflection(cpReflection!)
        let description = reflection.debugDescription
        #expect(description.contains("scale"))
        #expect(description.contains("kernel"))
    }

    @Test("MTLFunctionType debugDescription covers all cases")
    func testFunctionTypeDebugDescription() {
        #expect(MTLFunctionType.vertex.debugDescription == "vertex")
        #expect(MTLFunctionType.fragment.debugDescription == "fragment")
        #expect(MTLFunctionType.kernel.debugDescription == "kernel")
        #expect(MTLFunctionType.visible.debugDescription == "visible")
        #expect(MTLFunctionType.intersection.debugDescription == "intersection")
        #expect(MTLFunctionType.mesh.debugDescription == "mesh")
        #expect(MTLFunctionType.object.debugDescription == "object")
    }

    @Test("Reflection.Key debugDescription")
    func testKeyDebugDescription() {
        let key = Reflection.Key(functionType: .vertex, name: "myParam")
        let d = key.debugDescription
        #expect(d.contains("vertex"))
        #expect(d.contains("myParam"))
    }
}
