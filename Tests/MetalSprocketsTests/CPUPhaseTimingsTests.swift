import CoreGraphics
import Metal
import MetalSprockets
import Testing

@MainActor
@Suite("CPU phase timings", .requiresMetal4)
struct CPUPhaseTimingsTests {
    @Test func `an offscreen render reports its update, setup and workload times`() throws {
        let renderer = try OffscreenRenderer(size: CGSize(width: 16, height: 16))
        let rendering = try renderer.render(try RenderPass { EmptyElement() })
        let timings = try #require(rendering.cpuPhaseTimings)
        #expect(timings.content == nil)
        #expect(timings.update >= 0 && timings.setup >= 0 && timings.workload >= 0)
        #expect(timings.total > 0)
        #expect(timings.total == timings.update + timings.setup + timings.workload)
    }

    @Test func `total includes content when it is known`() {
        let timings = CPUPhaseTimings(content: 1, update: 2, setup: 3, workload: 4)
        #expect(timings.total == 10)
    }
}
