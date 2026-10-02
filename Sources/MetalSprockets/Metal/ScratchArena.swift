import Metal
import MetalSprocketsSupport

/// Bump-allocated shared storage for per-recording shader values, bound by GPU address.
///
/// Each command allocator has an arena, reset only after GPU retirement. Growth appends buffers instead of
/// reallocating, so GPU addresses already handed out stay valid for the rest of the recording. Reuse keeps the buffers,
/// so storage is bounded by peak per-recording use.
internal final class ScratchArena {
    enum Failure: Error, Equatable {
        case emptyAllocation
        case invalidAlignment(Int)
    }

    struct Allocation {
        let buffer: any MTLBuffer
        let offset: Int
        let length: Int

        var gpuAddress: MTLGPUAddress { buffer.gpuAddress + UInt64(offset) }
    }

    static let minimumAlignment = 16

    let resources: ResourceCollection
    private let device: any MTLDevice
    private let initialCapacity: Int
    private var buffers: [any MTLBuffer] = []
    private var currentIndex = 0
    private var currentOffset = 0

    var bufferCount: Int { buffers.count }

    /// Buffers used since the last reset. The arena keeps their residency across recordings.
    var usedBuffers: [any MTLBuffer] { buffers.isEmpty ? [] : Array(buffers[0...currentIndex]) }

    init(device: any MTLDevice, initialCapacity: Int) throws {
        self.device = device
        self.resources = try ResourceCollection(device: device)
        self.initialCapacity = max(initialCapacity, Self.minimumAlignment)
    }

    func reset() {
        currentIndex = 0
        currentOffset = 0
    }

    // Callers are responsible for passing POD values; the public parameter APIs assert POD-ness at runtime.
    func allocate<T>(_ value: T, alignment: Int? = nil) throws -> Allocation {
        try withUnsafeBytes(of: value) { try store($0, alignment: alignment ?? MemoryLayout<T>.alignment) }
    }

    func allocate<T>(_ values: [T], alignment: Int? = nil) throws -> Allocation {
        try values.withUnsafeBytes { try store($0, alignment: alignment ?? MemoryLayout<T>.alignment) }
    }

    private func store(_ bytes: UnsafeRawBufferPointer, alignment requested: Int) throws -> Allocation {
        guard requested > 0, requested & (requested - 1) == 0 else {
            throw Failure.invalidAlignment(requested)
        }
        guard !bytes.isEmpty else {
            throw Failure.emptyAllocation
        }
        let alignment = max(requested, Self.minimumAlignment)
        let (buffer, offset) = try reserve(length: bytes.count, alignment: alignment)
        (buffer.contents() + offset).copyMemory(from: bytes.baseAddress.orFatalError("A non-empty byte buffer has a base address"), byteCount: bytes.count)
        return Allocation(buffer: buffer, offset: offset, length: bytes.count)
    }

    private func reserve(length: Int, alignment: Int) throws -> (any MTLBuffer, Int) {
        while currentIndex < buffers.count {
            let offset = (currentOffset + alignment - 1) & ~(alignment - 1)
            if offset + length <= buffers[currentIndex].length {
                currentOffset = offset + length
                return (buffers[currentIndex], offset)
            }
            guard currentIndex + 1 < buffers.count else {
                break
            }
            currentIndex += 1
            currentOffset = 0
        }
        let previous = buffers.last?.length ?? initialCapacity / 2
        let capacity = max(previous * 2, length + alignment, initialCapacity)
        let buffer = try device.makeBuffer(length: capacity, options: .storageModeShared).orThrow(.resourceCreationFailure("Could not allocate Metal 4 scratch storage"))
        buffer.label = "MetalSprockets scratch"
        try resources.register(buffer)
        if !buffers.isEmpty {
            currentIndex += 1
        }
        buffers.append(buffer)
        currentOffset = length
        return (buffer, 0)
    }
}
