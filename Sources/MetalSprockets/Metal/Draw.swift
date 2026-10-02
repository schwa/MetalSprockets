import Metal
import MetalSprocketsSupport

// MARK: - Draw

/// Issues draw calls with the enclosing ``RenderPipeline``.
///
/// Before `encodeGeometry` runs, the pipeline, its argument tables (from ``Element/parameter(_:functionTypes:value:)``
/// and related modifiers), depth/stencil state, depth bias, viewport and scissor are already bound. Cull mode, triangle
/// fill mode, front-facing winding and vertex amplification count are reset to Metal's defaults. Every draw sets that
/// state, so nothing leaks from one draw to the next.
///
/// ```swift
/// Draw { encoder in
///     encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
/// }
/// .vertexBuffer(vertices, index: 0)
/// .parameter("color", value: SIMD4<Float>(1, 0, 0, 1))
/// ```
///
/// Metal 4 encoders have no `setVertexBytes` or `setFragmentTexture`. Pass data with the parameter and vertex
/// modifiers instead, and declare anything referenced only by the closure with ``Element/useResource(_:usage:stages:)``.
public struct Draw: Element, WorkloadElement {
    // Cannot use EnvironmentReader here: Draw runs in the workload phase, when the render command encoder exists,
    // not during the tree expansion phase where EnvironmentReader operates.
    public typealias Body = Never

    var encodeGeometry: (any MTL4RenderCommandEncoder) throws -> Void
    // Resources the closure reads by GPU address, kept resident and alive for the submission.
    var resources: [any MTLResource] = []

    public init(encodeGeometry: @escaping (any MTL4RenderCommandEncoder) throws -> Void) {
        self.encodeGeometry = encodeGeometry
    }

    init(resources: [any MTLResource], encodeGeometry: @escaping (any MTL4RenderCommandEncoder) throws -> Void) {
        self.encodeGeometry = encodeGeometry
        self.resources = resources
    }

    func workloadEnter(_ node: Node) throws {
        let environment = node.environmentValues
        let pass = try environment.renderPassEncoder.orThrow(.withHint(.missingEnvironment(\.renderCommandEncoder), hint: "Place Draw inside a RenderPass."))
        let pipeline = try environment.renderPipeline.orThrow(.withHint(.missingEnvironment(\.renderPipelineState), hint: "Place Draw inside a RenderPipeline or MeshRenderPipeline."))
        let context = try environment.metalContext.orThrow(.missingEnvironment("metalContext"))
        let depthStencil: any MTLDepthStencilState
        if let explicit = environment.depthStencilState {
            depthStencil = explicit
        } else if let state = environment.depthState {
            depthStencil = try context.depthStencilState(state)
        } else if let descriptor = environment.depthStencilDescriptor {
            depthStencil = try context.depthStencilState(DepthState(descriptor))
        } else {
            depthStencil = try context.depthStencilState(.disabled)
        }
        let bias = environment.depthBias ?? DepthBias(bias: 0, slopeScale: 0, clamp: 0)
        let stencilReference = environment.stencilReference ?? 0
        // Viewport and scissor are left at the encoder's defaults unless a draw asks for them, because the right
        // default depends on the target (rasterization rate maps and amplified layers need more than one full-texture
        // rect). Once a draw overrides them, later draws in the pass without an override get the defaults back.
        let explicitViewport = environment.viewport
        let explicitScissor = environment.scissor
        let defaults = Self.defaultViewportAndScissor(environment.activeRenderPassDescriptor)
        if !resources.isEmpty {
            let scope = try environment.recordingScope.orThrow(.missingEnvironment("recordingScope"))
            for resource in resources {
                try scope.retainAllocation(resource)
            }
        }
        try pass.draw(pipeline, parameters: environment.parameterSet ?? ParameterSet()) { encoder in
            // Depth/stencil state and bias logically apply to every draw, but the pass skips any that already match the
            // encoder so unchanged siblings do not re-bind. An unset value still means the default, never a leak.
            try pass.applyDrawState(depthStencil: depthStencil, bias: bias, stencilReference: stencilReference)
            // Rasterizer state a Draw closure may set. Reset to Metal's defaults so it does not leak to later siblings.
            encoder.setCullMode(.none)
            encoder.setTriangleFillMode(.fill)
            encoder.setFrontFacing(.clockwise)
            encoder.setVertexAmplificationCount(1)
            if let viewport = explicitViewport {
                encoder.setViewport(viewport)
                pass.viewportOverridden = true
            } else if pass.viewportOverridden, let viewport = defaults?.viewport {
                encoder.setViewport(viewport)
                pass.viewportOverridden = false
            }
            if let scissor = explicitScissor {
                encoder.setScissorRect(scissor)
                pass.scissorOverridden = true
            } else if pass.scissorOverridden, let scissor = defaults?.scissor {
                encoder.setScissorRect(scissor)
                pass.scissorOverridden = false
            }
            try encodeGeometry(encoder)
        }
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        // Draw only encodes during workload, never needs setup
        false
    }

