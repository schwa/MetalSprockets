#if os(visionOS)
import ARKit
import CompositorServices
import Metal
import MetalSprockets
import MetalSprocketsSupport
import simd
import SwiftUI

@ImmersiveRendererActor
internal final class ImmersiveRuntime<Content: Element> {
    let layerRenderer: LayerRenderer
    let progressive: Bool
    let contentBuilder: @Sendable (ImmersiveContext) throws -> Content
    let device: MTLDevice
    let frameRenderer: FrameRenderer
    /// Records into the compositor's own Metal 4 queue, as CompositorServices requires.
    let runner: FrameRunner
    let arSession: ARKitSession
    let worldTracking: WorldTrackingProvider
    let stencilValue: UInt8 = 200
    let stencilFormat: MTLPixelFormat
    var startTime: CFAbsoluteTime = 0
    var stencilTexture: MTLTexture?
    let stencilResources: ResourceCollection
    var frameTimingTracker = FrameTimingTracker()
    var frameTimingChange: (@Sendable (FrameTimingStatistics) -> Void)?

    init(layerRenderer: LayerRenderer, progressive: Bool, maximumInFlightSubmissions: Int, content: @Sendable @escaping (ImmersiveContext) throws -> Content) throws {
        self.layerRenderer = layerRenderer
        self.progressive = progressive
        self.contentBuilder = content

        self.device = layerRenderer.device
        self.stencilResources = try ResourceCollection(device: layerRenderer.device)
        self.frameRenderer = FrameRenderer()
        #if targetEnvironment(simulator)
        // CompositorServices exposes no Metal 4 queue, render context or presentation on the simulator.
        throw MetalSprocketsError.deviceCababilityFailure("Immersive rendering on Metal 4 requires an Apple Vision Pro; the visionOS simulator has no Metal 4 compositor API.")
        #else
        self.runner = try FrameRunner(device: device, commandQueue: layerRenderer.commandQueue, system: frameRenderer.system, maximumInFlightSubmissions: maximumInFlightSubmissions)
        #endif
        self.arSession = ARKitSession()
        self.worldTracking = WorldTrackingProvider()

        self.stencilFormat = progressive ? layerRenderer.configuration.drawableRenderContextStencilFormat : .invalid
    }

    func renderLoop() async throws {
        try await arSession.run([worldTracking])
        // Covers both `.invalidated` and cancellation of the driving task.
        defer {
            arSession.stop()
        }
        startTime = CACurrentMediaTime()
        while true {
            try Task.checkCancellation()
            switch layerRenderer.state {
            case .invalidated:
                return
            case .paused:
                await waitUntilRunning()
                continue
            default:
                try await renderFrame()
            }
        }
    }

    /// Waits for the compositor to leave the paused state.
    ///
    /// `LayerRenderer.waitUntilRunning()` blocks the calling thread, so it runs off the renderer actor: blocking here
    /// would stall the actor (and a cooperative pool thread) for the whole pause. See #386.
    private func waitUntilRunning() async {
        nonisolated(unsafe) let layerRenderer = layerRenderer
        await Self.waitUntilRunning(layerRenderer)
    }

    @concurrent
    nonisolated private static func waitUntilRunning(_ layerRenderer: LayerRenderer) async {
        layerRenderer.waitUntilRunning()
    }

    func renderFrame() async throws {
        guard let frame = layerRenderer.queryNextFrame() else {
            return
        }

        frame.startUpdate()
        let time = CACurrentMediaTime() - startTime
        frame.endUpdate()

        guard let timing = frame.predictTiming() else {
            return
        }

        try await LayerRenderer.Clock().sleep(until: timing.optimalInputTime, tolerance: nil)

        guard layerRenderer.state == .running else {
            return
        }

        // Await the in-flight limit before entering the compositor's submission interval.
        try await runner.waitForSubmissionCapacity()

        frame.startSubmission()

        guard let drawable = frame.queryDrawables().first else {
            // The frame was invalidated (for example the immersive space was
            // dismissed during the pre-submit sleep). Ending submission on an
            // invalid frame trips cp_frame_end_submission(). Bail without it.
            return
        }

        let presentationTime = LayerRenderer.Clock.Instant.epoch.duration(to: drawable.frameTiming.presentationTime)
        // Render even without a device anchor (world tracking is still starting when the space opens): once drawables
        // are queried, ending the submission without presenting aborts ("called cp_frame_end_submission() before
        // calling cp_drawable_encode_present()"), and skipping it leaves the frame in flight until the fourth aborts.
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: presentationTime.toTimeInterval)
        drawable.deviceAnchor = deviceAnchor

