import Metal
import MetalSprocketsSupport

// MARK: - ComputePass

/// A container element that creates a Metal compute command encoder.
///
/// `ComputePass` establishes the context for compute shader execution. It creates
/// an `MTLComputeCommandEncoder` that compute pipelines use to dispatch GPU work.
///
/// ## Overview
///
/// A compute pass typically contains one or more ``ComputePipeline`` elements:
///
/// ```swift
/// ComputePass {
///     ComputePipeline(computeKernel: library.myKernel) {
///         Dispatch { encoder, pipelineState in
///             let threadsPerGroup = MTLSize(width: 8, height: 8, depth: 1)
///             let threadgroups = MTLSize(width: 32, height: 32, depth: 1)
///             encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
///         }
///     }
/// }
/// ```
///
/// ## Mixing Render and Compute
///
/// Combine compute and render passes in the same frame:
///
/// ```swift
/// CommandBufferElement {
///     ComputePass {
///         // Process data on GPU
///     }
///     RenderPass {
///         // Render using computed data
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Related Elements
/// - ``ComputePipeline``
/// - ``RenderPass``
public struct ComputePass <Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    internal let label: String?
    internal let content: Content

    /// Creates a compute pass with the specified content.
    ///
    /// - Parameters:
    ///   - label: An optional label for debugging (visible in GPU frame capture).
    ///   - content: A closure that returns the child elements to execute.
    public init(label: String? = nil, @ElementBuilder content: () throws -> Content) throws {
        self.label = label
        self.content = try content()
    }

    func workloadEnter(_ node: Node) throws {
        logger?.verbose?.info("Start compute pass: \(label ?? "<unlabeled>") (\(node.element.internalDescription))")
        let commandBuffer = try node.environmentValues.commandBuffer.orThrow(.missingEnvironment(\.commandBuffer))
        let computeCommandEncoder = try commandBuffer._makeComputeCommandEncoder()
        if let label {
            computeCommandEncoder.label = label
        }
        node.environmentValues.computeCommandEncoder = computeCommandEncoder
    }

    func workloadExit(_ node: Node) throws {
        let computeCommandEncoder = try node.environmentValues.computeCommandEncoder.orThrow(.missingEnvironment(\.computeCommandEncoder))
        computeCommandEncoder.endEncoding()
        logger?.verbose?.info("Ending compute pass: \(label ?? "<unlabeled>") (\(node.element.internalDescription))")
    }
}

// MARK: - ComputePipeline

/// Configures a Metal compute pipeline state with a compute kernel.
///
/// `ComputePipeline` creates the pipeline state object that the GPU uses to
/// execute compute shaders. Place it inside a ``ComputePass``.
///
/// ## Overview
///
/// Create a compute pipeline by specifying a compute kernel:
///
/// ```swift
/// let library = try ShaderLibrary(bundle: .main)
///
/// ComputePipeline(computeKernel: library.myComputeKernel) {
///     Dispatch { encoder, pipelineState in
///         // Configure and dispatch threads
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Related Elements
/// - ``ComputePass``
/// - ``ComputeKernel``
public struct ComputePipeline <Content>: Element, BodylessElement, BodylessContentElement where Content: Element {
    private let label: String?
    private let computeKernel: ComputeKernel
    internal let content: Content

    /// Creates a compute pipeline with the specified kernel and content.
    ///
    /// - Parameters:
    ///   - label: An optional label for debugging (visible in GPU frame capture).
    ///   - computeKernel: The compute kernel function to execute.
    ///   - content: A closure that returns child elements (typically dispatch elements).
    public init(label: String? = nil, computeKernel: ComputeKernel, @ElementBuilder content: () throws -> Content) throws {
        self.label = label
        self.computeKernel = computeKernel
        self.content = try content()
    }

    func setupEnter(_ node: Node) throws {
        let device = try node.environmentValues.device.orThrow(.missingEnvironment(\.device))
        let descriptor = MTLComputePipelineDescriptor()
        if let label {
            descriptor.label = label
        }
        descriptor.computeFunction = computeKernel.function
        if let linkedFunctions = node.environmentValues.linkedFunctions {
            descriptor.linkedFunctions = linkedFunctions
        }
        let (computePipelineState, reflection) = try device.makeComputePipelineState(descriptor: descriptor, options: .bindingInfo)
        node.environmentValues.reflection = Reflection(try reflection.orThrow(.resourceCreationFailure("Failed to create reflection.")))
        node.environmentValues.computePipelineState = computePipelineState
    }

    nonisolated func requiresSetup(comparedTo old: ComputePipeline<Content>) -> Bool {
        // For now, always return false since kernels rarely change after initial setup
        // This prevents pipeline recreation on every frame
        // TODO: Implement proper comparison when shader constants are added
        false
    }
}
