import Metal
import MetalSprocketsSupport
import MetalSupport

// MARK: - ComputeDispatch

/// Dispatches compute shader work to the GPU.
///
/// Use `ComputeDispatch` inside a ``ComputePipeline`` to execute compute
/// work with the specified thread configuration.
///
/// ## Overview
///
/// Dispatch compute work with explicit threadgroup counts:
///
/// ```swift
/// ComputePass {
///     ComputePipeline(computeKernel: kernel) {
///         ComputeDispatch(
///             threadgroups: MTLSize(width: 32, height: 32, depth: 1),
///             threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
///         )
///     }
/// }
/// ```
///
/// ## Dispatch Modes
///
/// Two dispatch modes are available:
///
/// ### Threadgroups per Grid
/// Specify the number of threadgroups. Total threads = threadgroups × threadsPerThreadgroup.
///
/// ```swift
/// ComputeDispatch(
///     threadgroups: MTLSize(width: 32, height: 32, depth: 1),
///     threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
/// )
/// // Total: 256×256 threads
/// ```
///
/// ### Threads per Grid (Non-uniform)
/// Specify exact thread count. Metal handles edge cases automatically.
/// Requires Apple GPU Family 4+ (A11 or later).
///
/// ```swift
/// ComputeDispatch(
///     threadsPerGrid: MTLSize(width: 1920, height: 1080, depth: 1),
///     threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
/// )
/// ```
///
/// ### Indirect Dispatch
/// Read the threadgroup count from a GPU buffer containing an
/// `MTLDispatchThreadgroupsIndirectArguments` value, enabling GPU-driven
/// pipelines to size their own dispatches.
///
/// ```swift
/// ComputeDispatch(
///     indirectBuffer: argumentsBuffer,
///     indirectBufferOffset: 0,
///     threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)
/// )
/// ```
public struct ComputeDispatch: Element, BodylessElement {
    private enum Dimensions {
        case threadgroupsPerGrid(MTLSize)
        case threadsPerGrid(MTLSize)
        case indirect(buffer: MTLBuffer, offset: Int)

        /// The grid this dispatch covers, when known. Indirect dispatches size themselves on the GPU.
        var gridSize: MTLSize? {
            switch self {
            case .threadsPerGrid(let size):
                return size
            case .threadgroupsPerGrid, .indirect:
                return nil
            }
        }
    }

    private var dimensions: Dimensions
    /// `nil` means "pick a threadgroup size from the pipeline state at dispatch time".
    private var threadsPerThreadgroup: MTLSize?

    /// Creates a dispatch with explicit threadgroup counts.
    ///
    /// - Parameters:
    ///   - threadgroups: The number of threadgroups in each dimension.
    ///   - threadsPerThreadgroup: The number of threads per threadgroup. Pass `nil` (the default)
    ///     to derive it from the compute pipeline state at dispatch time.
    public init(threadgroups: MTLSize, threadsPerThreadgroup: MTLSize? = nil) throws {
        self.dimensions = .threadgroupsPerGrid(threadgroups)
        self.threadsPerThreadgroup = threadsPerThreadgroup
    }

    /// Creates a dispatch with exact thread counts (non-uniform threadgroups).
    ///
    /// This mode handles edge cases automatically but requires Apple GPU Family 4+.
    ///
    /// - Parameters:
    ///   - threadsPerGrid: The total number of threads in each dimension.
    ///   - threadsPerThreadgroup: The number of threads per threadgroup. Pass `nil` (the default)
    ///     to derive it from the compute pipeline state at dispatch time.
    public init(threadsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize? = nil) throws {
        let device = _MTLCreateSystemDefaultDevice()
        guard device.supportsFamily(.apple4) else {
            try _throw(MetalSprocketsError.deviceCababilityFailure("Non-uniform threadgroup sizes require Apple GPU Family 4+ (A11 or later)"))
        }
        self.dimensions = .threadsPerGrid(threadsPerGrid)
        self.threadsPerThreadgroup = threadsPerThreadgroup
    }

    /// Creates a dispatch whose threadgroup count is read from a GPU buffer.
    ///
    /// The buffer must contain an `MTLDispatchThreadgroupsIndirectArguments`
    /// value at `indirectBufferOffset`, which must be a multiple of 4.
    ///
    /// - Parameters:
    ///   - indirectBuffer: The buffer containing the dispatch arguments.
    ///   - indirectBufferOffset: The byte offset of the arguments in the buffer.
    ///   - threadsPerThreadgroup: The number of threads per threadgroup. Pass `nil` (the default)
    ///     to derive it from the compute pipeline state at dispatch time.
    public init(indirectBuffer: MTLBuffer, indirectBufferOffset: Int = 0, threadsPerThreadgroup: MTLSize? = nil) throws {
        guard indirectBufferOffset >= 0, indirectBufferOffset.isMultiple(of: 4) else {
            try _throw(MetalSprocketsError.configurationError("indirectBufferOffset must be a non-negative multiple of 4."))
        }
        self.dimensions = .indirect(buffer: indirectBuffer, offset: indirectBufferOffset)
        self.threadsPerThreadgroup = threadsPerThreadgroup
    }

    func workloadEnter(_ node: Node) throws {
        guard let computeCommandEncoder = node.environmentValues.computeCommandEncoder, let computePipelineState = node.environmentValues.computePipelineState else {
            preconditionFailure("No compute command encoder/compute pipeline state found.")
        }
        computeCommandEncoder.setComputePipelineState(computePipelineState)

        let threadsPerThreadgroup = self.threadsPerThreadgroup ?? Self.automaticThreadsPerThreadgroup(for: computePipelineState, gridSize: dimensions.gridSize)

        switch dimensions {
        case .threadgroupsPerGrid(let threadgroupCount):
            computeCommandEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)
        case .threadsPerGrid(let threads):
            computeCommandEncoder.dispatchThreads(threads, threadsPerThreadgroup: threadsPerThreadgroup)
        case let .indirect(buffer, offset):
            computeCommandEncoder.dispatchThreadgroups(indirectBuffer: buffer, indirectBufferOffset: offset, threadsPerThreadgroup: threadsPerThreadgroup)
        }
    }

    /// Derives a threadgroup size from the pipeline state, following Apple's recommended
    /// `threadExecutionWidth` × (`maxTotalThreadsPerThreadgroup` / `threadExecutionWidth`) split.
    /// The pipeline state is only available at dispatch time, and its limits can vary with
    /// linked functions, so this can't be computed when the element is constructed (#328).
    internal static func automaticThreadsPerThreadgroup(for pipelineState: MTLComputePipelineState, gridSize: MTLSize?) -> MTLSize {
        let maxTotal = max(1, pipelineState.maxTotalThreadsPerThreadgroup)
        let executionWidth = max(1, min(pipelineState.threadExecutionWidth, maxTotal))
        // A 1D grid gets a 1D threadgroup; anything else (or an unknown grid) gets a 2D one.
        if let gridSize, gridSize.height <= 1, gridSize.depth <= 1 {
            let width = min(maxTotal, max(executionWidth, gridSize.width))
            return MTLSize(width: max(1, width), height: 1, depth: 1)
        }
        let height = max(1, maxTotal / executionWidth)
        return MTLSize(width: executionWidth, height: height, depth: 1)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        // ComputeDispatch only dispatches during workload, never needs setup
        false
    }
}
