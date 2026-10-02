import Metal
import MetalSprockets
import MetalSprocketsSupport
internal import os

/// The body of `YCbCrBillboardRenderPass`: draws a full-screen quad converting Y + CbCr planes to RGB.
///
/// `owners` are objects that must outlive GPU use of the textures, such as the `CVMetalTexture`s behind camera planes.
/// They stay alive until the submission ends, not merely until the next camera frame replaces them.
package struct YCbCrBillboard: Element {
    @MSState
    private var vertexShader = ShaderLibrary.metalSprocketsUI
        .namespaced("YCbCrBillboard")
        .requiredFunction(named: "vertex_main", type: VertexShader.self)

    @MSState
    private var fragmentShader = ShaderLibrary.metalSprocketsUI
        .namespaced("YCbCrBillboard")
        .requiredFunction(named: "fragment_main", type: FragmentShader.self)

    let textureY: any MTLTexture
    let textureCbCr: any MTLTexture
    let textureCoordinates: [SIMD2<Float>]
    let owners: [AnyObject]

    package init(textureY: any MTLTexture, textureCbCr: any MTLTexture, textureCoordinates: [SIMD2<Float>] = [[0, 1], [1, 1], [0, 0], [1, 0]], owners: [AnyObject] = []) {
        self.textureY = textureY
        self.textureCbCr = textureCbCr
        self.textureCoordinates = textureCoordinates
        self.owners = owners
    }

    #if os(iOS)
    package init(frameData: ARFrameData) throws {
        let textureY = try frameData.textureY.orThrow(.validationError("ARFrameData has no Y texture"))
        let textureCbCr = try frameData.textureCbCr.orThrow(.validationError("ARFrameData has no CbCr texture"))
        self.init(textureY: textureY, textureCbCr: textureCbCr, textureCoordinates: frameData.textureCoordinates, owners: frameData.textureOwners)
    }
    #endif

    nonisolated(unsafe) private static let vertexDescriptor: MTLVertexDescriptor = {
        let descriptor = MTLVertexDescriptor()
        for index in 0..<2 {
            descriptor.attributes[index].format = .float2
            descriptor.attributes[index].offset = 0
            descriptor.attributes[index].bufferIndex = index
            descriptor.layouts[index].stride = MemoryLayout<SIMD2<Float>>.stride
            descriptor.layouts[index].stepFunction = .perVertex
        }
        return descriptor
    }()

    private static let positions: [SIMD2<Float>] = [[-1, -1], [1, -1], [-1, 1], [1, 1]]

    // Argument tables bind samplers by resource ID, which needs `supportArgumentBuffers`. One per device, reused.
    private static let samplers = OSAllocatedUnfairLock<[ObjectIdentifier: any MTLSamplerState]>(uncheckedState: [:])

    static func sampler(for device: any MTLDevice) throws -> any MTLSamplerState {
        try samplers.withLockUnchecked { samplers in
            if let sampler = samplers[ObjectIdentifier(device)] {
                return sampler
            }
            let descriptor = MTLSamplerDescriptor()
            descriptor.minFilter = .linear
            descriptor.magFilter = .linear
            descriptor.supportArgumentBuffers = true
            let sampler = try device.makeSamplerState(descriptor: descriptor).orThrow(.resourceCreationFailure("Failed to create YCbCr sampler"))
            samplers[ObjectIdentifier(device)] = sampler
            return sampler
        }
    }

    package var body: some Element {
        get throws {
            try RenderPipeline(label: "YCbCr billboard", vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { $0.drawPrimitives(primitiveType: .triangleStrip, vertexStart: 0, vertexCount: 4) }
                    .vertexValues(Self.positions, index: 0)
                    .vertexValues(textureCoordinates, index: 1)
                    .parameter("textureY", texture: textureY)
                    .parameter("textureCbCr", texture: textureCbCr)
                    .parameter("textureSampler", samplerState: try Self.sampler(for: textureY.device))
                    // Background layer: no depth test, no depth write.
                    .depthCompare(function: .always, enabled: false)
                    .retainOwners(owners)
            }.vertexDescriptor(Self.vertexDescriptor)
        }
    }
}
