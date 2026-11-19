import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
public struct MetalSprocketsMacros: CompilerPlugin {
    public let providingMacros: [Macro.Type] = [
        MSEntryMacro.self,
        MSStateMacro.self,
        MSStateProjectedValueMacro.self
    ]

    public init() {
        // This line intentionally left blank.
    }
}
