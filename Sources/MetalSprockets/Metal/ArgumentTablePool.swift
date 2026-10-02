import Metal

internal final class ArgumentTablePool {
    private final class Bucket {
        var tables: [any MTL4ArgumentTable] = []
        var usedCount = 0
    }

    private struct Key: Hashable {
        let sizes: PipelineBindings.TableSizes
        let label: String?
    }

    private let device: any MTLDevice
    private var buckets: [Key: Bucket] = [:]

    init(device: any MTLDevice) {
        self.device = device
    }

    func acquire(sizes: PipelineBindings.TableSizes, label: String?) throws -> any MTL4ArgumentTable {
        let key = Key(sizes: sizes, label: label)
        let bucket: Bucket
        if let existing = buckets[key] {
            bucket = existing
        } else {
            bucket = Bucket()
            buckets[key] = bucket
        }
        let table: any MTL4ArgumentTable
        if bucket.usedCount < bucket.tables.count {
            table = bucket.tables[bucket.usedCount]
            // Omitted parameters and short texture arrays must not inherit the previous recording's bindings.
            for index in 0..<sizes.buffers {
                table.setAddress(0, index: index)
            }
            for index in 0..<sizes.textures {
                table.setTexture(MTLResourceID(), index: index)
            }
            for index in 0..<sizes.samplers {
                table.setSamplerState(MTLResourceID(), index: index)
            }
        } else {
            let descriptor = MTL4ArgumentTableDescriptor()
            descriptor.maxBufferBindCount = sizes.buffers
            descriptor.maxTextureBindCount = sizes.textures
            descriptor.maxSamplerStateBindCount = sizes.samplers
            descriptor.initializeBindings = true
            descriptor.label = label
            table = try device.makeArgumentTable(descriptor: descriptor)
            bucket.tables.append(table)
        }
        bucket.usedCount += 1
        return table
    }

    // Reset only after encoding fails or both GPU completion and successful feedback arrive.
    func reset() {
        for bucket in buckets.values {
            bucket.usedCount = 0
        }
    }
}
