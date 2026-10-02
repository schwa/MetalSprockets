import Metal

/// Reference-counts allocations across recorded and in-flight submissions.
///
/// An allocation joins the residency set on its first use and leaves after its last use retires, so the set tracks
/// only live work instead of growing with every resource ever seen. Confined to the owning context's isolation.
internal final class ResidencyTracker {
    private struct Entry {
        let allocation: any MTLAllocation
        var uses: Int
    }

    let residencySet: any MTLResidencySet
    private var entries: [ObjectIdentifier: Entry] = [:]

    var trackedCount: Int { entries.count }

    init(device: any MTLDevice) throws {
        let descriptor = MTLResidencySetDescriptor()
        descriptor.label = "MetalSprockets context residency"
        residencySet = try device.makeResidencySet(descriptor: descriptor)
    }

    /// Adds one use for each distinct allocation. Returns the distinct allocations so the caller can release exactly them.
    func acquire(_ allocations: [any MTLAllocation]) -> [any MTLAllocation] {
        var distinct: [ObjectIdentifier: any MTLAllocation] = [:]
        for allocation in allocations {
            distinct[ObjectIdentifier(allocation)] = allocation
        }
        var added = false
        for (identifier, allocation) in distinct {
            if entries[identifier] == nil {
                entries[identifier] = Entry(allocation: allocation, uses: 0)
                residencySet.addAllocation(allocation)
                added = true
            }
            entries[identifier]?.uses += 1
        }
        if added {
            residencySet.commit()
        }
        return Array(distinct.values)
    }

    func release(_ allocations: [any MTLAllocation]) {
        var removed = false
        for allocation in allocations {
            let identifier = ObjectIdentifier(allocation)
            guard var entry = entries[identifier] else {
                preconditionFailure("Released an allocation that was never acquired")
            }
            entry.uses -= 1
            if entry.uses <= 0 {
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
