import MetalSprockets
import SwiftUI

// MARK: - SwiftUI Color Parameter

public extension Element {
    /// Binds a SwiftUI `Color` to a shader parameter as a `SIMD4<Float>`.
    ///
    /// Converts the SwiftUI color to device RGB and passes it to the shader
    /// as a float4 (RGBA components, 0.0-1.0 range).
    ///
    /// ## Example
    ///
    /// ```swift
    /// RenderPipeline(vertexShader: vs, fragmentShader: fs) {
    ///     Draw { encoder in ... }
    /// }
    /// .parameter("tintColor", color: .blue)
    /// ```
    ///
    /// In your shader:
    /// ```metal
    /// fragment float4 myFragment(constant float4 &tintColor [[buffer(N)]]) {
    ///     return tintColor;
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - name: The name of the shader parameter to bind.
    ///   - color: The SwiftUI color to convert and bind.
    ///   - functionType: Optional function type to target (vertex, fragment, or both).
    func parameter(_ name: String, color: Color, functionType: MTLFunctionType? = nil) -> some Element {
        // TODO: #102 Also it could take a SwiftUI environment(). Also SRGB?
        parameter(name, functionType: functionType, value: color.deviceRGBComponents)
    }
}

internal extension Color {
    /// The colour's device-RGB components as a shader-ready float4.
    ///
    /// A `Color` can be backed by something that does not convert to device RGB (a pattern, an unusual colour space).
    /// Rendering that as opaque magenta is far friendlier than trapping in the middle of a frame, and it is visually
    /// obvious enough to be noticed.
    var deviceRGBComponents: SIMD4<Float> {
        let fallback = SIMD4<Float>(1, 0, 1, 1)
        let colorspace = CGColorSpaceCreateDeviceRGB()
        guard let converted = resolve(in: .init()).cgColor.converted(to: colorspace, intent: .defaultIntent, options: nil) else {
            logger?.warning("Could not convert \(String(describing: self)) to device RGB; using magenta.")
            return fallback
        }
        guard let components = converted.components, components.count >= 4 else {
            logger?.warning("Device RGB conversion of \(String(describing: self)) produced no components; using magenta.")
            return fallback
        }
        return SIMD4<Float>(Float(components[0]), Float(components[1]), Float(components[2]), Float(components[3]))
    }
}
