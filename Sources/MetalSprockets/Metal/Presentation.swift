import Metal

/// A drawable-like target whose display must be ordered around a submission's GPU work.
internal protocol Presentable {
    /// Enqueues a wait so the work committed next does not start until the display releases the target.
    func waitForAvailability(on queue: any MTL4CommandQueue)
    /// Enqueues a signal after the committed work, marking the target ready to display.
    func signalCompletion(on queue: any MTL4CommandQueue)
    func present()
}

internal struct DrawablePresentation: Presentable {
    let drawable: any MTLDrawable

    func waitForAvailability(on queue: any MTL4CommandQueue) {
        queue.waitForDrawable(drawable)
    }

    func signalCompletion(on queue: any MTL4CommandQueue) {
        queue.signalDrawable(drawable)
    }

    func present() {
        drawable.present()
    }
}
