import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
public struct MetalSprocketsMacros: CompilerPlugin {
    public let providingMacros: [Macro.Type] = [
        UVEntryMacro.self
    ]

    public init() {
        // This line intentionaly left blank.
    }
}
