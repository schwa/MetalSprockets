import Metal
import MetalSprocketsSupport

internal struct CommandResources {
    let commandBuffer: any MTL4CommandBuffer
    let allocator: any MTL4CommandAllocator
    let scratch: ScratchArena
    let argumentTables: ArgumentTablePool

    init(device: any MTLDevice, scratchCapacity: Int) throws {
        allocator = try device.makeCommandAllocator(descriptor: MTL4CommandAllocatorDescriptor())
        commandBuffer = try device.makeCommandBuffer().orThrow(.resourceCreationFailure("Could not create a Metal 4 command buffer"))
        scratch = try ScratchArena(device: device, initialCapacity: scratchCapacity)
        argumentTables = ArgumentTablePool(device: device)
    }

    func reset() {
        allocator.reset()
        scratch.reset()
        argumentTables.reset()
    }
}
