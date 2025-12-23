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
    // TODO: #102 Also it could take a SwiftUI environment(). Also SRGB?
    func parameter(_ name: String, color: Color, functionType: MTLFunctionType? = nil) -> some Element {
        let colorspace = CGColorSpaceCreateDeviceRGB()
        guard let color = color.resolve(in: .init()).cgColor.converted(to: colorspace, intent: .defaultIntent, options: nil) else {
            preconditionFailure("Unimplemented.")
        }
        guard let components = color.components?.map({ Float($0) }) else {
            preconditionFailure("Unimplemented.")
        }
        let value = SIMD4<Float>(components[0], components[1], components[2], components[3])
        return parameter(name, functionType: functionType, value: value)
    }
}
