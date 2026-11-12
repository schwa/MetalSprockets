import Metal
import simd

/// The views that one frame draws at once, such as the two eyes of a visionOS immersive space.
///
/// Each view has a view matrix, a reversed-depth projection and a viewport. Renderers that support it draw every mesh
/// once with vertex amplification: the shader picks its view with `[[amplification_id]]`, and each view goes to its own
/// viewport and render target array slice.
public struct StereoViews: Sendable {
    /// The largest number of views.
    public static let maximumCount = 2

    /// One world-to-view matrix per view.
    public var viewMatrices: [simd_float4x4]
    /// One projection per view.
    public var projectionMatrices: [simd_float4x4]
    /// One viewport per view.
    public var viewports: [MTLViewport]

    /// Creates the views of a frame.
    ///
    /// - Parameters:
    ///   - viewMatrices: One world-to-view matrix per view.
    ///   - projectionMatrices: One projection per view.
    ///   - viewports: One viewport per view.
    public init(viewMatrices: [simd_float4x4], projectionMatrices: [simd_float4x4], viewports: [MTLViewport]) {
        precondition((1 ... Self.maximumCount).contains(viewMatrices.count), "One or two views")
        precondition(projectionMatrices.count == viewMatrices.count && viewports.count == viewMatrices.count, "One projection and viewport per view")
        self.viewMatrices = viewMatrices
        self.projectionMatrices = projectionMatrices
        self.viewports = viewports
    }

    /// The number of views.
    public var count: Int { viewMatrices.count }

    /// Whether there is more than one view.
    public var isStereo: Bool { count > 1 }

    /// Each view's projection times its view matrix.
    public var viewProjections: [simd_float4x4] {
        zip(projectionMatrices, viewMatrices).map { $0 * $1 }
    }

    /// Each view's world transform.
    public var cameraMatrices: [simd_float4x4] {
        viewMatrices.map(\.inverse)
    }

    /// Each view's position in world space.
    public var cameraPositions: [SIMD3<Float>] {
        cameraMatrices.map { SIMD3($0.columns.3.x, $0.columns.3.y, $0.columns.3.z) }
    }

    /// A single camera between the views: the first view's orientation at the mean of the view positions. For work that
    /// needs one camera, such as sorting and level of detail.
    public var centerCameraMatrix: simd_float4x4 {
        var matrix = cameraMatrices[0]
        let center = cameraPositions.reduce(SIMD3<Float>.zero, +) / Float(count)
        matrix.columns.3 = SIMD4(center, 1)
        return matrix
    }

    /// The world-to-view matrix of ``centerCameraMatrix``.
    public var centerViewMatrix: simd_float4x4 {
        isStereo ? centerCameraMatrix.inverse : viewMatrices[0]
    }

    /// Each view's projection times its view matrix, relative to `origin`. For renderers that draw relative to the
    /// camera to keep precision far from the world origin: positions are passed minus `origin`.
    public func relativeViewProjections(origin: SIMD3<Float>) -> [simd_float4x4] {
        zip(projectionMatrices, viewMatrices).map { projection, view in
            var translated = view
            // view * translate(origin): moves the view so that `origin` is its new world origin.
            translated.columns.3 = view * SIMD4(origin, 1)
            return projection * translated
        }
    }

    /// Makes the following draws on `encoder` go to every view. Each draw resets amplification, so call this before
    /// every draw. Pipelines must set `maxVertexAmplificationCount` to at least ``count``. Does nothing for one view.
    public func configure(_ encoder: any MTL4RenderCommandEncoder) {
        guard isStereo else {
            return
        }
        let mappings = (0 ..< count).map { MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: UInt32($0), renderTargetArrayIndexOffset: UInt32($0)) }
        encoder.setVertexAmplificationCount(mappings)
        encoder.setViewports(viewports)
    }
}

public extension Element {
    /// Lets the render pipelines inside draw to `count` views at once with vertex amplification.
    func vertexAmplification(count: Int) -> some Element {
        renderPipelineDescriptorTransformer { descriptor in
            descriptor.maxVertexAmplificationCount = count
        }
    }
}
