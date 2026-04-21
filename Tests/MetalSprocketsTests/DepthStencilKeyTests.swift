import Metal
@testable import MetalSprockets
import Testing

@Suite("DepthStencilKey")
struct DepthStencilKeyTests {
    // MARK: - Contents-based hashing (#314)

    @Test("Two descriptors with identical contents produce equal keys")
    func testIdenticalContentsEqualKeys() {
        let a = MTLDepthStencilDescriptor()
        a.depthCompareFunction = .less
        a.isDepthWriteEnabled = true

        let b = MTLDepthStencilDescriptor()
        b.depthCompareFunction = .less
        b.isDepthWriteEnabled = true

        // Different object identities, same contents.
        #expect(ObjectIdentifier(a) != ObjectIdentifier(b))
        #expect(DepthStencilKey(a) == DepthStencilKey(b))
    }

    @Test("Descriptors differing only in compareFunction produce distinct keys")
    func testDifferentCompareFunction() {
        let a = MTLDepthStencilDescriptor()
        a.depthCompareFunction = .less
        a.isDepthWriteEnabled = true

        let b = MTLDepthStencilDescriptor()
        b.depthCompareFunction = .greater
        b.isDepthWriteEnabled = true

        #expect(DepthStencilKey(a) != DepthStencilKey(b))
    }

    @Test("Descriptors differing only in isDepthWriteEnabled produce distinct keys")
    func testDifferentDepthWriteEnabled() {
        let a = MTLDepthStencilDescriptor()
        a.depthCompareFunction = .less
        a.isDepthWriteEnabled = true

        let b = MTLDepthStencilDescriptor()
        b.depthCompareFunction = .less
        b.isDepthWriteEnabled = false

        #expect(DepthStencilKey(a) != DepthStencilKey(b))
    }

    // MARK: - Regression: .depthCompare produces fresh descriptor per call

    /// `.depthCompare(function:enabled:)` is implemented as a fresh
    /// `MTLDepthStencilDescriptor()` allocation every invocation. Without a
    /// contents-based key the RenderPipeline cache would miss every frame (the
    /// perf-regression half of #314). With `DepthStencilKey` the key should
    /// compare equal across two invocations with identical arguments.
    @Test("Fresh descriptors built with matching fields produce equal keys")
    func testSimulatedDepthCompareStability() {
        func build(function: MTLCompareFunction, enabled: Bool) -> MTLDepthStencilDescriptor {
            MTLDepthStencilDescriptor(depthCompareFunction: function, isDepthWriteEnabled: enabled)
        }
        let first = build(function: .less, enabled: true)
        let second = build(function: .less, enabled: true)
        #expect(ObjectIdentifier(first) != ObjectIdentifier(second))
        #expect(DepthStencilKey(first) == DepthStencilKey(second))

        let third = build(function: .greater, enabled: true)
        #expect(DepthStencilKey(first) != DepthStencilKey(third))
    }
}
