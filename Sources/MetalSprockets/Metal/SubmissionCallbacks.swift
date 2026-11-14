import Metal
import os

// MARK: - Submission callbacks

public extension Element {
    /// Runs `action` after the recording this element encodes into is committed to the queue, on the committing
    /// thread, with the submission identifier.
    ///
    /// This is a CPU-side notification that commit returned. It does not mean the GPU has started the work, and a later
    /// result can still report a failure. Use ``onCommandBufferCompleted(_:)`` for the outcome and GPU timing.
    func onSubmissionCommitted(_ action: @escaping (UInt64) -> Void) -> some Element {
        ScopeModifier(content: self) { scope in
            try scope.onCommitted(action)
        }
    }

    /// Runs `action` once with the terminal result of the submission this element encodes into.
    ///
    /// `action` runs on a serial completion executor, not the caller's actor. Transfer values to your own actor
    /// explicitly. Encoding failures report nothing.
    ///
    /// ```swift
    /// .onCommandBufferCompleted { result in
    ///     let milliseconds = (result.gpuDuration ?? 0) * 1_000
    ///     Task { @MainActor in model.gpuTime = milliseconds }
    /// }
    /// ```
    func onCommandBufferCompleted(_ action: @escaping @Sendable (SubmissionResult) -> Void) -> some Element {
        ScopeModifier(content: self) { scope in
            try scope.onTerminated(action)
        }
    }

    /// Runs `action` on its own isolation (for example the `@MainActor`) with the submission's terminal result.
    ///
    /// A closure written on an actor keeps that actor, so it can use the actor's state without a manual hop. A
    /// closure with no actor runs on a concurrent executor; it is `@Sendable`, so that is safe (#567). The hop is
    /// asynchronous. After the GPU work finishes, `action` runs in a `Task`. Thus it never blocks the completion
    /// executor. Its order relative to other submissions can change. Work that fails during encoding reports nothing.
    ///
    /// ```swift
    /// .onCommandBufferCompleted { @MainActor result in
    ///     model.baked = result.outcome == .completed
    /// }
    /// ```
    func onCommandBufferCompleted(
        perform action: @escaping @isolated(any) @Sendable (SubmissionResult) -> Void
    ) -> some Element {
        ScopeModifier(content: self) { scope in
            try scope.onTerminated { result in
                Task { await action(result) }
            }
        }
    }

    /// Runs `action` exactly once when the submission this element encodes into finishes, whatever its outcome:
    /// completed, failed, timed out, or failed during encoding.
    ///
    /// Unlike ``onCommandBufferCompleted(_:)``, it also fires when encoding fails, so a
    /// per-frame resource ring can reclaim its slot without leaking. Use it to recycle instance buffers, build scratch
    /// buffers and acceleration structures once the GPU can no longer reference them.
    ///
    /// `action` can run on a completion executor or during teardown. Do not assume the actor of the caller.
    func onSubmissionFinished(_ action: @escaping @Sendable () -> Void) -> some Element {
        ScopeModifier(content: self) { scope in
            let sentinel = SubmissionFinishSentinel(action)
            // Retained through completion; deinit also fires it if encoding fails.
            try scope.retain(sentinel)
            try scope.onTerminated { _ in sentinel.fire() }
        }
    }
}

/// Fires once on GPU termination, or from deinit if encoding fails before submission.
private final class SubmissionFinishSentinel: Sendable {
    private let action: OSAllocatedUnfairLock<(@Sendable () -> Void)?>

    init(_ action: @escaping @Sendable () -> Void) {
        self.action = OSAllocatedUnfairLock(initialState: action)
    }

    func fire() {
        let pending = action.withLock { stored -> (@Sendable () -> Void)? in
            defer { stored = nil }
            return stored
        }
        pending?()
    }

    deinit {
        fire()
    }
}
