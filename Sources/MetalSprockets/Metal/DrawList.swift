import Metal
import MetalSprocketsSupport
import MetalSupport
import simd

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

    /// An axis-aligned box in the space the list's culling matrices take as input, usually world space.
    public struct Bounds: Hashable, Sendable {
        public var min: SIMD3<Float>
        public var max: SIMD3<Float>

        public init(min: SIMD3<Float>, max: SIMD3<Float>) {
            self.min = min
            self.max = max
        }
    }

    public var primitiveType: MTLPrimitiveType
    public var geometry: Geometry
    public var instances: Range<Int>
    public var cullMode: MTLCullMode
    public var winding: MTLWinding
    /// Covers every instance of the row. A row without bounds is never culled.
    public var bounds: Bounds?

    public init(primitiveType: MTLPrimitiveType = .triangle, geometry: Geometry, instances: Range<Int> = 0..<1, cullMode: MTLCullMode = .none, winding: MTLWinding = .clockwise, bounds: Bounds? = nil) {
        self.primitiveType = primitiveType
        self.geometry = geometry
        self.instances = instances
        self.cullMode = cullMode
        self.winding = winding
        self.bounds = bounds
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
    let cullingViewProjections: [simd_float4x4]
    let cachesCommands: Bool

    @MSEnvironment(\.device)
    var device

    @MSState
    var commandCache = DrawListCommandCache()

    /// With `stereoViews`, every row draws to each view with vertex amplification. With `cullingViewProjections`, a row
    /// whose bounds lie outside every one of those frustums is skipped. Clip z must be in 0...w.
    ///
    /// With `cachesCommands`, the rows are encoded once into an indirect command buffer and executed each frame until
    /// the visible rows change. The enclosing pipeline must support indirect command buffers
    /// (``Element/supportsIndirectCommandBuffers()``). Culling that changes the visible rows re-encodes them.
    public init(indexBuffer: (any MTLBuffer)? = nil, indexType: MTLIndexType = .uint32, stereoViews: StereoViews? = nil, cullingViewProjections: [simd_float4x4] = [], cachesCommands: Bool = false, rows: [DrawRow]) {
        self.rows = rows
        self.indexBuffer = indexBuffer
        self.indexType = indexType
        self.stereoViews = stereoViews
        self.cullingViewProjections = cullingViewProjections
        self.cachesCommands = cachesCommands
    }

    public init<Data: Sequence>(indexBuffer: (any MTLBuffer)? = nil, indexType: MTLIndexType = .uint32, stereoViews: StereoViews? = nil, cullingViewProjections: [simd_float4x4] = [], cachesCommands: Bool = false, _ data: Data, row: (Data.Element) throws -> DrawRow) rethrows {
        self.init(indexBuffer: indexBuffer, indexType: indexType, stereoViews: stereoViews, cullingViewProjections: cullingViewProjections, cachesCommands: cachesCommands, rows: try data.map(row))
    }

    /// The rows not culled, in order.
    var visibleRows: [DrawRow] {
        guard !cullingViewProjections.isEmpty else {
            return rows
        }
        let frustums = cullingViewProjections.map(Self.frustumPlanes)
        return rows.filter { row in
            guard let bounds = row.bounds else {
                return true
            }
            return frustums.contains { Self.intersects(bounds, planes: $0) }
        }
    }

    // Six planes whose normals point into the frustum (Gribb-Hartmann).
    static func frustumPlanes(_ viewProjection: simd_float4x4) -> [SIMD4<Float>] {
        let rows = viewProjection.transpose.columns
        return [rows.3 + rows.0, rows.3 - rows.0, rows.3 + rows.1, rows.3 - rows.1, rows.2, rows.3 - rows.2]
    }

    // Conservative: may keep a box near a frustum corner that is outside.
    static func intersects(_ bounds: DrawRow.Bounds, planes: [SIMD4<Float>]) -> Bool {
        planes.allSatisfy { plane in
            let normal = SIMD3(plane.x, plane.y, plane.z)
            let farthest = SIMD3<Float>.zero.replacing(with: bounds.max, where: normal .>= 0).replacing(with: bounds.min, where: normal .< 0)
            return dot(normal, farthest) + plane.w >= 0
        }
    }

    public var body: some Element {
        get throws {
            try makeBody()
        }
    }

    private func makeBody() throws -> Draw {
        let rows = visibleRows
        let indexBuffer = indexBuffer
        let indexType = indexType
        let stereoViews = stereoViews
        if cachesCommands {
            let commands = try commandCache.commands(device: device ?? _MTLCreateSystemDefaultDevice(), rows: rows, indexBuffer: indexBuffer, indexType: indexType)
            let resources: [any MTLResource] = [commands.buffer].compactMap(\.self) + (indexBuffer.map { [$0] } ?? [])
            return Draw(resources: resources, changesRasterizerState: true) { encoder in
                stereoViews?.configure(encoder)
                guard let buffer = commands.buffer else {
                    return
                }
                for segment in commands.segments {
                    encoder.setCullMode(segment.cullMode)
                    encoder.setFrontFacing(segment.winding)
                    encoder.executeCommands(buffer: buffer, range: segment.range)
                }
            }
        }
        // The rows set cull mode, winding and amplification, so the pass sets them again for the next draw (#472).
        return Draw(resources: indexBuffer.map { [$0] } ?? [], changesRasterizerState: true) { encoder in
            stereoViews?.configure(encoder)
            // Unknown at the start: the enclosing modifiers may have set them. Set on the first row, then on changes.
            var cullMode: MTLCullMode?
            var winding: MTLWinding?
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

// MARK: - DrawListCommandCache

// Rows encoded into an indirect command buffer, kept until the inputs change (#604). A change makes a new buffer, so a
// frame still on the GPU keeps reading the old one.
internal final class DrawListCommandCache: @unchecked Sendable {
    struct Segment: Equatable {
        var cullMode: MTLCullMode
        var winding: MTLWinding
        var range: Range<Int>
    }

    struct Commands {
        var buffer: (any MTLIndirectCommandBuffer)?
        var segments: [Segment]
    }

    private struct Key: Equatable {
        var device: ObjectIdentifier
        var rows: [DrawRow]
        var indexBuffer: ObjectIdentifier?
        var indexType: MTLIndexType
    }

    private let lock = NSLock()
    private var key: Key?
    private var cached: Commands?
    private(set) var encodeCount = 0

    func commands(device: any MTLDevice, rows: [DrawRow], indexBuffer: (any MTLBuffer)?, indexType: MTLIndexType) throws -> Commands {
        let key = Key(device: ObjectIdentifier(device), rows: rows, indexBuffer: indexBuffer.map(ObjectIdentifier.init), indexType: indexType)
        return try lock.withLock {
            if let cached, self.key == key {
                return cached
            }
            let commands = try Self.encode(device: device, rows: rows, indexBuffer: indexBuffer, indexType: indexType)
            self.key = key
            cached = commands
            encodeCount += 1
            return commands
        }
    }

    private static func encode(device: any MTLDevice, rows: [DrawRow], indexBuffer: (any MTLBuffer)?, indexType: MTLIndexType) throws -> Commands {
        let drawn = rows.filter { row in
            switch row.geometry {
            case .vertices(let range):
                !row.instances.isEmpty && !range.isEmpty
            case .indexed(let range, _):
                !row.instances.isEmpty && !range.isEmpty
            }
        }
        guard !drawn.isEmpty else {
            return Commands(buffer: nil, segments: [])
        }
        let buffer = try device.makeRenderIndirectCommandBuffer(maxCommandCount: drawn.count, options: .storageModeShared)
        var segments: [Segment] = []
        for (index, row) in drawn.enumerated() {
            let command = buffer.indirectRenderCommandAt(index)
            switch row.geometry {
            case .vertices(let range):
                command.drawPrimitives(row.primitiveType, vertexStart: range.lowerBound, vertexCount: range.count, instanceCount: row.instances.count, baseInstance: row.instances.lowerBound)
            case let .indexed(range, baseVertex):
                let indexBuffer = try indexBuffer.orThrow(.configurationError("DrawList has indexed rows but no indexBuffer."))
                let indexSize = indexType == .uint16 ? 2 : 4
                _ = try IndexBuffer(buffer: indexBuffer, type: indexType, indexCount: range.count, offset: range.lowerBound * indexSize).validatedRange()
                command.drawIndexedPrimitives(row.primitiveType, indexCount: range.count, indexType: indexType, indexBuffer: indexBuffer, indexBufferOffset: range.lowerBound * indexSize, instanceCount: row.instances.count, baseVertex: baseVertex, baseInstance: row.instances.lowerBound)
            }
            if let last = segments.last, last.cullMode == row.cullMode, last.winding == row.winding {
                segments[segments.count - 1].range = last.range.lowerBound ..< index + 1
            } else {
                segments.append(Segment(cullMode: row.cullMode, winding: row.winding, range: index ..< index + 1))
            }
        }
        return Commands(buffer: buffer, segments: segments)
    }
}
