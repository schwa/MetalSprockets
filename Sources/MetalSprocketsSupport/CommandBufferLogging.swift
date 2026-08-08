import Metal
import MetalSupport

public extension MTLCommandBufferDescriptor {
    /// Attaches a default log state that routes shader logs to the MetalSprockets logger.
    /// - Parameter device: The device that owns the log state. Pass the device the command
    ///   buffer will actually be encoded on rather than relying on the system default. See #55.
    func addMetalSprocketsLogging(device: MTLDevice) throws {
        let logStateDescriptor = MTLLogStateDescriptor()
        logStateDescriptor.bufferSize = 32 * 1_024 * 1_024
        let logState = try device.makeLogState(descriptor: logStateDescriptor)
        logState.addLogHandler { _, _, _, message in
            logger?.log("\(message)")
        }
        self.logState = logState
    }
}
