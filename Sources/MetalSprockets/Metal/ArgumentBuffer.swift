import Metal
import MetalSprocketsSupport
import os

/// A long-lived argument buffer: shader struct fields written by name, bound to a draw or dispatch with one address.
///
/// The layout comes from the reflection of the first pipeline that binds it with
/// ``Element/parameter(_:functionTypes:argumentBuffer:)``. `count` elements fill a `constant Struct *` array that
/// shaders index, so draws in one indirect command buffer can each reach their own textures.
///
/// You can set fields from any thread. A change takes effect the next time the buffer is bound; draws already
/// encoded keep the contents they were encoded with.
public final class ArgumentBuffer: @unchecked Sendable {
    public enum Failure: Error, Equatable {
        case notAnArgumentBuffer(String)
        case layoutMismatch(String)
        case unknownField(name: String, available: [String])
        case kindMismatch(name: String)
        case valueTooLarge(name: String, size: Int, span: Int)
        case tooManyElements(name: String, count: Int, capacity: Int)
        case elementOutOfRange(element: Int, count: Int)
        case offsetOutOfRange(name: String, offset: Int, length: Int)
        case bufferCreationFailed
    }

    private enum Value {
        case texture((any MTLTexture)?)
        case textures([any MTLTexture])
        case sampler(any MTLSamplerState)
        case samplers([any MTLSamplerState])
        case buffer(any MTLBuffer, offset: Int)
        case bytes([UInt8])
    }

    private struct FieldKey: Hashable {
        let element: Int
        let name: String
    }

    // One built copy of the contents. Draws retain the version they were encoded with, so later changes write a new one.
    final class Version {
        let buffer: any MTLBuffer
        let allocations: [any MTLAllocation]
        let objects: [AnyObject]

        init(buffer: any MTLBuffer, allocations: [any MTLAllocation], objects: [AnyObject]) {
            self.buffer = buffer
            self.allocations = allocations
            self.objects = objects
        }
    }

    private struct State {
        var layout: ArgumentBufferLayout?
        var values: [FieldKey: Value] = [:]
        var version: Version?
    }

    public let device: any MTLDevice
    public let count: Int
    public let label: String?
    private let state = OSAllocatedUnfairLock(uncheckedState: State())

    public init(device: any MTLDevice, count: Int = 1, label: String? = nil) {
        precondition(count > 0, "An argument buffer needs at least one element")
        self.device = device
        self.count = count
        self.label = label
    }

    /// A nil texture writes an empty resource ID.
    public func set(_ name: String, texture: (any MTLTexture)?, element: Int = 0) {
        store(name, element: element, value: .texture(texture))
    }

    /// Fills an `array<texture2d<...>, N>` field from its first slot.
    public func set(_ name: String, textures: [any MTLTexture], element: Int = 0) {
        store(name, element: element, value: .textures(textures))
    }

    /// Create the sampler with `supportArgumentBuffers = true`.
    public func set(_ name: String, samplerState: any MTLSamplerState, element: Int = 0) {
        store(name, element: element, value: .sampler(samplerState))
    }

    public func set(_ name: String, samplerStates: [any MTLSamplerState], element: Int = 0) {
        store(name, element: element, value: .samplers(samplerStates))
    }

    /// Writes the buffer's GPU address into a pointer field and keeps the buffer resident while this buffer is bound.
    public func set(_ name: String, buffer: any MTLBuffer, offset: Int = 0, element: Int = 0) {
        store(name, element: element, value: .buffer(buffer, offset: offset))
    }

    /// The value must be a plain-old-data type Metal can memcpy.
    public func set<Value>(_ name: String, value: Value, element: Int = 0) {
        assert(_isPOD(Value.self), "Argument buffer values must be a POD type.")
        let bytes = withUnsafeBytes(of: value) { Array($0) }
        store(name, element: element, value: .bytes(bytes))
    }

    private func store(_ name: String, element: Int, value: Value) {
        state.withLockUnchecked { state in
            state.values[FieldKey(element: element, name: name)] = value
            state.version = nil
        }
    }

    // The contents for a binding with `layout`, built if any field changed since the last call.
    func version(for layout: ArgumentBufferLayout?, bindingName: String) throws -> Version {
        try state.withLockUnchecked { state in
            guard let layout else {
                throw Failure.notAnArgumentBuffer(bindingName)
            }
            if let existing = state.layout, existing != layout {
                throw Failure.layoutMismatch(bindingName)
            }
            state.layout = layout
            if let version = state.version {
                return version
            }
            let version = try build(layout: layout, values: state.values)
            state.version = version
            return version
        }
    }

