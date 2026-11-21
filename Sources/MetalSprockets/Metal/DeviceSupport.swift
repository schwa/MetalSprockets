import Metal

public extension MTLDevice {
    /// Whether MetalSprockets can render on this device. MetalSprockets needs Metal 4 and has no fallback.
    ///
    /// Check this before you show a `RenderView` or create a renderer, and show other content when it is `false`.
    var supportsMetalSprockets: Bool {
        supportsFamily(.metal4)
    }
}

/// Reports whether the system default Metal device can run MetalSprockets.
///
/// Returns `false` when there is no Metal device. See ``Metal/MTLDevice/supportsMetalSprockets``.
public func isMetalSprocketsSupported() -> Bool {
    // swiftlint:disable:next MTLCreateSystemDefaultDevice
    MTLCreateSystemDefaultDevice()?.supportsMetalSprockets ?? false // No device must return false, not trap.

}
