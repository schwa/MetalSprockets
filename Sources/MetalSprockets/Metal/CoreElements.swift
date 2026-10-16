import Metal
import MetalSprocketsSupport

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

/// State carried through a collapsed chain of workload modifiers.
internal struct CollapseState {
    /// The parameter set being built, started from the inherited one by the first parameter modifier in the chain.
    var parameters: ParameterSet?
}

/// A modifier that only acts in `workloadEnter` and can be collapsed into an enclosing one.
///
/// A chain of directly nested collapsible modifiers (for example `.vertexValues(...).parameter(...).viewport(...)
/// .useResource(...)`) becomes one node: the outermost applies every modifier in the chain to its own node, outermost
/// first, and visits the first element that is not collapsible. Writes nearer the content still win, as with separate
/// nodes. Restores and extends #54 for Metal 4 (RFC 0006).
internal protocol CollapsibleWorkloadModifier: BodylessContentElement {
    func applyCollapsed(to node: Node, state: inout CollapseState) throws

    // Walk the rest of the chain in place. A chain is one nested value (`A<B<C<Draw>>>`), so taking each level out as
    // `any Element` would copy the whole remaining chain at every level. These read `Self` through a pointer to the
    // caller's storage instead, and are called through the metatype of `Content` cached in `ElementTypeInfo`.
    static func visitInnermost(at pointer: UnsafeRawPointer, _ visit: (any Element) throws -> Void) throws
    static func applyChain(at pointer: UnsafeRawPointer, to node: Node, state: inout CollapseState) throws
}

extension CollapsibleWorkloadModifier {
    static func visitInnermost(at pointer: UnsafeRawPointer, _ visit: (any Element) throws -> Void) throws {
        let modifier = pointer.assumingMemoryBound(to: Self.self)
        guard let next = ElementTypeInfo.of(type: Content.self).collapsibleType else {
            try visit(modifier.pointee.content)
            return
        }
        try withUnsafePointer(to: modifier.pointee.content) { content in
            try next.visitInnermost(at: UnsafeRawPointer(content), visit)
        }
    }

    static func applyChain(at pointer: UnsafeRawPointer, to node: Node, state: inout CollapseState) throws {
        let modifier = pointer.assumingMemoryBound(to: Self.self)
        try modifier.pointee.applyCollapsed(to: node, state: &state)
        guard let next = ElementTypeInfo.of(type: Content.self).collapsibleType else {
            return
        }
        try withUnsafePointer(to: modifier.pointee.content) { content in
            try next.applyChain(at: UnsafeRawPointer(content), to: node, state: &state)
        }
    }

    func visitInnermost(_ visit: (any Element) throws -> Void) throws {
        try withUnsafePointer(to: self) { modifier in
            try Self.visitInnermost(at: UnsafeRawPointer(modifier), visit)
        }
    }

    func applyChain(to node: Node) throws {
        var state = CollapseState()
        try withUnsafePointer(to: self) { modifier in
            try Self.applyChain(at: UnsafeRawPointer(modifier), to: node, state: &state)
        }
        if let parameters = state.parameters {
            node.environmentValues.parameterSet = parameters
        }
    }
}

/// Binds parameters for its subtree.
internal struct ParameterModifier<Content>: Element, WorkloadElement, BodylessContentElement, CollapsibleWorkloadModifier where Content: Element {
    var content: Content
    var apply: (inout ParameterSet) -> Void

    func applyCollapsed(to node: Node, state: inout CollapseState) throws {
        var parameters = state.parameters ?? node.environmentValues.inheritedParameterSet ?? ParameterSet()
        apply(&parameters)
        state.parameters = parameters
    }

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visitInnermost(visit)
    }

    func workloadEnter(_ node: Node) throws {
        try applyChain(to: node)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

/// Writes a draw-state value during workload every frame, so reused nodes never keep an earlier frame's state.
internal struct DrawStateModifier<Content>: Element, WorkloadElement, BodylessContentElement, CollapsibleWorkloadModifier where Content: Element {
    var content: Content
    var apply: (inout MSEnvironmentValues) -> Void

    func applyCollapsed(to node: Node, state: inout CollapseState) throws {
        apply(&node.environmentValues)
    }

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visitInnermost(visit)
    }

    func workloadEnter(_ node: Node) throws {
        try applyChain(to: node)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}

/// Runs `action` with the recording scope during workload, for resource declarations and result callbacks.
internal struct ScopeModifier<Content>: Element, WorkloadElement, BodylessContentElement, CollapsibleWorkloadModifier where Content: Element {
    var content: Content
    var action: (RecordingScope) throws -> Void

    func applyCollapsed(to node: Node, state: inout CollapseState) throws {
        try action(try node.environmentValues.recordingScope.orThrow(.missingEnvironment("recordingScope")))
    }

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        try visitInnermost(visit)
    }

    func workloadEnter(_ node: Node) throws {
        try applyChain(to: node)
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
