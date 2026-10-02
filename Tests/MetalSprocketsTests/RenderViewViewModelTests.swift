import CoreGraphics
import Metal
import MetalKit
@testable import MetalSprockets
import MetalSprocketsSupport
@testable import MetalSprocketsUI
import SwiftUI
import Testing

@MainActor
@Suite("RenderViewViewModel frame driving")
struct RenderViewViewModelTests {
    struct Failure: Error {
    }

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;

    [[vertex]] float4 vertex_main(uint id [[vertex_id]]) {
        float2 positions[3] = { float2(0, 0.5), float2(-0.5, -0.5), float2(0.5, -0.5) };
        return float4(positions[id], 0, 1);
    }

    [[fragment]] float4 fragment_main() {
        return float4(1, 0, 0, 1);
    }
    """

    private func makeView(device: MTLDevice) -> MTKView {
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 64, height: 64), device: device)
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.framebufferOnly = false
        view.drawableSize = CGSize(width: 64, height: 64)
        return view
    }

    private func makeViewModel<Content: Element>(device: MTLDevice, content: @escaping (RenderViewContext, CGSize) throws -> Content) throws -> RenderViewViewModel<Content> {
        let commandQueue = try #require(device.makeMTL4CommandQueue())
        return RenderViewViewModel(device: device, commandQueue: commandQueue, content: content)
    }

    private func triangle() throws -> some Element {
        let vertexShader = try VertexShader(source: Self.source)
        let fragmentShader = try FragmentShader(source: Self.source)
        return try RenderPass {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
            }
        }
    }

    @Test(.requiresMetal4) func `drawing a frame advances the frame counter and reports timing`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var reported: [FrameTimingStatistics] = []
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        viewModel.frameTimingChange = { reported.append($0) }
        view.delegate = viewModel

        #expect(viewModel.frame == 0)
        view.draw()

        #expect(viewModel.frame == 1)
        #expect(reported.count == 1)
        #expect(viewModel.lastError == nil)
    }

    @Test(.requiresMetal4) func `successive frames reuse the system`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        view.delegate = viewModel

        view.draw()
        let nodeCount = viewModel.frameRenderer.system.nodes.count
        view.draw()

        #expect(viewModel.frame == 2)
        #expect(viewModel.frameRenderer.system.nodes.count == nodeCount)
        #expect(viewModel.lastError == nil)
    }

    @Test(.requiresMetal4) func `residency changes apply to frames without replacing the runner`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let collection = try ResourceCollection(device: device)
        let external = try device.makeResidencySet(descriptor: MTLResidencySetDescriptor())
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        view.delegate = viewModel
        viewModel.residency = ResidencyConfiguration(mode: .manual, collections: [collection], residencySets: [external])
        view.draw()
        #expect(viewModel.lastError == nil)
        let runner = try viewModel.runner()
        #expect(runner.residency.mode == .manual)
        #expect(runner.residency.collections.first === collection)
        #expect(runner.residency.residencySets.first === external)
        try await runner.context.drain()
        viewModel.residency = ResidencyConfiguration()
        view.draw()
        #expect(viewModel.lastError == nil)
        #expect(try viewModel.runner() === runner)
        #expect(runner.residency.mode == .automatic)
        #expect(runner.residency.collections.count == 1)
        #expect(runner.residency.collections.first !== collection)
        #expect(runner.residency.residencySets.isEmpty)
        try await runner.context.drain()
    }

    @Test(.requiresMetal4)
    func `attachment residency excludes drawables and retains replaced textures until their last use`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let viewModel = try makeViewModel(device: device) { _, _ in EmptyElement() }
        func texture(size: Int, samples: Int = 1) throws -> any MTLTexture {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
            descriptor.usage = .renderTarget
            descriptor.storageMode = .private
            if samples > 1 {
                descriptor.textureType = .type2DMultisample
                descriptor.sampleCount = samples
            }
            return try #require(device.makeTexture(descriptor: descriptor))
        }
        let drawable = try texture(size: 16)
        let original = try texture(size: 16, samples: 4)
        let replacement = try texture(size: 32, samples: 4)
        let descriptor = MTL4RenderPassDescriptor()
        descriptor.colorAttachments[0].texture = original
        descriptor.colorAttachments[0].resolveTexture = drawable
        let resources = try viewModel.updateAttachmentResidency(for: descriptor, drawableTexture: drawable)
        #expect(resources.contains(original))
        #expect(!resources.contains(drawable))
        #expect(resources.residencySet.allocationCount == 1)
        #expect(try viewModel.updateAttachmentResidency(for: descriptor, drawableTexture: drawable) === resources)
        var lease: ResourceCollection.Lease? = resources.acquire()
        descriptor.colorAttachments[0].texture = replacement
        _ = try viewModel.updateAttachmentResidency(for: descriptor, drawableTexture: drawable)
        #expect(!resources.contains(original))
        #expect(resources.residencySet.containsAllocation(original))
        #expect(resources.contains(replacement))
        #expect(lease != nil)
        lease = nil
        #expect(!resources.residencySet.containsAllocation(original))
        descriptor.colorAttachments[0].texture = drawable
        descriptor.colorAttachments[0].resolveTexture = nil
        _ = try viewModel.updateAttachmentResidency(for: descriptor, drawableTexture: drawable)
        #expect(resources.residencySet.allocationCount == 0)
    }

    @Test(.requiresMetal4, .timeLimit(.minutes(1)))
    func `depth and MSAA attachments avoid transient residency across frames and resizing`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = 4
        let viewModel = try makeViewModel(device: device) { _, _ in try triangle() }
        view.delegate = viewModel
        for index in 0..<6 {
            if index == 2 { view.drawableSize = CGSize(width: 96, height: 96) }
            if index == 4 { view.sampleCount = 1 }
            view.draw()
            #expect(viewModel.lastError == nil)
            let runner = try viewModel.runner()
            let resources = try #require(runner.residency.collections.last)
            let depth = try #require(view.depthStencilTexture)
            if depth.storageMode != .memoryless {
                #expect(resources.contains(depth))
            }
            #expect(runner.context.residentAllocationCount == 0)
            try await runner.context.drain()
            #expect(runner.context.residentAllocationCount == 0)
        }
        #expect(viewModel.frame == 6)
    }

    @Test(.requiresMetal4) func `the content closure sees the drawable size`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var seenSizes: [CGSize] = []
        let viewModel = try makeViewModel(device: device) { _, size in
            seenSizes.append(size)
            return try triangle()
        }
        view.delegate = viewModel

        view.draw()

        #expect(seenSizes == [CGSize(width: 64, height: 64)])
    }

    @Test(.requiresMetal4) func `a drawable size change marks every node for setup`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var reportedSizes: [CGSize] = []
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        viewModel.drawableSizeChange = { reportedSizes.append($0) }
        view.delegate = viewModel

        view.draw()
        #expect(viewModel.frameRenderer.system.nodes.values.map(\.needsSetup).contains(true) == false)

        viewModel.mtkView(view, drawableSizeWillChange: CGSize(width: 128, height: 128))

        // The first draw also reports, because the delegate was attached after the view was already sized.
        #expect(reportedSizes == [CGSize(width: 64, height: 64), CGSize(width: 128, height: 128)])
        #expect(viewModel.currentDrawableSize == CGSize(width: 128, height: 128))
        #expect(viewModel.frameRenderer.system.nodes.values.map(\.needsSetup).contains(true))
    }

    @Test(.requiresMetal4) func `a size change noticed during draw is resynced`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var reportedSizes: [CGSize] = []
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        viewModel.drawableSizeChange = { reportedSizes.append($0) }
        view.delegate = viewModel

        // The delegate never got a drawableSizeWillChange call, so draw(in:) has to notice the mismatch itself.
        view.draw()

        #expect(reportedSizes == [CGSize(width: 64, height: 64)])
        #expect(viewModel.currentDrawableSize == CGSize(width: 64, height: 64))
    }

    @Test(.requiresMetal4) func `an error thrown by the content closure is captured`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let viewModel: RenderViewViewModel<EmptyElement> = try makeViewModel(device: device) { _, _ in
            throw Failure()
        }
        view.delegate = viewModel

        view.draw()

        #expect(viewModel.lastError is Failure)
    }

    @Test(.requiresMetal4) func `an error thrown during setup is captured and the next frame recovers`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var shouldThrow = true
        // The content closure succeeds; the failure happens later, while the element tree is being set up. That is a
        // different catch from the content-closure one above, and it must not take the drawable presentation or the
        // view model down with it.
        let viewModel = try makeViewModel(device: device) { _, _ -> AnyElement in
            let willThrow = shouldThrow
            return AnyElement(
                try triangle().onSetupEnter { _ in
                    if willThrow {
                        throw Failure()
                    }
                }
            )
        }
        view.delegate = viewModel

        view.draw()
        #expect(viewModel.lastError is Failure)

        shouldThrow = false
        view.draw()
        #expect(viewModel.frame == 2)
    }

    @Test(.requiresMetal4) func `an error thrown during the frame leaves the view model usable`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        var shouldThrow = true
        let viewModel = try makeViewModel(device: device) { _, _ -> AnyElement in
            if shouldThrow {
                throw Failure()
            }
            return try AnyElement(triangle())
        }
        view.delegate = viewModel

        view.draw()
        #expect(viewModel.lastError is Failure)

        shouldThrow = false
        view.draw()
        #expect(viewModel.frame == 2)
    }

    @Test func `sampleCountChanged reports only real changes`() {
        #expect(sampleCountChanged(current: 1, observed: 4))
        #expect(sampleCountChanged(current: 4, observed: 4) == false)
    }

    @Test(.requiresMetal4) func `an MSAA change invalidates setup for every node`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        view.delegate = viewModel

        view.draw()
        #expect(viewModel.frameRenderer.system.nodes.values.map(\.needsSetup).contains(true) == false)
        #expect(viewModel.currentSampleCount == 1)

        // A sample-count change means every pipeline state is stale, whether or not the size changed.
        guard device.supportsTextureSampleCount(4) else {
            return
        }
        view.sampleCount = 4
        view.draw()

        #expect(viewModel.currentSampleCount == 4)
    }

    @Test(.requiresMetal4) func `frame logging can be switched on through the environment`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }
        view.delegate = viewModel

        SystemEnvironment.$current.withValue(SystemEnvironment(enabled: ["MS_RENDERVIEW_LOG_FRAME"])) {
            #expect(RenderViewDebugging.logFrame)
            viewModel.diagnostics = RenderViewDiagnostics(environment: EnvironmentValues())
            #expect(viewModel.diagnostics.logFrame)
            view.draw()
        }

        #expect(viewModel.frame == 1)
        #expect(viewModel.lastError == nil)
    }

    @Test(.requiresMetal4) func `SwiftUI environment values override the process environment for diagnostics (#269)`() {
        let processEnvironment = SystemEnvironment(enabled: ["MS_RENDERVIEW_LOG_FRAME", "MS_FATALERROR_ON_THROW"])

        let inherited = RenderViewDiagnostics(environment: EnvironmentValues(), systemEnvironment: processEnvironment)
        #expect(inherited.logFrame)
        #expect(inherited.fatalErrorOnError)

        var environment = EnvironmentValues()
        environment.renderViewLogFrame = false
        environment.renderViewFatalErrorOnError = false
        let overridden = RenderViewDiagnostics(environment: environment, systemEnvironment: processEnvironment)
        #expect(!overridden.logFrame)
        #expect(!overridden.fatalErrorOnError)

        var opted = EnvironmentValues()
        opted.renderViewLogFrame = true
        let optedIn = RenderViewDiagnostics(environment: opted, systemEnvironment: SystemEnvironment(variables: [:]))
        #expect(optedIn.logFrame)
        #expect(!optedIn.fatalErrorOnError)
    }

    @Test(.requiresMetal4) func `the signpost id is made once and reused`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let viewModel = try makeViewModel(device: device) { _, _ in
            try triangle()
        }

        let first = viewModel.signpostID
        let second = viewModel.signpostID
        #expect(first == second)
    }

    // Ported from the removed Metal4ViewRenderer staging tests (#438).

    private static let colorSource = """
    #include <metal_stdlib>
    using namespace metal;
    [[vertex]] float4 fullscreen(uint id [[vertex_id]]) {
        const float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};
        return float4(positions[id], 0, 1);
    }
    [[fragment]] float4 solid(constant float4 &color [[buffer(0)]]) { return color; }
    """

    /// Fills the drawable with `color` and records the drawable's texture so the test can read it back.
    private func solidShaders() throws -> (VertexShader, FragmentShader) {
        let library = try ShaderLibrary(source: Self.colorSource)
        return (try library.function(type: VertexShader.self, named: "fullscreen"), try library.function(type: FragmentShader.self, named: "solid"))
    }

    private func solid(_ color: SIMD4<Float>, shaders: (VertexShader, FragmentShader), capture: @escaping (any MTLTexture) -> Void) throws -> some Element {
        let (vertexShader, fragmentShader) = shaders
        return EnvironmentReader(keyPath: \.currentDrawable) { drawable in
            // `_ =` is an expression the element builder would try to build; a declaration is skipped.
            // swiftlint:disable:next redundant_discardable_let
            let _ = drawable.map { capture($0.texture) }
            try RenderPass {
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                    Draw { $0.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3) }
                        .parameter("color", value: color)
                }
            }
        }
    }

    private func centerPixel(_ texture: any MTLTexture) -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&pixel, bytesPerRow: 4, from: MTLRegionMake2D(texture.width / 2, texture.height / 2, 1, 1), mipmapLevel: 0)
        return pixel
    }

    @Test(.requiresMetal4, .timeLimit(.minutes(1)))
    func `frames render the right pixels into successive drawables with one pipeline compile`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let colors: [SIMD4<Float>] = [[1, 0, 0, 1], [0, 1, 0, 1], [0, 0, 1, 1], [1, 1, 1, 1], [1, 0, 1, 1]]
        var index = 0
        var textures: [any MTLTexture] = []
        let shaders = try solidShaders()
        let viewModel = try makeViewModel(device: device) { _, _ in
            try solid(colors[index], shaders: shaders) { textures.append($0) }
        }
        view.delegate = viewModel
        for (frameIndex, color) in colors.enumerated() {
            index = frameIndex
            view.draw()
            try await viewModel.runner().context.drain()
            #expect(viewModel.lastError == nil)
            let texture = try #require(textures.last)
            #expect(centerPixel(texture) == [UInt8(color.z * 255), UInt8(color.y * 255), UInt8(color.x * 255), 255])
        }
        #expect(textures.count == colors.count)
        let compilationCount = try viewModel.runner().context.pipelines.compilationCount
        #expect(compilationCount == 1)
        #expect(viewModel.skippedFrameCount == 0)
    }

    @Test(.requiresMetal4, .timeLimit(.minutes(1)))
    func `a frame at the configured in flight limit is skipped and later recovers`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let view = makeView(device: device)
        let viewModel = try makeViewModel(device: device) { _, _ in
            try solid([1, 1, 1, 1], shaders: try solidShaders()) { _ in }
        }
        view.delegate = viewModel
        viewModel.maximumInFlightSubmissions = 1
        let runner = try viewModel.runner()
        #expect(runner.context.maximumInFlightSubmissions == 1)
        let gate = try #require(device.makeSharedEvent())
        runner.context.waitForEvent(gate, value: 1)
        var pending: [Submission] = []
        while runner.context.canSubmit {
            pending.append(try runner.context.submit { _ in })
        }
        view.draw()
        #expect(viewModel.skippedFrameCount == 1)
        #expect(viewModel.frame == 0)
        gate.signaledValue = 1
        for submission in pending {
            _ = try await submission.waitForResult()
        }
        view.draw()
        try await runner.context.drain()
        #expect(viewModel.lastError == nil)
        #expect(viewModel.skippedFrameCount == 1)
        #expect(viewModel.frame == 1)
        try runner.context.retireCompletedSubmissions()
        #expect(runner.context.inFlightCount == 0)
        viewModel.maximumInFlightSubmissions = 2
        #expect(try viewModel.runner() === runner)
        #expect(runner.context.maximumInFlightSubmissions == 2)
    }
}
