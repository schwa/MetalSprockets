import MetalSprockets
import MetalSprocketsUIShaders

internal extension ShaderLibrary {
    static var metalSprocketsUI: ShaderLibrary {
        do {
            return try ShaderLibrary(bundle: .metalSprocketsUIShaders())
        }
        catch {
            fatalError("Failed to load the MetalSprocketsUI shader library, which ships inside the framework: \(error)")
        }
    }
}
