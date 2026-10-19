import Metal

/// Value-type digest of the fields of `MTLDepthStencilDescriptor` that affect
/// the resulting `MTLDepthStencilState`. Used as part of pipeline cache keys
/// so that descriptors with identical contents (but different object identity)
/// hit the cache instead of forcing a rebuild every frame.
///
/// Helpers like `.depthCompare(function:writes:)` make a new
/// `MTLDepthStencilDescriptor` on every call. Without this key, each new
/// descriptor causes a miss in the per-node pipeline cache from #333. See #314.
internal struct DepthStencilKey: Hashable {
    let depthCompareFunction: MTLCompareFunction
    let isDepthWriteEnabled: Bool

    init(_ descriptor: MTLDepthStencilDescriptor) {
        self.depthCompareFunction = descriptor.depthCompareFunction
        self.isDepthWriteEnabled = descriptor.isDepthWriteEnabled
    }
}
