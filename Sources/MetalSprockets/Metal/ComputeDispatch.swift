import Metal
import MetalSprocketsSupport

// MARK: - ComputeDispatch

/// Dispatches the enclosing ``ComputePipeline`` with the parameters in scope.
///
/// ```swift
/// try ComputePass {
///     try ComputePipeline(computeKernel: kernel) {
///         try ComputeDispatch(threadsPerGrid: MTLSize(width: 1024, height: 1, depth: 1))
///             .parameter("output", buffer: output)
///     }
/// }
/// ```
///
/// When `threadsPerThreadgroup` is `nil`, a size is chosen from the pipeline's execution width and limits.
public struct ComputeDispatch: Element, WorkloadElement {
    public typealias Body = Never
    private let grid: ComputePassEncoder.Grid
    private let threadsPerThreadgroup: MTLSize?

    /// Dispatches a number of threadgroups.
    public init(threadgroups: MTLSize, threadsPerThreadgroup: MTLSize? = nil) throws {
        grid = .threadgroups(threadgroups)
        self.threadsPerThreadgroup = threadsPerThreadgroup
    }

    /// Dispatches an exact number of threads (non-uniform threadgroups; Apple GPU Family 4 or later).
    public init(threadsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize? = nil) throws {
        // The Apple-family check happens at dispatch time against the device actually in use. See #55.
        grid = .threads(threadsPerGrid)
        self.threadsPerThreadgroup = threadsPerThreadgroup
    }

    /// Dispatches threadgroup counts read by the GPU from `indirectBuffer` (`MTLDispatchThreadgroupsIndirectArguments`).
    public init(indirectBuffer: MTLBuffer, indirectBufferOffset: Int = 0, threadsPerThreadgroup: MTLSize? = nil) throws {
        guard indirectBufferOffset >= 0, indirectBufferOffset.isMultiple(of: 4) else {
            try _throw(MetalSprocketsError.configurationError("indirectBufferOffset must be a non-negative multiple of 4."))
        }
        grid = .indirect(indirectBuffer, offset: indirectBufferOffset)
        self.threadsPerThreadgroup = threadsPerThreadgroup
    }

    func workloadEnter(_ node: Node) throws {
        let pass = try node.environmentValues.computePassEncoder.orThrow(.withHint(.missingEnvironment(\.computeCommandEncoder), hint: "Place ComputeDispatch inside a ComputePass."))
        let pipeline = try node.environmentValues.computePipeline.orThrow(.withHint(.missingEnvironment(\.computePipelineState), hint: "Place ComputeDispatch inside a ComputePipeline."))
        try pass.dispatch(pipeline, parameters: node.environmentValues.parameterSet ?? ParameterSet(), grid: grid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    internal static func automaticThreadsPerThreadgroup(for pipelineState: MTLComputePipelineState, gridSize: MTLSize?) -> MTLSize {
        let maxTotal = max(1, pipelineState.maxTotalThreadsPerThreadgroup)
        let executionWidth = max(1, min(pipelineState.threadExecutionWidth, maxTotal))
        guard let gridSize else {
            // Unknown grid (threadgroup or indirect dispatch): one SIMD group, which suits kernels of any
            // dimensionality. A 2D default is rejected by API Validation for kernels with a 1D thread position.
            return MTLSize(width: executionWidth, height: 1, depth: 1)
        }
        // A 1D grid gets a 1D threadgroup; a 2D or 3D grid gets a 2D one.
        if gridSize.height <= 1, gridSize.depth <= 1 {
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

// MARK: - ComputeCommand

/// Raw access to the Metal 4 compute encoder inside a ``ComputePass``, without a pipeline.
///
/// Use it for copies, fills and other pipeline-free commands (the replacement for `BlitPass`). The encoder performs no
/// hazard tracking: declare every referenced resource with ``Element/useComputeResources(_:usage:)``, and order
/// dependent commands with ``EncoderBarrier``.
///
/// ```swift
/// try ComputePass {
///     ComputeCommand { encoder in
///         encoder.copy(sourceBuffer: source, sourceOffset: 0, destinationBuffer: destination, destinationOffset: 0, size: 256)
///     }
///     .useComputeResources([source, destination], usage: [.read, .write])
/// }
/// ```
public struct ComputeCommand: Element, WorkloadElement {
    public typealias Body = Never
    let encode: (any MTL4ComputeCommandEncoder) throws -> Void

    public init(_ encode: @escaping (any MTL4ComputeCommandEncoder) throws -> Void) {
        self.encode = encode
    }

    func workloadEnter(_ node: Node) throws {
        let pass = try node.environmentValues.computePassEncoder.orThrow(.withHint(.missingEnvironment(\.computeCommandEncoder), hint: "Place ComputeCommand inside a ComputePass."))
        try pass.command(encode)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool { false }
}
