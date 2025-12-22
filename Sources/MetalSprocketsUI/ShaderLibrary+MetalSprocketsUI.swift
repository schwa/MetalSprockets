import MetalSprockets
import MetalSprocketsUIShaders

internal extension ShaderLibrary {
    static var metalSprocketsUI: ShaderLibrary {
        // swiftlint:disable:next force_try
        try! ShaderLibrary(bundle: .metalSprocketsUIShaders())
    }
}
