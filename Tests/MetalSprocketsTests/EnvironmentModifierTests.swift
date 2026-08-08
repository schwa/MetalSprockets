import CoreGraphics
import Metal
import MetalKit
@testable import MetalSprockets
import ModelIO
import Testing

@MainActor
@Suite("Environment convenience modifiers")
struct EnvironmentModifierTests {
    struct Leaf: Element, BodylessElement {
        typealias Body = Never
        var matched: Bool
    }

    /// Reads a value out of the environment and reports whether it is the one that was set.
    struct Probe<Value>: Element {
        @MSEnvironment var value: Value
        var isExpected: (Value) -> Bool

        init(_ keyPath: KeyPath<MSEnvironmentValues, Value>, isExpected: @escaping (Value) -> Bool) {
            self._value = MSEnvironment(keyPath)
            self.isExpected = isExpected
        }

        var body: some Element {
            Leaf(matched: isExpected(value))
        }
    }

    private func probeMatched(_ element: some Element) throws -> Bool {
        let system = System()
        try system.update(root: element)
        let leaf = try #require(system.nodes.values.compactMap { $0.element as? Leaf }.first)
        return leaf.matched
    }

    @Test func `the device modifier reaches descendants`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let probe = Probe(\.device) { $0 === device }
        #expect(try probeMatched(probe.device(device)))
    }

    @Test func `the command queue modifier reaches descendants`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        let probe = Probe(\.commandQueue) { $0 === commandQueue }
        #expect(try probeMatched(probe.commandQueue(commandQueue)))
    }

    @Test func `the command buffer modifier reaches descendants`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let commandQueue = try #require(device.makeCommandQueue())
        let commandBuffer = try #require(commandQueue.makeCommandBuffer())
        let probe = Probe(\.commandBuffer) { $0 === commandBuffer }
        #expect(try probeMatched(probe.commandBuffer(commandBuffer)))
    }

    @Test func `the descriptor modifiers reach descendants`() throws {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        let passProbe = Probe(\.renderPassDescriptor) { $0 === renderPassDescriptor }
        let pipelineProbe = Probe(\.renderPipelineDescriptor) { $0 === renderPipelineDescriptor }
        #expect(try probeMatched(passProbe.renderPassDescriptor(renderPassDescriptor)))
        #expect(try probeMatched(pipelineProbe.renderPipelineDescriptor(renderPipelineDescriptor)))
    }

    @Test func `the drawable size modifier reaches descendants`() throws {
        let size = CGSize(width: 320, height: 240)
        let probe = Probe(\.drawableSize) { $0 == size }
        #expect(try probeMatched(probe.drawableSize(size)))
    }

    @Test func `an unset value stays at its default`() throws {
        let probe = Probe(\.drawableSize) { $0 == nil }
        #expect(try probeMatched(probe))
    }

    // MARK: - Attachments

    private func makeTexture() throws -> MTLTexture {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 8, height: 8, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .private
        return try #require(device.makeTexture(descriptor: descriptor))
    }

    @Test func `the colour attachment modifier carries texture and index`() throws {
        let texture = try makeTexture()
        let probe = Probe(\.colorAttachment0) { attachment in
            attachment?.0 === texture && attachment?.1 == 2
        }
        #expect(try probeMatched(probe.colorAttachment0(texture, index: 2)))
    }

    @Test func `the depth attachment modifier reaches descendants`() throws {
        let texture = try makeTexture()
        let probe = Probe(\.depthAttachment) { $0 === texture }
        #expect(try probeMatched(probe.depthAttachment(texture)))
    }

    @Test func `the stencil attachment modifier reaches descendants`() throws {
        let texture = try makeTexture()
        let probe = Probe(\.stencilAttachment) { $0 === texture }
        #expect(try probeMatched(probe.stencilAttachment(texture)))
    }

    // MARK: - Vertex descriptors

    @Test func `a Model I-O vertex descriptor is converted to a Metal one`() throws {
        let modelDescriptor = MDLVertexDescriptor()
        modelDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        modelDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)

        let probe = Probe(\.vertexDescriptor) { descriptor in
            descriptor?.attributes[0].format == .float3 && descriptor?.layouts[0].stride == MemoryLayout<SIMD3<Float>>.stride
        }
        #expect(try probeMatched(probe.vertexDescriptor(modelDescriptor)))
    }
}
