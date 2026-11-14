import Foundation
internal import os

/// A dedicated thread with its own run loop. RenderView uses one per view to build, encode and commit frames off the
/// main thread (#560). It is not a Swift concurrency executor: frames block on drawables and in-flight limits.
internal final class RenderThread: Sendable {
    private struct State: @unchecked Sendable {
        var runLoop: CFRunLoop?
        var isStopped = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    init(name: String = "MetalSprockets.RenderThread") {
        let started = DispatchSemaphore(value: 0)
        let thread = Thread { [state] in
            let runLoop = CFRunLoopGetCurrent()
            // A port keeps the run loop alive while nothing else is scheduled.
            RunLoop.current.add(NSMachPort(), forMode: .default)
            state.withLockUnchecked { $0.runLoop = runLoop }
            started.signal()
            while !state.withLock({ $0.isStopped }) {
                autoreleasepool {
                    _ = RunLoop.current.run(mode: .default, before: .distantFuture)
                }
            }
            state.withLock { $0.runLoop = nil }
        }
        thread.name = name
        thread.qualityOfService = .userInteractive
        thread.start()
        started.wait()
    }

    /// `false` once the thread has left its run loop.
    var isRunning: Bool {
        state.withLockUnchecked { $0.runLoop != nil }
    }

    /// Runs `work` on the render thread, after work already queued.
    func perform(_ work: @escaping @Sendable () -> Void) {
        let runLoop: CFRunLoop? = state.withLockUnchecked { state in
            state.isStopped ? nil : state.runLoop
        }
        guard let runLoop else {
            return
        }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, work)
        CFRunLoopWakeUp(runLoop)
    }

    /// Runs `work` on the render thread, then lets the thread exit. Work queued later is dropped.
    func stop(after work: @escaping @Sendable () -> Void = { /* nothing to run first */ }) {
        perform { [state] in
            work()
            state.withLock { $0.isStopped = true }
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
    }
}
