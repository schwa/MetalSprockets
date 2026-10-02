import Metal
import os

public final class ResourceCollection {
    public enum Failure: Error {
        case foreignDevice
        case unsupportedAllocation
        case memorylessResource
    }

    private struct Entry {
        let allocation: any MTLAllocation
        var registered = true
        var uses = 0
    }

    internal final class Lease {
        let collection: ResourceCollection
        let identifiers: Set<ObjectIdentifier>

        init(collection: ResourceCollection, identifiers: Set<ObjectIdentifier>) {
            self.collection = collection
            self.identifiers = identifiers
        }

        deinit {
            collection.release(identifiers)
        }
    }

    public let device: any MTLDevice
    internal let residencySet: any MTLResidencySet
    private let entries = OSAllocatedUnfairLock(uncheckedState: [ObjectIdentifier: Entry]())

    public init(device: any MTLDevice) throws {
        self.device = device
        let descriptor = MTLResidencySetDescriptor()
        descriptor.label = "MetalSprockets resource collection"
        residencySet = try device.makeResidencySet(descriptor: descriptor)
    }

    deinit {
        // Command buffers may retain the set after its last collection lease has ended.
        residencySet.removeAllAllocations()
        residencySet.commit()
    }

    public func register(_ allocation: any MTLAllocation) throws {
        let allocationDevice: any MTLDevice
        switch allocation {
        case let resource as any MTLResource: allocationDevice = resource.device
        case let heap as any MTLHeap: allocationDevice = heap.device
        case let pipeline as any MTLRenderPipelineState: allocationDevice = pipeline.device
        case let pipeline as any MTLComputePipelineState: allocationDevice = pipeline.device
        #if !targetEnvironment(simulator)
        case let pipeline as any MTL4MachineLearningPipelineState: allocationDevice = pipeline.device
        #endif
        default: throw Failure.unsupportedAllocation
        }
        guard allocationDevice === device else {
            throw Failure.foreignDevice
        }
        if let resource = allocation as? any MTLResource, resource.storageMode == .memoryless {
            throw Failure.memorylessResource
        }
        entries.withLockUnchecked { entries in
            let identifier = ObjectIdentifier(allocation)
            if entries[identifier] != nil {
                entries[identifier]?.registered = true
            } else {
                entries[identifier] = Entry(allocation: allocation)
                residencySet.addAllocation(allocation)
                residencySet.commit()
            }
        }
    }

    public func unregister(_ allocation: any MTLAllocation) {
        entries.withLockUnchecked { entries in
            let identifier = ObjectIdentifier(allocation)
            guard var entry = entries[identifier] else {
                return
            }
            entry.registered = false
            if entry.uses == 0 {
                entries.removeValue(forKey: identifier)
                residencySet.removeAllocation(entry.allocation)
                residencySet.commit()
            } else {
                entries[identifier] = entry
            }
        }
    }

    public func contains(_ allocation: any MTLAllocation) -> Bool {
        entries.withLockUnchecked { $0[ObjectIdentifier(allocation)]?.registered == true }
    }

    internal func acquire() -> Lease {
        entries.withLockUnchecked { entries in
            let identifiers = Set(entries.compactMap { identifier, entry in entry.registered ? identifier : nil })
            for identifier in identifiers {
                entries[identifier]?.uses += 1
            }
            return Lease(collection: self, identifiers: identifiers)
        }
    }

    private func release(_ identifiers: Set<ObjectIdentifier>) {
        entries.withLockUnchecked { entries in
            var removed = false
            for identifier in identifiers {
                guard var entry = entries[identifier] else {
                    preconditionFailure("Resource collection lease lost its allocation")
                }
                entry.uses -= 1
                if !entry.registered, entry.uses == 0 {
                    entries.removeValue(forKey: identifier)
                    residencySet.removeAllocation(entry.allocation)
                    removed = true
                } else {
                    entries[identifier] = entry
                }
            }
            if removed {
                residencySet.commit()
            }
        }
    }
}
