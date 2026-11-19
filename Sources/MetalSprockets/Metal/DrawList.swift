import Metal
import MetalSprocketsSupport

// MARK: - DrawRow

/// One draw in a ``DrawList``: a value with no closures or bindings.
///
/// A row selects its per-draw data through its instance range. The first instance is the draw's base instance, so a
/// shader reads `table[instance_id]` from tables bound once on the list.
public struct DrawRow: Hashable, Sendable {
    public enum Geometry: Hashable, Sendable {
        /// Non-indexed vertices.
        case vertices(Range<Int>)
        /// A range of indices into the list's index buffer, added to `baseVertex`.
        case indexed(Range<Int>, baseVertex: Int = 0)
    }

    public var primitiveType: MTLPrimitiveType
    public var geometry: Geometry
    public var instances: Range<Int>
    public var cullMode: MTLCullMode
    public var winding: MTLWinding

    public init(primitiveType: MTLPrimitiveType = .triangle, geometry: Geometry, instances: Range<Int> = 0..<1, cullMode: MTLCullMode = .none, winding: MTLWinding = .clockwise) {
        self.primitiveType = primitiveType
        self.geometry = geometry
        self.instances = instances
        self.cullMode = cullMode
        self.winding = winding
    }
}

// MARK: - DrawList

/// Issues many similar draws from one element.
///
/// Every row shares the enclosing pipeline and the bindings set on the list, so the list costs one element however many
/// rows it has. Per-draw data lives in tables bound on the list and indexed by each row's base instance.
///
/// ```swift
/// DrawList(indexBuffer: indices, indexType: .uint32, batches) { batch in
///     DrawRow(geometry: .indexed(batch.indexRange, baseVertex: batch.baseVertex), instances: batch.instances, cullMode: .back)
/// }
/// .vertexBuffer(positions, index: 0)
/// .parameter("instances", values: instanceRecords)
/// ```
///
/// Use ``Draw`` when a draw needs its own textures, buffers or other bindings.
public struct DrawList: Element {
    let rows: [DrawRow]
    let indexBuffer: (any MTLBuffer)?
    let indexType: MTLIndexType
    let stereoViews: StereoViews?

    /// With `stereoViews`, every row draws to each view with vertex amplification.
    public init(indexBuffer: (any MTLBuffer)? = nil, indexType: MTLIndexType = .uint32, stereoViews: StereoViews? = nil, rows: [DrawRow]) {
        self.rows = rows
        self.indexBuffer = indexBuffer
        self.indexType = indexType
        self.stereoViews = stereoViews
    }

    public init<Data: Sequence>(indexBuffer: (any MTLBuffer)? = nil, indexType: MTLIndexType = .uint32, stereoViews: StereoViews? = nil, _ data: Data, row: (Data.Element) throws -> DrawRow) rethrows {
        self.init(indexBuffer: indexBuffer, indexType: indexType, stereoViews: stereoViews, rows: try data.map(row))
    }

    public var body: some Element {
        let rows = rows
        let indexBuffer = indexBuffer
        let indexType = indexType
        let stereoViews = stereoViews
        return Draw(resources: indexBuffer.map { [$0] } ?? []) { encoder in
            stereoViews?.configure(encoder)
            // Draw has reset cull mode and winding to these defaults; set them only when a row changes them.
            var cullMode = MTLCullMode.none
            var winding = MTLWinding.clockwise
            for row in rows {
                if row.cullMode != cullMode {
                    encoder.setCullMode(row.cullMode)
                    cullMode = row.cullMode
                }
                if row.winding != winding {
                    encoder.setFrontFacing(row.winding)
                    winding = row.winding
                }
                guard !row.instances.isEmpty else {
                    continue
                }
                switch row.geometry {
                case .vertices(let range):
                    guard !range.isEmpty else {
                        continue
                    }
                    encoder.drawPrimitives(primitiveType: row.primitiveType, vertexStart: range.lowerBound, vertexCount: range.count, instanceCount: row.instances.count, baseInstance: row.instances.lowerBound)
                case let .indexed(range, baseVertex):
                    guard !range.isEmpty else {
                        continue
                    }
                    let buffer = try indexBuffer.orThrow(.configurationError("DrawList has indexed rows but no indexBuffer."))
                    let indexSize = indexType == .uint16 ? 2 : 4
                    let indices = IndexBuffer(buffer: buffer, type: indexType, indexCount: range.count, offset: range.lowerBound * indexSize)
                    let validated = try indices.validatedRange()
                    encoder.drawIndexedPrimitives(primitiveType: row.primitiveType, indexCount: range.count, indexType: indexType, indexBuffer: validated.address, indexBufferLength: validated.length, instanceCount: row.instances.count, baseVertex: baseVertex, baseInstance: row.instances.lowerBound)
                }
            }
        }
    }
}
