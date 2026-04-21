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
        logger?.verbose?.info("Enter compute pass: \(label ?? "<unlabeled>") (\(node.element.internalDescription))")
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
        logger?.verbose?.info("Exit compute pass: \(label ?? "<unlabeled>") (\(node.element.internalDescription))")
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
        let linkedFunctions = node.environmentValues.linkedFunctions

        // Per-node cache: rebuild the PSO only when the inputs that actually
        // affect it change. Tracks kernel function identity, linked-functions
        // identity, and label. See #327 / #333.
        let cache = node.cache(ComputePipelineCache.self) { ComputePipelineCache() }
        let key = ComputePipelineCache.Key(
            function: ObjectIdentifier(computeKernel.function),
            linkedFunctions: linkedFunctions.map { ObjectIdentifier($0) },
            label: label
        )

        if cache.key == key, let cachedPSO = cache.pipelineState, let cachedReflection = cache.reflection {
            node.environmentValues.computePipelineState = cachedPSO
            node.environmentValues.reflection = cachedReflection
            return
        }

        // Cache miss: build a new PSO.
        let descriptor = MTLComputePipelineDescriptor()
        if let label {
            descriptor.label = label
        }
        descriptor.computeFunction = computeKernel.function
        if let linkedFunctions {
            descriptor.linkedFunctions = linkedFunctions
        }
        let (computePipelineState, rawReflection) = try device.makeComputePipelineState(descriptor: descriptor, options: .bindingInfo)
        let reflection = Reflection(try rawReflection.orThrow(.resourceCreationFailure("Failed to create reflection.")))

        cache.key = key
        cache.pipelineState = computePipelineState
        cache.reflection = reflection

        node.environmentValues.computePipelineState = computePipelineState
        node.environmentValues.reflection = reflection
    }

    nonisolated func requiresSetup(comparedTo old: ComputePipeline<Content>) -> Bool {
        // Always re-run setup. The per-node cache inside setupEnter decides
        // whether to rebuild the underlying PSO based on its actual inputs,
        // including environment values (linkedFunctions) that we can't see
        // from here. Setup is cheap on a cache hit.
        true
    }
}

private final class ComputePipelineCache: NodeElementCache {
    struct Key: Hashable {
        let function: ObjectIdentifier
        let linkedFunctions: ObjectIdentifier?
        let label: String?
    }

    var key: Key?
    var pipelineState: MTLComputePipelineState?
    var reflection: Reflection?
}
