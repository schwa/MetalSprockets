#if os(visionOS)
import ARKit
@preconcurrency import CompositorServices
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
    let commandQueue: MTLCommandQueue
    let system: System
    let arSession: ARKitSession
    let worldTracking: WorldTrackingProvider
    let stencilValue: UInt8 = 200
    let stencilFormat: MTLPixelFormat
    var startTime: CFAbsoluteTime = 0
    var stencilTexture: MTLTexture?

    init(layerRenderer: LayerRenderer, progressive: Bool, content: @Sendable @escaping (ImmersiveContext) throws -> Content) throws {
        self.layerRenderer = layerRenderer
        self.progressive = progressive
        self.contentBuilder = content

        self.device = layerRenderer.device
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalSprocketsError.resourceCreationFailure("command queue")
        }
        self.commandQueue = commandQueue
        self.system = System()
        self.arSession = ARKitSession()
        self.worldTracking = WorldTrackingProvider()

        self.stencilFormat = progressive ? layerRenderer.configuration.drawableRenderContextStencilFormat : .invalid
    }

    func renderLoop() async throws {
        try await arSession.run([worldTracking])
        startTime = CACurrentMediaTime()
        while true {
            switch layerRenderer.state {
            case .invalidated:
                arSession.stop()
                return
            case .paused:
                layerRenderer.waitUntilRunning()
                continue
            default:
                try await renderFrame()
            }
        }
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

        // Async sleep instead of blocking wait
        try await LayerRenderer.Clock().sleep(until: timing.optimalInputTime, tolerance: nil)

        guard layerRenderer.state == .running else {
            return
        }

        frame.startSubmission()
        defer {
            frame.endSubmission()
        }

        guard let drawable = frame.queryDrawables().first else {
            return
        }

        // Get device anchor at presentation time
        let presentationTime = LayerRenderer.Clock.Instant.epoch.duration(to: drawable.frameTiming.presentationTime)
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: presentationTime.toTimeInterval)
        drawable.deviceAnchor = deviceAnchor

        try encodeFrame(drawable: drawable, deviceAnchor: deviceAnchor, time: time)
    }

    func encodeFrame(drawable: LayerRenderer.Drawable, deviceAnchor: DeviceAnchor?, time: TimeInterval) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalSprocketsError.resourceCreationFailure("command buffer")
        }

        let renderPassDescriptor = makeRenderPassDescriptor(drawable: drawable)
        let renderContext = drawable.addRenderContext(commandBuffer: commandBuffer)

        let context = ImmersiveContext(device: device, time: time, drawable: drawable, deviceAnchor: deviceAnchor, renderContext: renderContext, isProgressive: progressive, stencilValue: stencilValue, stencilFormat: stencilFormat)

        let userContent = try contentBuilder(context)

        let root = userContent
            .environment(\.device, device)
            .environment(\.commandQueue, commandQueue)
            .environment(\.commandBuffer, commandBuffer)
            .environment(\.renderPassDescriptor, renderPassDescriptor)
            .immersiveRenderContext(renderContext)

        try system.update(root: root)
        try system.processSetup()
        try system.processWorkload()

        drawable.encodePresent(commandBuffer: commandBuffer)
        commandBuffer.commit()
    }

    func makeRenderPassDescriptor(drawable: LayerRenderer.Drawable) -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()

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
            desc.stencilAttachment.texture = getOrCreateStencilTexture(matching: drawable.colorTextures[0])
            desc.stencilAttachment.loadAction = .clear
            desc.stencilAttachment.storeAction = .dontCare
            desc.stencilAttachment.clearStencil = 0
        }

        return desc
    }

    func getOrCreateStencilTexture(matching colorTexture: MTLTexture) -> MTLTexture? {
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
        stencilTexture = texture
        return texture
    }
}
#endif
