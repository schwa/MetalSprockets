@testable import MetalSprockets
import MetalSprocketsSupport
import Testing

// #461: missing-environment errors must name the property as a plain identifier in every build configuration.
@MainActor
struct MissingEnvironmentNameTests {
    @Test
    func `a draw outside a render pass names the missing encoder`() throws {
        let system = System()
        try system.update(root: Draw { _ in })
        let error = #expect(throws: MetalSprocketsError.self) {
            try system.withCurrentSystem { try system.processWorkload() }
        }
        #expect(error?.description.hasPrefix("Missing environment value: renderCommandEncoder\n") == true)
    }
}
