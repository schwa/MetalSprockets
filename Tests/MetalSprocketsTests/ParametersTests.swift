@testable import MetalSprockets
import Testing

// Parameter binding behavior on Metal 4 is covered by ParameterBindingTests, ParameterCollapseTests,
// MultiStageParameterTests and ArgumentBindingTests. The legacy ParameterValue/Parameter internals are gone.
@Suite
struct ParametersTests {
    @Test
    func testStringQuoted() {
        let string = "test"
        #expect(string.quoted == "\"test\"")

        let optional: String? = "optional"
        #expect(optional.quoted == "\"optional\"")

        let nilString: String? = nil
        #expect(nilString.quoted == "nil")
    }
}
