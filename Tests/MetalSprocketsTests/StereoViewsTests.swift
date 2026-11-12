import Metal
@testable import MetalSprockets
import simd
import Testing

struct StereoViewsTests {
    private func translation(_ t: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4(t, 1)
        return matrix
    }

    private func makeViews() -> StereoViews {
        let viewport = MTLViewport(originX: 0, originY: 0, width: 10, height: 10, znear: 0, zfar: 1)
        return StereoViews(
            viewMatrices: [translation([1, 0, 0]), translation([-1, 0, 0])],
            projectionMatrices: [matrix_identity_float4x4, matrix_identity_float4x4],
            viewports: [viewport, viewport]
        )
    }

    @Test
    func cameraPositionsAndCenter() {
        let views = makeViews()
        #expect(views.count == 2)
        #expect(views.isStereo)
        #expect(views.cameraPositions == [[-1, 0, 0], [1, 0, 0]])
        #expect(views.centerCameraMatrix.columns.3 == SIMD4(0, 0, 0, 1))
        #expect(views.centerViewMatrix == matrix_identity_float4x4)
    }

    @Test
    func relativeViewProjectionsMatchTranslatedPositions() {
        let views = makeViews()
        let origin = SIMD3<Float>(3, 4, 5)
        let point = SIMD4<Float>(7, 8, 9, 1)
        for (relative, absolute) in zip(views.relativeViewProjections(origin: origin), views.viewProjections) {
            #expect(relative * (point - SIMD4(origin, 0)) == absolute * point)
        }
    }
}