    private func build(layout: ArgumentBufferLayout, values: [FieldKey: Value]) throws -> Version {
        let length = layout.stride * count
        guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else {
            throw Failure.bufferCreationFailed
        }
        buffer.label = label
        var allocations: [any MTLAllocation] = [buffer]
        var objects: [AnyObject] = []
        let contents = buffer.contents()
        func writeIDs(_ ids: [UInt64], at offset: Int) {
            for (index, id) in ids.enumerated() {
                contents.storeBytes(of: id, toByteOffset: offset + index * MemoryLayout<UInt64>.stride, as: UInt64.self)
            }
        }
        // Sorted so errors are deterministic.
        for (key, value) in values.sorted(by: { ($0.key.element, $0.key.name) < ($1.key.element, $1.key.name) }) {
            guard key.element >= 0, key.element < count else {
                throw Failure.elementOutOfRange(element: key.element, count: count)
            }
            guard let field = layout.fields[key.name] else {
                throw Failure.unknownField(name: key.name, available: layout.fields.keys.sorted())
            }
            let offset = key.element * layout.stride + field.offset
            switch (value, field.kind) {
            case let (.texture(texture), .texture):
                writeIDs([texture?.gpuResourceID._impl ?? 0], at: offset)
                if let texture {
                    allocations.append(texture)
                }
            case let (.textures(textures), .textures(capacity)):
                guard textures.count <= capacity else {
                    throw Failure.tooManyElements(name: key.name, count: textures.count, capacity: capacity)
                }
                writeIDs(textures.map(\.gpuResourceID._impl), at: offset)
                allocations += textures as [any MTLAllocation]
            case let (.sampler(sampler), .sampler):
                writeIDs([sampler.gpuResourceID._impl], at: offset)
                objects.append(sampler)
            case let (.samplers(samplers), .samplers(capacity)):
                guard samplers.count <= capacity else {
                    throw Failure.tooManyElements(name: key.name, count: samplers.count, capacity: capacity)
                }
                writeIDs(samplers.map(\.gpuResourceID._impl), at: offset)
                objects += samplers as [AnyObject]
            case let (.buffer(target, targetOffset), .pointer):
                guard targetOffset >= 0, targetOffset < target.length else {
                    throw Failure.offsetOutOfRange(name: key.name, offset: targetOffset, length: target.length)
                }
                contents.storeBytes(of: target.gpuAddress + UInt64(targetOffset), toByteOffset: offset, as: UInt64.self)
                allocations.append(target)
            case let (.bytes(bytes), .bytes):
                guard bytes.count <= field.span else {
                    throw Failure.valueTooLarge(name: key.name, size: bytes.count, span: field.span)
                }
                bytes.withUnsafeBytes { source in
                    contents.advanced(by: offset).copyMemory(from: source.baseAddress!, byteCount: bytes.count) // swiftlint:disable:this force_unwrapping
                }
            default:
                throw Failure.kindMismatch(name: key.name)
            }
        }
        return Version(buffer: buffer, allocations: allocations, objects: objects)
    }
}

extension ArgumentBuffer.Failure: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notAnArgumentBuffer(let name):
            "Parameter '\(name)' is not a buffer of a struct, so an argument buffer cannot fill it."
        case .layoutMismatch(let name):
            "Parameter '\(name)' has a different struct layout from the one this argument buffer was first bound to."
        case let .unknownField(name, available):
            "Argument buffer field '\(name)' is not in the shader struct. Fields: \(available.joined(separator: ", "))."
        case .kindMismatch(let name):
            "Argument buffer field '\(name)' has the wrong kind for the shader struct member."
        case let .valueTooLarge(name, size, span):
            "Argument buffer value for '\(name)' is \(size) bytes, but the field holds \(span)."
        case let .tooManyElements(name, count, capacity):
            "Argument buffer field '\(name)' was given \(count) values but holds \(capacity)."
        case let .elementOutOfRange(element, count):
            "Argument buffer element \(element) is outside its \(count) elements."
        case let .offsetOutOfRange(name, offset, length):
            "Argument buffer field '\(name)' offset \(offset) is outside its buffer of \(length) bytes."
        case .bufferCreationFailed:
            "Could not create an argument buffer."
        }
    }
}
