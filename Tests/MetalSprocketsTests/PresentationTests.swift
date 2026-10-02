import Metal
@testable import MetalSprockets
import os
import Testing

private final class PresentationLog: @unchecked Sendable {
    private let entries = OSAllocatedUnfairLock<[String]>(initialState: [])
    var all: [String] { entries.withLock { $0 } }
    func append(_ entry: String) { entries.withLock { $0.append(entry) } }
}

private struct RecordingPresentable: Presentable {
    let log: PresentationLog
    func waitForAvailability(on queue: any MTL4CommandQueue) { log.append("wait") }
    func signalCompletion(on queue: any MTL4CommandQueue) { log.append("signal") }
    func present() { log.append("present") }
}

@Suite("Metal 4 presentation order", .requiresMetal4)
struct PresentationTests {
    @Test(.timeLimit(.minutes(1)))
    func presentationWaitsBeforeCommitAndSignalsAndPresentsAfter() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let context = try MetalContext(device: device)
        let log = PresentationLog()
        context.onSubmissionCommitted { _, _ in log.append("commit") }
        let submission = try context.submit(presenting: RecordingPresentable(log: log)) { _ in }
        _ = try await context.awaitResult(submission)
        #expect(log.all == ["wait", "commit", "signal", "present"])
    }
}
