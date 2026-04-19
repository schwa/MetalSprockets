import Foundation
@testable import MetalSprockets
import Testing

@Suite
struct SupportTests {
    @Test
    func testAbbreviatedTypeNameStripsGenerics() {
        let array: [Int] = [1, 2, 3]
        // `type(of: array)` is `Array<Int>`; abbreviated strips from the first `<`.
        #expect(abbreviatedTypeName(of: array) == "Array")
    }

    @Test
    func testAbbreviatedTypeNameOfNonGeneric() {
        let s = "hello"
        #expect(abbreviatedTypeName(of: s) == "String")
    }

    @Test
    func testObjectIdentifierShortIdIsAlphaOnly() {
        final class Dummy {}
        let d = Dummy()
        let id = ObjectIdentifier(d).shortId
        #expect(!id.isEmpty)
        // The alphabet is k-z.
        let allowed = Set("klmnopqrstuvwxyz")
        #expect(id.allSatisfy { allowed.contains($0) })
    }

    @Test
    func testObjectIdentifierShortIdDistinguishesObjects() {
        final class Dummy {}
        let a = Dummy()
        let b = Dummy()
        #expect(ObjectIdentifier(a).shortId != ObjectIdentifier(b).shortId)
    }

    @Test
    func testObjectIdentifierShortIdIsStable() {
        final class Dummy {}
        let d = Dummy()
        let id1 = ObjectIdentifier(d).shortId
        let id2 = ObjectIdentifier(d).shortId
        #expect(id1 == id2)
    }
}
