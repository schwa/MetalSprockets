import Foundation
import Metal
import MetalKit
import QuartzCore
import simd

// MARK: - Vertex layout (must match Shaders.metal)

private struct Vertex {
    var position: SIMD2<Float>
    var uv: SIMD2<Float>
}

// MARK: - Frame-in-flight constant

/// The canonical triple-buffered frame count. Matches Apple's
/// `metal-drawing-a-triangle-with-metal-4` sample and WWDC25-254
/// guidance. One allocator per in-flight frame.
private let maxFramesInFlight = 3

// MARK: - Renderer

final class Renderer: NSObject, MTKViewDelegate {
    let device: any MTLDevice

    // Metal 4 infrastructure.
    private let commandQueue: any MTL4CommandQueue
    private let commandBuffer: any MTL4CommandBuffer
    private let commandAllocators: [any MTL4CommandAllocator]
    private let frameRootResidencySet: any MTLResidencySet

    // Pipelines.
    private let renderPipelineState: any MTLRenderPipelineState
    private let computePipelineState: any MTLComputePipelineState

    // Argument tables. Built once at init, mutated in `draw(in:)` as needed.
    private let vertexArgumentTable: any MTL4ArgumentTable
    private let fragmentArgumentTable: any MTL4ArgumentTable
    private let computeArgumentTable: any MTL4ArgumentTable

    // Resources.
    private let vertexBuffer: any MTLBuffer
    private let gradientTexture: any MTLTexture
    private let linearSampler: any MTLSamplerState
    private let timeBuffer: any MTLBuffer

    // Frame pacing.
    private let endFrameEvent: any MTLSharedEvent
    private var frameIndex: Int

    // Animation clock.
    private let startDate = Date()

    // Compute grid sizing.
    private let gradientSize = 256

    init(device: any MTLDevice) {
        self.device = device

        // 1. Metal 4 command queue.
        do {
            let descriptor = MTL4CommandQueueDescriptor()
            descriptor.label = "Main MTL4CommandQueue"
            self.commandQueue = try! device.makeMTL4CommandQueue(descriptor: descriptor)
        }

        // 2. ONE command buffer, reused across frames.
        self.commandBuffer = device.makeCommandBuffer()!
        self.commandBuffer.label = "Frame Command Buffer"

        // 3. `maxFramesInFlight` command allocators, one per in-flight frame.
        self.commandAllocators = (0..<maxFramesInFlight).map { i in
            let descriptor = MTL4CommandAllocatorDescriptor()
            descriptor.label = "Allocator \(i)"
            return try! device.makeCommandAllocator(descriptor: descriptor)
        }

        // 4. Compiler + default library.
        let compiler: any MTL4Compiler
        do {
            let descriptor = MTL4CompilerDescriptor()
            descriptor.label = "Main MTL4Compiler"
            compiler = try! device.makeCompiler(descriptor: descriptor)
        }
        let library = try! device.makeDefaultLibrary(bundle: .main)

        // 5. Render pipeline.
        do {
            let vertexFunctionDescriptor = MTL4LibraryFunctionDescriptor()
            vertexFunctionDescriptor.name = "vertex_main"
            vertexFunctionDescriptor.library = library

            let fragmentFunctionDescriptor = MTL4LibraryFunctionDescriptor()
            fragmentFunctionDescriptor.name = "fragment_main"
            fragmentFunctionDescriptor.library = library

            let descriptor = MTL4RenderPipelineDescriptor()
            descriptor.label = "Triangle Pipeline"
            descriptor.vertexFunctionDescriptor = vertexFunctionDescriptor
            descriptor.fragmentFunctionDescriptor = fragmentFunctionDescriptor
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            self.renderPipelineState = try! compiler.makeRenderPipelineState(descriptor: descriptor)
        }

        // 6. Compute pipeline.
        do {
            let functionDescriptor = MTL4LibraryFunctionDescriptor()
            functionDescriptor.name = "gradient_kernel"
            functionDescriptor.library = library

            let descriptor = MTL4ComputePipelineDescriptor()
            descriptor.label = "Gradient Pipeline"
            descriptor.computeFunctionDescriptor = functionDescriptor

            self.computePipelineState = try! compiler.makeComputePipelineState(descriptor: descriptor)
        }

        // 7. Argument tables (built once, stable slots populated below).
        do {
            let descriptor = MTL4ArgumentTableDescriptor()
            descriptor.label = "Vertex Argument Table"
            descriptor.maxBufferBindCount = 1
            descriptor.initializeBindings = true
            self.vertexArgumentTable = try! device.makeArgumentTable(descriptor: descriptor)
        }
        do {
            let descriptor = MTL4ArgumentTableDescriptor()
            descriptor.label = "Fragment Argument Table"
            descriptor.maxTextureBindCount = 1
            descriptor.maxSamplerStateBindCount = 1
            descriptor.initializeBindings = true
            self.fragmentArgumentTable = try! device.makeArgumentTable(descriptor: descriptor)
        }
        do {
            let descriptor = MTL4ArgumentTableDescriptor()
            descriptor.label = "Compute Argument Table"
            descriptor.maxBufferBindCount = 1
            descriptor.maxTextureBindCount = 1
            descriptor.initializeBindings = true
            self.computeArgumentTable = try! device.makeArgumentTable(descriptor: descriptor)
        }

        // 8. Geometry.
        let vertices: [Vertex] = [
            Vertex(position: [ 0.0,  0.7], uv: [0.5, 0.0]),
            Vertex(position: [-0.7, -0.7], uv: [0.0, 1.0]),
            Vertex(position: [ 0.7, -0.7], uv: [1.0, 1.0]),
        ]
        let length = MemoryLayout<Vertex>.stride * vertices.count
        self.vertexBuffer = device.makeBuffer(bytes: vertices, length: length, options: .storageModeShared)!
        self.vertexBuffer.label = "Triangle Vertices"

        // 9. Gradient texture (compute writes, fragment reads).
        do {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: gradientSize,
                height: gradientSize,
                mipmapped: false
            )
            descriptor.usage = [.shaderWrite, .shaderRead]
            descriptor.storageMode = .private
            self.gradientTexture = device.makeTexture(descriptor: descriptor)!
            self.gradientTexture.label = "Gradient Texture"
        }

