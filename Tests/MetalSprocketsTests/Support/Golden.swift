import CoreGraphics
import Foundation
import GoldenImage
@testable import MetalSprockets
import Testing

/// Golden-image comparison for the test suite.
///
/// Reference images live in `Tests/MetalSprocketsTests/Golden Images`. When a reference is missing, the comparison
/// writes the rendered image to `$TMPDIR/MetalSprocketsGoldenImages` and fails, so a new reference can be inspected
/// and copied in deliberately rather than blessed by accident.
internal enum Golden {
    /// Where images are written when there is nothing to compare against.
    static var failureOutputDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MetalSprocketsGoldenImages")
    }

    static func comparison(psnrThreshold: Double = 120.0) throws -> GoldenImageComparison {
        let directory = try #require(Bundle.module.resourceURL?.appendingPathComponent("Golden Images"))
        return GoldenImageComparison(
            imageDirectory: directory,
            options: .ignoreEdgeAAHalos,
            psnrThreshold: psnrThreshold,
            failureOutputDirectory: failureOutputDirectory
        )
    }

    /// Fails the calling test unless `image` matches the named reference.
    static func verify(_ image: CGImage, named name: String, psnrThreshold: Double = 120.0, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let matches = try comparison(psnrThreshold: psnrThreshold).image(image: image, matchesGoldenImageNamed: name)
        #expect(matches, "Rendered image does not match golden image \(name.quoted).", sourceLocation: sourceLocation)
    }

    /// Renders an element offscreen and compares the result against the named reference.
    static func verify(_ element: some Element, named name: String, size: CGSize = CGSize(width: 256, height: 256), psnrThreshold: Double = 120.0, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let renderer = try OffscreenRenderer(size: size)
        let rendering = try renderer.render(element)
        try verify(rendering.cgImage, named: name, psnrThreshold: psnrThreshold, sourceLocation: sourceLocation)
    }
}
