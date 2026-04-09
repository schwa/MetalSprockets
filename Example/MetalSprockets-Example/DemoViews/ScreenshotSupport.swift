import CoreGraphics
import MetalSprockets
import MetalSprocketsSupport
import simd
import SwiftUI

@MainActor
struct Screenshot: Transferable {
    var width: Int = 1_920
    var height: Int = 1_080

    func render() throws -> Image {
        let size = CGSize(width: width, height: height)
        let renderer = try OffscreenRenderer(size: size)

        let time: Float = 0
        let modelMatrix = cubeRotationMatrix(time: TimeInterval(time))
        let viewMatrix = float4x4.translation(0, 0, -8)
        let aspect = size.height > 0 ? Float(size.width / size.height) : 1.0
        let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 100.0)
        let transform = projectionMatrix * viewMatrix * modelMatrix

        let renderPass = try RenderPass {
            try DemoCubeRenderPipeline(transform: transform, time: time)
        }

        let rendering = try renderer.render(renderPass)
        let cgImage = try rendering.cgImage

        #if os(iOS) || os(visionOS)
        return Image(uiImage: UIImage(cgImage: cgImage))
        #else
        return Image(nsImage: NSImage(cgImage: cgImage, size: size))
        #endif
    }

    nonisolated static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { screenshot in
            // swiftlint:disable:next force_try
            MainActor.assumeIsolated { try! screenshot.render() }
        }
    }
}