        let currentTime = CACurrentMediaTime()
        frameTimingTracker.lastGPUTime = frameRenderer.lastGPUTime
        let frameTimingStatistics = frameTimingTracker.recordFrame(timestamp: currentTime)
        frameTimingChange?(frameTimingStatistics)

        try encodeFrame(drawable: drawable, deviceAnchor: deviceAnchor, time: time, frameTimingStatistics: frameTimingStatistics)
        frame.endSubmission()
    }

    func encodeFrame(drawable: LayerRenderer.Drawable, deviceAnchor: DeviceAnchor?, time: TimeInterval, frameTimingStatistics: FrameTimingStatistics) throws {
        #if !targetEnvironment(simulator)
        let renderPassDescriptor = try makeRenderPassDescriptor(drawable: drawable)
        // The device anchor is already set, which the render context requires.
        let renderContext = drawable.addRenderContext()

        let context = ImmersiveContext(device: device, time: time, drawable: drawable, deviceAnchor: deviceAnchor, renderContext: renderContext, isProgressive: progressive, stencilValue: stencilValue, stencilFormat: stencilFormat, frameTimingStatistics: frameTimingStatistics)

        let userContent = try contentBuilder(context)

        let root = userContent
            .renderPassDescriptor(renderPassDescriptor)
            .immersiveRenderContext(renderContext)
            .onCommandBufferCompleted { [frameRenderer] result in
                frameRenderer.lastGPUTime = result.gpuDuration
            }

        runner.residency.collections = [stencilResources]
        try runner.submitFrame(root)
        // UNVERIFIED ORDER (#404/#434): the Metal 4 header says to commit to the layer queue before presenting; the
        // inherited note says to encode presentation before commit. This follows the Metal 4 note until a device run
        // settles it.
        drawable.encodePresent()
        #endif
    }

    func makeRenderPassDescriptor(drawable: LayerRenderer.Drawable) throws -> MTL4RenderPassDescriptor {
        let desc = MTL4RenderPassDescriptor()

        desc.colorAttachments[0].texture = drawable.colorTextures[0]
        desc.colorAttachments[0].loadAction = .clear
        desc.colorAttachments[0].storeAction = .store
        desc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        desc.depthAttachment.texture = drawable.depthTextures[0]
        desc.depthAttachment.loadAction = .clear
        desc.depthAttachment.storeAction = .store
        desc.depthAttachment.clearDepth = 0.0

        desc.renderTargetArrayLength = drawable.views.count

        if let rasterizationRateMap = drawable.rasterizationRateMaps.first {
            desc.rasterizationRateMap = rasterizationRateMap
        }

        if progressive, stencilFormat != .invalid {
            desc.stencilAttachment.texture = try getOrCreateStencilTexture(matching: drawable.colorTextures[0])
            desc.stencilAttachment.loadAction = .clear
            desc.stencilAttachment.storeAction = .dontCare
            desc.stencilAttachment.clearStencil = 0
        }

        return desc
    }

    func getOrCreateStencilTexture(matching colorTexture: MTLTexture) throws -> MTLTexture? {
        if let existing = stencilTexture, existing.width == colorTexture.width, existing.height == colorTexture.height, existing.arrayLength == colorTexture.arrayLength {
            return existing
        }

        let desc = MTLTextureDescriptor()
        desc.textureType = colorTexture.textureType
        desc.pixelFormat = stencilFormat
        desc.width = colorTexture.width
        desc.height = colorTexture.height
        desc.arrayLength = colorTexture.arrayLength
        desc.usage = [.renderTarget]
        desc.storageMode = .private

        let texture = colorTexture.device.makeTexture(descriptor: desc)
        if let texture {
            try stencilResources.register(texture)
        }
        if let previous = stencilTexture {
            stencilResources.unregister(previous)
        }
        stencilTexture = texture
        return texture
    }
}
#endif
