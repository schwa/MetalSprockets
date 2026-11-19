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
        let gpuAddress: MTLGPUAddress
    }

    // Buffer properties read once at creation, so storing a value makes no Objective-C calls.
    private struct Slab {
        let buffer: any MTLBuffer
        let length: Int
        let contents: UnsafeMutableRawPointer
        let gpuAddress: MTLGPUAddress
    }

    static let minimumAlignment = 16

    let resources: ResourceCollection
    private let device: any MTLDevice
    private let initialCapacity: Int
    private var slabs: [Slab] = []
    private var currentIndex = 0
    private var currentOffset = 0

    var bufferCount: Int { slabs.count }

    /// Buffers used since the last reset. The arena keeps their residency across recordings.
    var usedBuffers: [any MTLBuffer] { slabs.isEmpty ? [] : slabs[0...currentIndex].map(\.buffer) }

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
        let (slab, offset) = try reserve(length: bytes.count, alignment: alignment)
        (slab.contents + offset).copyMemory(from: bytes.baseAddress.orFatalError("A non-empty byte buffer has a base address"), byteCount: bytes.count)
        return Allocation(buffer: slab.buffer, offset: offset, length: bytes.count, gpuAddress: slab.gpuAddress + UInt64(offset))
    }

    private func reserve(length: Int, alignment: Int) throws -> (Slab, Int) {
        while currentIndex < slabs.count {
            let offset = (currentOffset + alignment - 1) & ~(alignment - 1)
            if offset + length <= slabs[currentIndex].length {
                currentOffset = offset + length
                return (slabs[currentIndex], offset)
            }
            guard currentIndex + 1 < slabs.count else {
                break
            }
            currentIndex += 1
            currentOffset = 0
        }
        let previous = slabs.last?.length ?? initialCapacity / 2
        let capacity = max(previous * 2, length + alignment, initialCapacity)
        let buffer = try device.makeBuffer(length: capacity, options: .storageModeShared).orThrow(.resourceCreationFailure("Could not allocate Metal 4 scratch storage"))
        buffer.label = "MetalSprockets scratch"
        try resources.register(buffer)
        if !slabs.isEmpty {
            currentIndex += 1
        }
        let slab = Slab(buffer: buffer, length: buffer.length, contents: buffer.contents(), gpuAddress: buffer.gpuAddress)
        slabs.append(slab)
        currentOffset = length
        return (slab, 0)
    }
}
