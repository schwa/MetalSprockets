import Metal
import Testing

/// Makes sure a layered run (see MetalDebugLayers.swift) really runs under the layer it asked for.
@Suite("Metal debug layers")
struct MetalDebugLayersTests {
    @Test("Requested API validation is active", .enabled(if: MetalDebugLayers.validationRequested))
    func validationIsActive() {
        #expect(MetalDebugLayers.validationActive, "MTL_DEBUG_LAYER=1 is set, but the device is \(MetalDebugLayers.deviceClassNames)")
    }

    @Test("Requested GPU frame capture is active", .enabled(if: MetalDebugLayers.captureRequested))
    func captureIsActive() {
        #expect(MetalDebugLayers.captureActive, "MTL_CAPTURE_ENABLED=1 is set, but the device is \(MetalDebugLayers.deviceClassNames)")
    }
}
