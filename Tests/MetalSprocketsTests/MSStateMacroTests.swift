import SwiftSyntaxMacrosTestSupport
import XCTest
#if canImport(MetalSprocketsMacros)
// periphery:ignore
import MetalSprocketsMacros
#endif

@MainActor
final class MSStateMacroTests: XCTestCase {
    func testLocalVariableIsDiagnosed() throws {
        #if canImport(MetalSprocketsMacros)
        assertMacroExpansion(
            """
            func f() {
                @MSState var x = 0
            }
            """,
            expandedSource:
                """
            func f() {
                var x = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@MSState can only be applied to a property of a type, not a local or global variable", line: 2, column: 5)
            ],
            macros: ["MSState": MSStateMacro.self]
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
