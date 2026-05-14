import Metal
import MetalSprocketsSupport
import MetalSupport

public extension Element {
    /// Runs the element tree once against a freshly-created device and command
    /// queue.
    ///
    /// This is a convenience for one-shot, headless execution. For repeated
    /// execution of the same (or structurally similar) tree, prefer ``Runner``,
    /// which amortizes setup work across calls.
    func run() throws {
        let runner = try Runner()
        try runner.run(self)
    }
}
