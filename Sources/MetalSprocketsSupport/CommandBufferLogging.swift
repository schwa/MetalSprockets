import Metal
import MetalSupport

public extension MTLCommandBufferDescriptor {
    /// Attaches a default log state that routes shader logs to the MetalSprockets logger.
    func addMetalSprocketsLogging() throws {
        let logStateDescriptor = MTLLogStateDescriptor()
        logStateDescriptor.bufferSize = 32 * 1_024 * 1_024
        let device = _MTLCreateSystemDefaultDevice()
        let logState = try device.makeLogState(descriptor: logStateDescriptor)
        logState.addLogHandler { _, _, _, message in
            logger?.log("\(message)")
        }
        self.logState = logState
    }
}
