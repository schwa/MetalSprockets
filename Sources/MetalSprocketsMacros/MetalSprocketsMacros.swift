import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
public struct MetalSprocketsMacros: CompilerPlugin {
    public let providingMacros: [Macro.Type] = [
        MSEntryMacro.self
    ]

    public init() {
        // This line intentionaly left blank.
    }
}
