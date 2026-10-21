import Foundation
import Metal
import Testing

// Xcode Debug runs turn on Metal API validation (MTL_DEBUG_LAYER) and GPU frame capture (MTL_CAPTURE_ENABLED) by
// default. Both layers wrap the device, and some Metal usage fails only under them (#541, #542). Metal reads
// these variables once, when it creates the first device. All tests run in one process, and test planning creates
// that device (see `.requiresMetal4`), so a trait cannot turn a layer on. To test under a layer, set the variable
// for the whole run:
//
//     xcb test -e MTL_DEBUG_LAYER=1
//     xcb test -e MTL_CAPTURE_ENABLED=1
//
// Scripts/test-metal-layers.sh runs the suite in all three configurations.

enum MetalDebugLayers {
    static var validationRequested: Bool { ProcessInfo.processInfo.environment["MTL_DEBUG_LAYER"] == "1" }
    static var captureRequested: Bool { ProcessInfo.processInfo.environment["MTL_CAPTURE_ENABLED"] == "1" }

    /// The class names of the default device, outermost first. Capture wraps validation when both are on.
    static let deviceClassNames: [String] = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return []
        }
        var names: [String] = []
        var object: AnyObject? = device
        while let current = object, names.count < 4 {
            names.append(String(describing: type(of: current)))
            object = Self.wrappedObject(of: current)
        }
        return names
    }()

    static var validationActive: Bool { deviceClassNames.contains { $0.contains("Debug") } }
    static var captureActive: Bool { deviceClassNames.contains { $0.hasPrefix("Capture") } }

    /// Layer wrappers expose the device they wrap as `baseObject`. This is private API, used here only to report layers.
    private static func wrappedObject(of object: AnyObject) -> AnyObject? {
        let selector = NSSelectorFromString("baseObject")
        guard let object = object as? NSObject, object.responds(to: selector) else {
            return nil
        }
        return object.perform(selector)?.takeUnretainedValue()
    }
}

extension Trait where Self == ConditionTrait {
    /// Skips a test while GPU frame capture is active, for a known capture failure. Name the issue in `comment`.
    static func disabledUnderCapture(_ comment: Comment) -> Self {
        .disabled(if: MetalDebugLayers.captureActive, comment)
    }

    /// Skips a test while Metal API validation is active, for a known validation failure. Name the issue in `comment`.
    static func disabledUnderValidation(_ comment: Comment) -> Self {
        .disabled(if: MetalDebugLayers.validationActive, comment)
    }
}
