import Metal
@testable import MetalSprockets
import os
import Testing

// #570: an element can write its own @MSState from a Sendable completion handler by capturing the state's storage.
private struct BakingElement: Element {
    @MSState var baked = false
    let observed: OSAllocatedUnfairLock<Bool>

    // Explicit: Swift 6.2 (Xcode 26) makes the memberwise initializer private next to @MSState storage.
    init(observed: OSAllocatedUnfairLock<Bool>) { self.observed = observed }

    var body: some Element {
        get throws {
            let baked = baked
            // `let _ =`: a declaration, which the element builder skips.
            // swiftlint:disable:next redundant_discardable_let
            let _ = observed.withLock { $0 = baked }
            // swiftlint:disable:next trailing_closure
            EmptyElement().onCommandBufferCompleted(perform: { [_baked] result in
                _baked.wrappedValue = result.outcome == .completed
            })
        }
    }
}

@Test(.requiresMetal4, .timeLimit(.minutes(1)))
func msStateWrittenFromACompletionHandlerReachesTheNextFrame() async throws {
    let observed = OSAllocatedUnfairLock(initialState: false)
    let runner = try Runner()
    let element = BakingElement(observed: observed)
    try runner.run(element)
    #expect(observed.withLock { $0 } == false)
    for _ in 0..<200 where !observed.withLock({ $0 }) {
        try await Task.sleep(for: .milliseconds(10))
        try runner.run(element)
    }
    #expect(observed.withLock { $0 })
}
