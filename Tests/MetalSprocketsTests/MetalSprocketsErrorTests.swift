import MetalSprocketsSupport
import Testing

@Suite("MetalSprocketsError Description Tests")
struct MetalSprocketsErrorTests {
    @Test("Each case stringifies correctly")
    func descriptions() {
        #expect(String(describing: MetalSprocketsError.undefined) == "Undefined error")
        #expect(String(describing: MetalSprocketsError.generic("boom")) == "boom")
        #expect(String(describing: MetalSprocketsError.missingEnvironment("device")) == "Missing environment value: device")
        #expect(String(describing: MetalSprocketsError.missingBinding("color")) == "Missing binding: color")
        #expect(String(describing: MetalSprocketsError.resourceCreationFailure("tex")).contains("Resource creation failure: tex"))
        #expect(String(describing: MetalSprocketsError.deviceCababilityFailure("no mesh")).contains("Device capability failure: no mesh"))
        #expect(String(describing: MetalSprocketsError.validationError("bad")).contains("Validation error: bad"))
        #expect(String(describing: MetalSprocketsError.configurationError("oops")).contains("Configuration error: oops"))
        #expect(String(describing: MetalSprocketsError.unexpectedError(.undefined)).contains("Unexpected error"))
    }

    @Test("withHint appends the hint to the wrapped description")
    func withHintDescription() {
        let err = MetalSprocketsError.withHint(.missingBinding("color"), hint: "check your shader")
        let description = String(describing: err)
        #expect(description.contains("Missing binding: color"))
        #expect(description.contains("Hint: check your shader"))
    }

    @Test("Optional.orThrow returns the value when non-nil")
    func orThrowReturnsValue() throws {
        let opt: Int? = 42
        let value = try opt.orThrow(.undefined)
        #expect(value == 42)
    }

    @Test("Optional.orThrow throws when nil")
    func orThrowThrows() {
        let opt: Int? = nil
        #expect(throws: MetalSprocketsError.missingBinding("x")) {
            _ = try opt.orThrow(.missingBinding("x"))
        }
    }

    @Test("Optional.orFatalError(message:) returns the value when non-nil")
    func orFatalErrorMessageReturnsValue() {
        let opt: Int? = 7
        #expect(opt.orFatalError("unreached") == 7)
    }

    @Test("Optional.orFatalError(error:) returns the value when non-nil")
    func orFatalErrorErrorReturnsValue() {
        let opt: String? = "hi"
        #expect(opt.orFatalError(MetalSprocketsError.undefined) == "hi")
    }
}
