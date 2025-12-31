#if os(visionOS)
import ARKit
@preconcurrency import CompositorServices
import Metal
import MetalSprockets
import simd
import SwiftUI

@globalActor
internal actor ImmersiveRendererActor {
    static let shared = ImmersiveRendererActor()
}

internal extension LayerRenderer.Clock.Instant.Duration {
    var toTimeInterval: TimeInterval {
        let nanoseconds = TimeInterval(components.attoseconds / 1_000_000_000)
        return TimeInterval(components.seconds) + (nanoseconds / TimeInterval(NSEC_PER_SEC))
    }
}
#endif
