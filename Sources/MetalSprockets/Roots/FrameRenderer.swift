import Foundation
import MetalSprocketsSupport
import os
import QuartzCore

/// Drives one frame of an element tree: update, setup, workload, in that order.
///
/// The phase ordering is a contract, not a caller responsibility — every driver (``Runner``, `RenderView`, the
/// visionOS immersive runtime) shares this one implementation instead of repeating the sequence. See #296.
///
/// - Note: Like ``System``, a `FrameRenderer` must stay confined to a single isolation context. Only
///   ``lastGPUTime`` is safe to touch from elsewhere, because command-buffer completion handlers run off-thread.
package final class FrameRenderer: @unchecked Sendable {
    /// How long each phase of a frame took.
    package typealias PhaseTimings = System.PhaseTimings

    /// The engine driven by this renderer. Nodes and state persist across frames.
    package let system: System

    private let _lastGPUTime = OSAllocatedUnfairLock<TimeInterval?>(initialState: nil)

    /// GPU execution time of the most recently completed command buffer, or `nil` if none has completed.
    ///
    /// Safe to write from a command-buffer completion handler.
    package var lastGPUTime: TimeInterval? {
        get { _lastGPUTime.withLock { $0 } }
        set { _lastGPUTime.withLock { $0 = newValue } }
    }

    package init(system: System = System()) {
        self.system = system
    }

    /// Marks every node as needing setup again, e.g. after a drawable-size or sample-count change.
    package func invalidateSetup() {
        system.markAllNodesNeedingSetup()
    }

    /// Runs one frame for the given root element and reports how long each phase took.
    @discardableResult
    package func renderFrame(root: some Element) throws -> PhaseTimings {
        try system.render(root: root)
    }
}
