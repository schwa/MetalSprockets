import Metal
import Testing

extension Trait where Self == ConditionTrait {
    /// Skips tests that need a Metal 4 GPU. CI runners use a paravirtual device without Metal 4 (#444).
    static var requiresMetal4: Self {
        .enabled(if: MTLCreateSystemDefaultDevice()?.supportsFamily(.metal4) == true, "Requires a Metal 4-capable device")
    }
}
