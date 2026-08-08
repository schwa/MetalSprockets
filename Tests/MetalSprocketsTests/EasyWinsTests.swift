import Foundation
import Metal
@testable import MetalSprockets
@testable import MetalSprocketsSupport
@testable import MetalSprocketsUI
import SwiftUI
import Testing

// MARK: - AnyElement

@MainActor
@Suite("AnyElement")
struct AnyElementTests {
    struct Leaf: Element, WorkloadElement {
        var value: Int
        var body: Never { fatalError() }
        func workloadEnter(_ node: Node) throws {
            TestMonitor.shared.logUpdate("leaf-\(value)")
        }
    }

    @Test("eraseToAnyElement wraps and forwards visit")
    func testEraseWrapsBase() throws {
        TestMonitor.shared.reset()
        let system = System()
        try system.update(root: Leaf(value: 42).eraseToAnyElement())
        try system.processWorkload()
        #expect(TestMonitor.shared.updates == ["leaf-42"])
    }

    // See #343: AnyElement only requires setup when the wrapped type changes.
    @Test("AnyElement requiresSetup tracks the wrapped type")
    func testRequiresSetupTracksWrappedType() {
        let a = AnyElement(Leaf(value: 1))
        let b = AnyElement(Leaf(value: 1))
        let other = AnyElement(EmptyElement())
        #expect(a.requiresSetup(comparedTo: b) == false)
        #expect(a.requiresSetup(comparedTo: other) == true)
    }
}

// MARK: - ComputeDispatch init errors + requiresSetup

@MainActor
@Suite("ComputeDispatch additional tests")
struct ComputeDispatchMoreTests {
    @Test("threadsPerGrid succeeds on supported GPUs")
    func testThreadsPerGrid() throws {
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.apple4) else { return }
        _ = try ComputeDispatch(
            threadsPerGrid: MTLSize(width: 16, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
        )
    }

    @Test("requiresSetup is false")
    func testRequiresSetupIsFalse() throws {
        let a = try ComputeDispatch(
            threadgroups: MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
        )
        let b = try ComputeDispatch(
            threadgroups: MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
        )
        #expect(a.requiresSetup(comparedTo: b) == false)
    }
}

// MARK: - ProcessInfo isTruthy parsing

@Suite("ProcessInfo environment flags")
struct ProcessInfoExtensionsTests {
    @Test("All getter properties return Bool without crashing")
    func testFlagsReadable() {
        let info = ProcessInfo.processInfo
        _ = info.loggingEnabled
        _ = info.verboseLoggingEnabled
        _ = info.fatalErrorOnThrow
        _ = info.metalLoggingEnabled
        _ = info.dumpSnapshotsEnabled
        _ = info.renderViewLogFrameEnabled
    }

    // isTruthy is a private extension; covered indirectly above.
    // The parser accepts ["yes","true","y","1","on"] regardless of case/whitespace.
    // We can only exercise it via public APIs, which we've just done.
}

// MARK: - CommandBufferLogging

@Suite("CommandBufferLogging")
struct CommandBufferLoggingTests {
    @Test(
        "addMetalSprocketsLogging attaches a log state",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Metal log state unavailable on CI runners")
    )
    func testAddMetalSprocketsLogging() throws {
        let descriptor = MTLCommandBufferDescriptor()
        #expect(descriptor.logState == nil)
        try descriptor.addMetalSprocketsLogging(device: MTLCreateSystemDefaultDevice()!)
        #expect(descriptor.logState != nil)
    }
}

// MARK: - SwiftUI Color parameter

@MainActor
@Suite("Parameter+SwiftUI")
struct ParameterSwiftUITests {
    struct Leaf: Element, BodylessElement { var body: Never { fatalError() } }

    @Test(".parameter(name:color:) returns a ParameterElementModifier")
    func testColorParameterReturnsModifier() {
        let e = Leaf().parameter("tint", color: Color.red)
        #expect(e is ParameterElementModifier<Leaf>)
    }

    @Test(".parameter(name:color:functionType:) targets fragment")
    func testColorParameterWithFunctionType() {
        let e = Leaf().parameter("tint", color: Color.blue, functionType: .fragment)
        guard let modifier = e as? ParameterElementModifier<Leaf> else {
            Issue.record("Expected ParameterElementModifier")
            return
        }
        #expect(modifier.parameters[name: "tint"]?.functionTypes == .fragment)
    }
}
