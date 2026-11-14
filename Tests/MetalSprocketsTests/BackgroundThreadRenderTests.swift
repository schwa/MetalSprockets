import Foundation
import Metal
@testable import MetalSprockets
import Testing

// Run under ThreadSanitizer to check completion callbacks (#559).
@Test(.requiresMetal4, .timeLimit(.minutes(1)))
func offscreenRenderOnBackgroundThread() async throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let error: (any Error)? = await withCheckedContinuation { continuation in
        let thread = Thread {
            do {
                let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 64), device: device)
                for _ in 0..<20 {
                    _ = try renderer.render(RenderPass { EmptyElement() })
                }
                continuation.resume(returning: nil)
            } catch {
                continuation.resume(returning: error)
            }
        }
        thread.start()
    }
    if let error {
        throw error
    }
}
