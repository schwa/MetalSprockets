import Metal

/// Value-type digest of the fields of `MTLDepthStencilDescriptor` that affect
/// the resulting `MTLDepthStencilState`. Used as part of pipeline cache keys
/// so that descriptors with identical contents (but different object identity)
/// hit the cache instead of forcing a rebuild every frame.
///
/// Without this, helpers like `.depthCompare(function:enabled:)` that allocate
/// a fresh `MTLDepthStencilDescriptor` every call would defeat the per-node
/// pipeline cache introduced in #333 — see #314.
internal struct DepthStencilKey: Hashable {
    let depthCompareFunction: MTLCompareFunction
    let isDepthWriteEnabled: Bool

    init(_ descriptor: MTLDepthStencilDescriptor) {
        self.depthCompareFunction = descriptor.depthCompareFunction
        self.isDepthWriteEnabled = descriptor.isDepthWriteEnabled
    }
}
