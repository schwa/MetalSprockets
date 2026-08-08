import Metal
import MetalSprocketsSupport

/// Catches shaders that were compiled on a different `MTLDevice` than the pipeline is being built on.
///
/// Shader libraries are compiled eagerly, before any element tree exists, so they resolve their device at
/// construction time — by default the system default device. On a machine with more than one GPU that can differ from
/// the device the pipeline ends up on, and Metal's own diagnostic for the mismatch is poor. See #55.
internal enum ShaderDeviceCheck {
    /// The name of the first stage whose device doesn't match, or `nil` when they all agree.
    static func mismatchedStage(_ stages: [(name: String, device: ObjectIdentifier)], pipelineDevice: ObjectIdentifier) -> String? {
        stages.first { $0.device != pipelineDevice }?.name
    }

    /// Throws when any of the named functions was created on a device other than `device`.
    static func validate(_ stages: [(name: String, function: MTLFunction?)], device: MTLDevice, label: String?) throws {
        let identified = stages.compactMap { stage in
            stage.function.map { (name: stage.name, device: ObjectIdentifier($0.device)) }
        }
        guard let mismatched = mismatchedStage(identified, pipelineDevice: ObjectIdentifier(device)) else {
            return
        }
        let pipeline = label.map { "pipeline \($0.quoted)" } ?? "pipeline"
        let hint = "Shader libraries pick their device when they are created. Pass the same device to ShaderLibrary (or the shader initialiser) that the renderer uses."
        try _throw(MetalSprocketsError.withHint(.configurationError("The \(mismatched) shader of \(pipeline) was created on a different MTLDevice than \(device.name.quoted)."), hint: hint))
    }
}
