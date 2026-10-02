import Foundation
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

private final class SubmissionResourceOwner: Sendable {
    let released: (any MTLSharedEvent)?

    init(released: (any MTLSharedEvent)? = nil) {
        self.released = released
    }

    deinit {
        released?.signaledValue = 1
    }
}

@MainActor
@Suite("Metal 4 submissions", .requiresMetal4)
struct SubmissionTests {
    private enum TestFailure: Error {
        case encoding
    }

    @Test
    func `throwing encoding releases owners and invalidates escaped encoding state`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device, maximumInFlightSubmissions: 1)
        var escapedScope: RecordingScope?
        weak var weakOwner: SubmissionResourceOwner?
        #expect(throws: TestFailure.encoding) {
            try context.submit { scope in
                escapedScope = scope
                let owner = SubmissionResourceOwner()
                weakOwner = owner
                try scope.retain(owner)
                try scope.withComputeEncoder { _ in throw TestFailure.encoding }
            }
        }
        #expect(weakOwner == nil)
        #expect(context.inFlightCount == 0)
        #expect(context.completionEvent.signaledValue == 0)
        #expect(throws: RecordingScope.Failure.encodingEnded) {
            try #require(escapedScope).withComputeEncoder { _ in }
        }
        let next = try context.submit { _ in }
        #expect(next.identifier == 1)
        try context.waitForResult(next)
    }

    @Test
    func `throwing render encoding and nested encoders leave no submitted work`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        textureDescriptor.usage = .renderTarget
        let texture = try #require(device.makeTexture(descriptor: textureDescriptor))
        let descriptor = MTL4RenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .dontCare
        #expect(throws: TestFailure.encoding) {
            try context.submit { scope in
                try scope.retainAllocation(texture)
                try scope.withRenderEncoder(descriptor: descriptor) { _ in throw TestFailure.encoding }
            }
        }
        #expect(throws: RecordingScope.Failure.nestedEncoder) {
            try context.submit { scope in
                try scope.withComputeEncoder { _ in try scope.withComputeEncoder { _ in } }
            }
        }
        #expect(context.inFlightCount == 0)
        #expect(context.completionEvent.signaledValue == 0)
    }

    @Test
    func `recursive submission is rejected without interrupting the outer encoding`() throws {
        let context = try MetalContext(device: #require(MTLCreateSystemDefaultDevice()))
        let submission = try context.submit { _ in
            #expect(throws: MetalSprocketsError.self) { try context.submit { _ in } }
        }
        #expect(try context.waitForResult(submission).outcome == .completed)
    }

    @Test(.timeLimit(.minutes(1)))
    func `submitted owners survive dropped handles and context`() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let gate = try #require(device.makeSharedEvent())
        let released = try #require(device.makeSharedEvent())
        var context: MetalContext? = try MetalContext(device: device)
        let weakContext = WeakBox(try #require(context))
        try #require(context).commandQueue.waitForEvent(gate, value: 1)
        defer { gate.signaledValue = 1 }
        weak var weakOwner: SubmissionResourceOwner?
        try autoreleasepool {
            let owner = SubmissionResourceOwner(released: released)
            weakOwner = owner
            try #require(context).submit { try $0.retain(owner) }
        }
        context = nil
        #expect(weakContext.wrappedValue == nil)
        #expect(weakOwner != nil)
        #expect(released.signaledValue == 0)
        gate.signaledValue = 1
        await released.valueSignaled(1)
        #expect(weakOwner == nil)
    }
}