        // 10. Linear sampler.
        do {
            let descriptor = MTLSamplerDescriptor()
            descriptor.minFilter = .linear
            descriptor.magFilter = .linear
            descriptor.sAddressMode = .clampToEdge
            descriptor.tAddressMode = .clampToEdge
            self.linearSampler = device.makeSamplerState(descriptor: descriptor)!
        }

        // 11. Time uniform buffer (updated per frame).
        self.timeBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)!
        self.timeBuffer.label = "Time"

        // 12. Root residency set for our own long-lived allocations. Attach
        //     at queue level (stable lifecycle). CAMetalLayer's drawable
        //     residency set is attached per-frame on the command buffer,
        //     because that's what Xcode 26's Metal 4 Game template does.
        do {
            let descriptor = MTLResidencySetDescriptor()
            descriptor.label = "Root Residency Set"
            descriptor.initialCapacity = 3
            self.frameRootResidencySet = try! device.makeResidencySet(descriptor: descriptor)
        }
        frameRootResidencySet.addAllocations([vertexBuffer, gradientTexture, timeBuffer])
        frameRootResidencySet.commit()
        commandQueue.addResidencySet(frameRootResidencySet)

        // 13. Populate stable argument-table slots.
        vertexArgumentTable.setAddress(vertexBuffer.gpuAddress, index: 0)
        fragmentArgumentTable.setTexture(gradientTexture.gpuResourceID, index: 0)
        fragmentArgumentTable.setSamplerState(linearSampler.gpuResourceID, index: 0)
        computeArgumentTable.setTexture(gradientTexture.gpuResourceID, index: 0)
        computeArgumentTable.setAddress(timeBuffer.gpuAddress, index: 0)

        // 14. Shared event for frame pacing. Initialize such that the first
        //     `maxFramesInFlight` frames don't wait: start frameIndex at
        //     maxFramesInFlight and set the signaled value to
        //     maxFramesInFlight - 1. First frame's wait-value is
        //     frameIndex - maxFramesInFlight = 0, which is already
        //     satisfied.
        self.endFrameEvent = device.makeSharedEvent()!
        self.endFrameEvent.label = "End Frame Event"
        self.frameIndex = maxFramesInFlight
        self.endFrameEvent.signaledValue = UInt64(maxFramesInFlight - 1)

        super.init()
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op; gradient texture is a fixed size.
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }

        // Delay grabbing the render pass descriptor until we need it so we
        // don't hold the drawable longer than necessary.
        guard let renderPassDescriptor = view.currentMTL4RenderPassDescriptor else {
            return
        }

        // Wait on the shared event: the frame that was in flight
        // `maxFramesInFlight` frames ago must have finished before we reuse
        // its allocator.
        let waitValue = UInt64(frameIndex - maxFramesInFlight)
        endFrameEvent.wait(untilSignaledValue: waitValue, timeoutMS: 10)

        // Rotate allocators.
        let allocator = commandAllocators[frameIndex % maxFramesInFlight]
        allocator.reset()

        // Begin encoding into our reused command buffer.
        commandBuffer.beginCommandBuffer(allocator: allocator)
        commandBuffer.label = "Frame \(frameIndex)"

        // Update the time uniform (CPU-side write into a shared-storage buffer).
        let t = Float(Date().timeIntervalSince(startDate))
        timeBuffer.contents().assumingMemoryBound(to: Float.self).pointee = t

        // -- Compute pass: write the gradient texture. ----------------------
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.label = "Gradient Compute"
            computeEncoder.setComputePipelineState(computePipelineState)
            computeEncoder.setArgumentTable(computeArgumentTable)

            let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadsPerGrid = MTLSize(width: gradientSize, height: gradientSize, depth: 1)
            computeEncoder.dispatchThreads(threadsPerGrid: threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

            // Metal 4 does no automatic hazard tracking between encoders.
            // Make the compute writes visible to the upcoming fragment-stage
            // reads.
            let baseEncoder: any MTL4CommandEncoder = computeEncoder
            baseEncoder.barrier(
                afterStages: .dispatch,
                beforeQueueStages: .fragment,
                visibilityOptions: .device
            )
            computeEncoder.endEncoding()
        }

        // -- Render pass: sample the gradient texture. ----------------------
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.label = "Triangle Encoder"
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setArgumentTable(vertexArgumentTable, stages: .vertex)
            renderEncoder.setArgumentTable(fragmentArgumentTable, stages: .fragment)
            renderEncoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
            renderEncoder.endEncoding()
        }

        // Attach the drawable's residency set to the command buffer (not the
        // queue): the Xcode 26 Metal 4 Game template's pattern. CAMetalLayer
        // manages the set's contents itself.
        if let metalLayer = view.layer as? CAMetalLayer {
            commandBuffer.useResidencySet(metalLayer.residencySet)
        }
        commandBuffer.endCommandBuffer()

        // Canonical Metal 4 drawable handshake:
        // wait → commit → signalDrawable → signalEvent → present.
        commandQueue.waitForDrawable(drawable)
        commandQueue.commit([commandBuffer])
        commandQueue.signalDrawable(drawable)
        commandQueue.signalEvent(endFrameEvent, value: UInt64(frameIndex))
        drawable.present()

        frameIndex += 1
    }
}
