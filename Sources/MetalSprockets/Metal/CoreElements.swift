import Metal
import MetalSprocketsSupport

internal struct ParameterSetKey: MSEnvironmentKey {
    static var defaultValue: ParameterSet? { nil }
}

package struct StencilFace: Hashable, Sendable {
    package var compare: MTLCompareFunction = .always
    package var stencilFailure: MTLStencilOperation = .keep
    package var depthFailure: MTLStencilOperation = .keep
    package var depthStencilPass: MTLStencilOperation = .keep
    package var readMask: UInt32 = 0xFFFF_FFFF
    package var writeMask: UInt32 = 0xFFFF_FFFF

    package init(compare: MTLCompareFunction = .always, stencilFailure: MTLStencilOperation = .keep, depthFailure: MTLStencilOperation = .keep, depthStencilPass: MTLStencilOperation = .keep, readMask: UInt32 = 0xFFFF_FFFF, writeMask: UInt32 = 0xFFFF_FFFF) {
        self.compare = compare
        self.stencilFailure = stencilFailure
        self.depthFailure = depthFailure
        self.depthStencilPass = depthStencilPass
        self.readMask = readMask
        self.writeMask = writeMask
    }

    func makeDescriptor() -> MTLStencilDescriptor {
        let descriptor = MTLStencilDescriptor()
        descriptor.stencilCompareFunction = compare
        descriptor.stencilFailureOperation = stencilFailure
        descriptor.depthFailureOperation = depthFailure
        descriptor.depthStencilPassOperation = depthStencilPass
        descriptor.readMask = readMask
        descriptor.writeMask = writeMask
        return descriptor
    }
}

/// Depth and stencil test state for draws; the value form of `MTLDepthStencilDescriptor`, usable as a cache key.
package struct DepthState: Hashable, Sendable {
    package var compare: MTLCompareFunction
    package var isWriteEnabled: Bool
    package var frontStencil: StencilFace?
    package var backStencil: StencilFace?

    package init(compare: MTLCompareFunction, isWriteEnabled: Bool, frontStencil: StencilFace? = nil, backStencil: StencilFace? = nil) {
        self.compare = compare
        self.isWriteEnabled = isWriteEnabled
        self.frontStencil = frontStencil
        self.backStencil = backStencil
    }

    /// Metal's default: every fragment passes and nothing is written.
    static let disabled = Self(compare: .always, isWriteEnabled: false)
}

package struct DepthBias: Equatable, Sendable {
    package var bias: Float
    package var slopeScale: Float
    package var clamp: Float
}

internal extension MSEnvironmentValues {
    @MSEntry var metalContext: MetalContext?
    @MSEntry var depthState: DepthState?
    @MSEntry var depthBias: DepthBias?
    @MSEntry var stencilReference: UInt32?
    @MSEntry var viewport: MTLViewport?
    @MSEntry var scissor: MTLScissorRect?

    var parameterSet: ParameterSet? {
        get { self[ParameterSetKey.self] }
        set { self[ParameterSetKey.self] = newValue }
    }

    @MSEntry var activeRenderPassDescriptor: MTL4RenderPassDescriptor?
    @MSEntry var renderPipeline: PipelineCache.RenderPipeline?
    @MSEntry var computePipeline: PipelineCache.ComputePipeline?
}

/// Attachment formats and sample count read from a pass, which pipelines must match.
internal struct PassFormats {
    var color: [MTLPixelFormat] = []
    let depth: MTLPixelFormat
    let stencil: MTLPixelFormat
    let sampleCount: Int

    init(_ pass: MTL4RenderPassDescriptor) {
        for index in 0..<8 {
            guard let texture = pass.colorAttachments[index]?.texture else {
                break
            }
            color.append(texture.pixelFormat)
        }
        depth = pass.depthAttachment.texture?.pixelFormat ?? .invalid
        stencil = pass.stencilAttachment.texture?.pixelFormat ?? .invalid
        sampleCount = pass.colorAttachments[0]?.texture?.sampleCount ?? 1
    }
}

/// Adds parameters during workload, rebuilding from the parent's current parameters every frame. Reading the
/// inherited value (not this node's own earlier write) keeps skipped, reused nodes from pinning stale parameters.
internal struct ParameterModifier<Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var apply: (inout ParameterSet) -> Void

    func workloadEnter(_ node: Node) throws {
        var parameters = node.environmentValues.inheritedValue(ParameterSetKey.self) ?? ParameterSet()
        apply(&parameters)
        node.environmentValues.parameterSet = parameters
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

/// Writes a draw-state value during workload every frame, so reused nodes never keep an earlier frame's state.
internal struct DrawStateModifier<Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var apply: (inout MSEnvironmentValues) -> Void

    func workloadEnter(_ node: Node) throws {
        apply(&node.environmentValues)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

/// Runs `action` with the recording scope during workload, for resource declarations and result callbacks.
internal struct ScopeModifier<Content>: Element, WorkloadElement, BodylessContentElement where Content: Element {
    var content: Content
    var action: (RecordingScope) throws -> Void

    func workloadEnter(_ node: Node) throws {
        try action(try node.environmentValues.recordingScope.orThrow(.missingEnvironment("recordingScope")))
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

public extension Element {
    /// Keeps `collection` resident for every submission this subtree encodes into.
    func useResourceCollection(_ collection: ResourceCollection) -> some Element {
        ScopeModifier(content: self) { try $0.useResourceCollection(collection) }
    }

    /// Attaches an externally owned residency set to every submission this subtree encodes into.
    func useResidencySet(_ residencySet: any MTLResidencySet) -> some Element {
        ScopeModifier(content: self) { try $0.useResidencySet(residencySet) }
    }
}

package extension Element {
    /// Sets the full depth and stencil state for draws in this subtree.
    func depthStencil(_ state: DepthState, stencilReference: UInt32 = 0) -> some Element {
        DrawStateModifier(content: self) { environment in
            environment.depthState = state
            environment.stencilReference = stencilReference
        }
    }

    func viewport(_ viewport: MTLViewport) -> some Element {
        DrawStateModifier(content: self) { $0.viewport = viewport }
    }

    func scissor(_ rect: MTLScissorRect) -> some Element {
        DrawStateModifier(content: self) { $0.scissor = rect }
    }

    /// Keeps external owners (such as `CVMetalTexture`s backing camera textures) alive until the submission ends.
    func retainOwners(_ owners: [AnyObject]) -> some Element {
        ScopeModifier(content: self) { scope in
            for owner in owners {
                try scope.retainObject(owner)
            }
        }
    }

    /// Declares allocations referenced indirectly or by raw encoder closures, for residency and lifetime.
    func useResources(_ allocations: [any MTLAllocation]) -> some Element {
        ScopeModifier(content: self) { scope in
            for allocation in allocations {
                try scope.retainAllocation(allocation)
            }
        }
    }

    /// Invokes `action` once with the terminal result of the recording this subtree encodes into, if it is committed.
    func onSubmissionTerminated(_ action: @escaping @Sendable (SubmissionResult) -> Void) -> some Element {
        ScopeModifier(content: self) { scope in
            try scope.onTerminated(action)
        }
    }
}
