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

    /// Runs `action` on the calling isolation (for example the `@MainActor`) with the submission's terminal result, so
    /// it can write `@MSState` directly without a manual actor hop.
    ///
    /// Unlike ``onCommandBufferCompleted(_:)``, `action` is not `@Sendable`: it may capture isolated state such as an
    /// element's `self`. The hop is asynchronous: `action` runs in a `Task` on `isolation` after the GPU work finishes,
    /// so it never blocks the completion executor, and its ordering against other submissions is not guaranteed. Work
    /// that fails during encoding reports nothing.
    ///
    /// ```swift
    /// .onCommandBufferCompleted { result in   // this @MainActor closure can now write @MSState
    ///     baked = result.outcome == .completed
    /// }
    /// ```
    func onCommandBufferCompleted(
        isolation: isolated (any Actor)? = #isolation,
        perform action: @escaping (SubmissionResult) -> Void
    ) -> some Element {
        let transfer = UncheckedTransfer(action)
        return ScopeModifier(content: self) { scope in
            try scope.onTerminated { result in
                Task { await runIsolated(on: isolation, transfer, result) }
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
    /// `action` may run on a completion executor or during teardown; do not assume the caller's actor.
    func onSubmissionFinished(_ action: @escaping @Sendable () -> Void) -> some Element {
        ScopeModifier(content: self) { scope in
            let sentinel = SubmissionFinishSentinel(action)
            // Retained through completion; deinit also fires it if encoding fails.
            try scope.retain(sentinel)
            try scope.onTerminated { _ in sentinel.fire() }
        }
    }
}

/// Carries a non-`Sendable` value into a `@Sendable` closure so it can be delivered to an isolated executor. The
/// caller guarantees the value is only touched after the hop to that isolation.
private struct UncheckedTransfer<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

/// Runs the transferred action on `actor`. Being `isolated`, calling it from a `Task` hops onto that isolation before
/// the non-`Sendable` action runs.
private func runIsolated(
    on actor: isolated (any Actor)?,
    _ transfer: UncheckedTransfer<(SubmissionResult) -> Void>,
    _ result: SubmissionResult
) {
    transfer.value(result)
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