    /// The rects a pass starts with: the rate map's logical screen when there is one, else attachment 0's size.
    static func defaultViewportAndScissor(_ descriptor: MTL4RenderPassDescriptor?) -> (viewport: MTLViewport, scissor: MTLScissorRect)? {
        guard let descriptor else {
            return nil
        }
        let width: Int
        let height: Int
        if let rateMap = descriptor.rasterizationRateMap {
            width = rateMap.screenSize.width
            height = rateMap.screenSize.height
        } else if let texture = descriptor.colorAttachments[0]?.texture {
            width = texture.width
            height = texture.height
        } else {
            return nil
        }
        return (MTLViewport(originX: 0, originY: 0, width: Double(width), height: Double(height), znear: 0, zfar: 1), MTLScissorRect(x: 0, y: 0, width: width, height: height))
    }
}

// MARK: - RenderCommand

/// Raw access to the Metal 4 render encoder inside a ``RenderPass``, without a pipeline or any bound state.
///
/// Use it for work that sets its own state, such as a mask drawn by the visionOS compositor. For ordinary geometry use
/// ``Draw``. Encoder state set here does not carry over: each ``Draw`` sets its own depth, stencil, viewport and scissor.
public struct RenderCommand: Element, WorkloadElement {
    public typealias Body = Never
    let encode: (any MTL4RenderCommandEncoder) throws -> Void

    public init(_ encode: @escaping (any MTL4RenderCommandEncoder) throws -> Void) {
        self.encode = encode
    }

    func workloadEnter(_ node: Node) throws {
        let pass = try node.environmentValues.renderPassEncoder.orThrow(.withHint(.missingEnvironment(\.renderCommandEncoder), hint: "Place RenderCommand inside a RenderPass."))
        try pass.command(encode)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

public extension Element {
    /// Sets the stencil reference value for draws in this subtree.
    func stencilReferenceValue(_ value: UInt32) -> some Element {
        DrawStateModifier(content: self) { $0.stencilReference = value }
    }
}

extension DepthState {
    init(_ descriptor: MTLDepthStencilDescriptor) {
        func face(_ stencil: MTLStencilDescriptor?) -> StencilFace? {
            stencil.map { StencilFace(compare: $0.stencilCompareFunction, stencilFailure: $0.stencilFailureOperation, depthFailure: $0.depthFailureOperation, depthStencilPass: $0.depthStencilPassOperation, readMask: $0.readMask, writeMask: $0.writeMask) }
        }
        self.init(compare: descriptor.depthCompareFunction, isWriteEnabled: descriptor.isDepthWriteEnabled, frontStencil: face(descriptor.frontFaceStencil), backStencil: face(descriptor.backFaceStencil))
    }
}
