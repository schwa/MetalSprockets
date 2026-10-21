import Metal
@testable import MetalSprockets
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

    // PipelineCache turns off binary linking under capture by class name (#542). This fails if Metal renames the class.
    @Test("PipelineCache detects GPU frame capture")
    func pipelineCacheDetectsCapture() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        #expect(PipelineCache.isCaptureDevice(device) == MetalDebugLayers.captureActive, "Device is \(MetalDebugLayers.deviceClassNames)")
    }
}
