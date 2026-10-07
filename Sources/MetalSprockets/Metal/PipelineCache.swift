import Metal
import MetalSprocketsSupport

/// Immutable reflected bindings for one compiled pipeline, keyed by argument name and stage.
internal struct PipelineBindings {
    struct Binding: Equatable {
        let index: Int
        let type: MTLBindingType
        var arrayLength = 1
    }

    private struct Key: Hashable {
        let name: String
        let stage: MTLFunctionType
    }

    struct TableSizes: Hashable {
        var buffers = 0
        var textures = 0
        var samplers = 0
    }

    private var entries: [Key: Binding] = [:]
    private var sizes: [MTLFunctionType: TableSizes] = [:]

    init(_ bindings: [(MTLFunctionType, [any MTLBinding])]) {
        for (stage, stageBindings) in bindings {
            for binding in stageBindings {
                // Array arguments (e.g. `array<texture2d<float>, N>`) reflect as one binding spanning N slots.
                let arrayLength = (binding as? any MTLTextureBinding)?.arrayLength ?? 1
                entries[Key(name: binding.name, stage: stage)] = Binding(index: binding.index, type: binding.type, arrayLength: arrayLength)
                var size = sizes[stage, default: TableSizes()]
                switch binding.type {
                case .texture:
                    size.textures = max(size.textures, binding.index + arrayLength)
                case .sampler:
                    size.samplers = max(size.samplers, binding.index + 1)
                case .buffer, .visibleFunctionTable, .intersectionFunctionTable, .instanceAccelerationStructure, .primitiveAccelerationStructure:
                    size.buffers = max(size.buffers, binding.index + 1)
                default:
                    // Not argument-table slots: threadgroup and imageblock memory, and the object-to-mesh payload.
                    break
                }
                sizes[stage] = size
            }
        }
    }

    func binding(named name: String, stage: MTLFunctionType) -> Binding? {
        entries[Key(name: name, stage: stage)]
    }

    /// Argument-table capacities sized by the highest used slot, so sparse indices get correctly sized tables.
    func tableSizes(stage: MTLFunctionType) -> TableSizes {
        sizes[stage, default: TableSizes()]
    }

    func index(of name: String, stage: MTLFunctionType) -> Int? {
        binding(named: name, stage: stage)?.index
    }
}

internal struct MeshRenderPipelineConfiguration {
    var object: ObjectShader?
    var mesh: MeshShader
    var fragment: FragmentShader
    var colorPixelFormats: [MTLPixelFormat]
    var depthPixelFormat: MTLPixelFormat = .invalid
    var stencilPixelFormat: MTLPixelFormat = .invalid
    var rasterSampleCount = 1
    var linkedFunctions: [VisibleFunction] = []
    var label: String?
}

internal struct RenderPipelineConfiguration {
    var vertex: VertexShader
    var fragment: FragmentShader
    var colorPixelFormats: [MTLPixelFormat]
    var depthPixelFormat: MTLPixelFormat = .invalid
    var stencilPixelFormat: MTLPixelFormat = .invalid
    var rasterSampleCount = 1
    var vertexDescriptor: MTLVertexDescriptor?
    /// Linked into both stages.
    var linkedFunctions: [VisibleFunction] = []
    var vertexLinkedFunctions: [VisibleFunction] = []
    var fragmentLinkedFunctions: [VisibleFunction] = []
    /// Caller-configured pipeline state (for example blending from `renderPipelineDescriptorTransformer`). Shaders,
    /// layout and sample count are filled in; color formats only where the base leaves them `.invalid`.
    var baseDescriptor: MTL4RenderPipelineDescriptor?
    var label: String?

    init(vertex: VertexShader, fragment: FragmentShader, colorPixelFormats: [MTLPixelFormat], depthPixelFormat: MTLPixelFormat = .invalid, stencilPixelFormat: MTLPixelFormat = .invalid, rasterSampleCount: Int = 1, vertexDescriptor: MTLVertexDescriptor? = nil, linkedFunctions: [VisibleFunction] = [], vertexLinkedFunctions: [VisibleFunction] = [], fragmentLinkedFunctions: [VisibleFunction] = [], baseDescriptor: MTL4RenderPipelineDescriptor? = nil, label: String? = nil) {
        self.baseDescriptor = baseDescriptor
        self.vertex = vertex
        self.fragment = fragment
        self.colorPixelFormats = colorPixelFormats
        self.depthPixelFormat = depthPixelFormat
        self.stencilPixelFormat = stencilPixelFormat
        self.rasterSampleCount = rasterSampleCount
        self.vertexDescriptor = vertexDescriptor
        self.linkedFunctions = linkedFunctions
        self.vertexLinkedFunctions = vertexLinkedFunctions
        self.fragmentLinkedFunctions = fragmentLinkedFunctions
        self.label = label
    }
}

/// Compiles pipelines through the context's `MTL4Compiler` and caches them by complete identity.
///
/// Identity uses shader provenance (exact library, name, constants, export name), linked functions, attachment formats,
/// sample count, vertex layout, and label, so steady-state workloads never recompile. Confined to the owning context.
internal final class PipelineCache {
    struct RenderPipeline {
        let state: any MTLRenderPipelineState
        let bindings: PipelineBindings
        /// The programmable stages that get argument tables: vertex+fragment, or object (if present)+mesh+fragment.
        let stages: [MTLFunctionType]
        let functionTables: FunctionTables
        /// Built once per compiled pipeline; setup publishes it every frame.
        let reflection: Reflection?

        init(state: any MTLRenderPipelineState, bindings: PipelineBindings, stages: [MTLFunctionType] = [.vertex, .fragment]) {
            self.state = state
            self.bindings = bindings
            self.stages = stages
            functionTables = FunctionTables(render: state)
            reflection = state.reflection.map(Reflection.init)
        }
    }

    private struct MeshKey: Hashable {
        let object: ShaderFunction?
        let mesh: ShaderFunction
        let fragment: ShaderFunction
        let linked: [ShaderFunction]
        let colorPixelFormats: [MTLPixelFormat]
        let depthPixelFormat: MTLPixelFormat
        let stencilPixelFormat: MTLPixelFormat
        let rasterSampleCount: Int
        let label: String?
    }

    struct ComputePipeline {
        let state: any MTLComputePipelineState
        let bindings: PipelineBindings
        let functionTables: FunctionTables
        let reflection: Reflection?

        init(state: any MTLComputePipelineState, bindings: PipelineBindings) {
            self.state = state
            self.bindings = bindings
            functionTables = FunctionTables(compute: state)
            reflection = state.reflection.map(Reflection.init)
        }
    }

    private struct VertexLayoutKey: Hashable {
        let descriptor: MTLVertexDescriptor

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.descriptor.isEqual(rhs.descriptor) }
        func hash(into hasher: inout Hasher) { hasher.combine(descriptor.hash) }
    }

    private struct RenderKey: Hashable {
        let vertex: ShaderFunction
        let fragment: ShaderFunction
        let vertexLinked: [ShaderFunction]
        let fragmentLinked: [ShaderFunction]
        let colorPixelFormats: [MTLPixelFormat]
        let depthPixelFormat: MTLPixelFormat
        let stencilPixelFormat: MTLPixelFormat
        let rasterSampleCount: Int
        let vertexLayout: VertexLayoutKey?
        let base: DescriptorKey?
        let label: String?
    }

    /// Value identity for a private descriptor copy; Metal 4 descriptors implement `isEqual`/`hash` by value.
    private struct DescriptorKey: Hashable {
        let descriptor: MTL4RenderPipelineDescriptor

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.descriptor.isEqual(rhs.descriptor) }
        func hash(into hasher: inout Hasher) { hasher.combine(descriptor.hash) }
    }

    private struct ComputeKey: Hashable {
        let kernel: ShaderFunction
        let linked: [ShaderFunction]
        let label: String?
    }

    private let device: any MTLDevice
    let compiler: any MTL4Compiler
    private var renderPipelines: [RenderKey: RenderPipeline] = [:]
    private var computePipelines: [ComputeKey: ComputePipeline] = [:]
    private var meshPipelines: [MeshKey: RenderPipeline] = [:]

    private(set) var compilationCount = 0

    init(device: any MTLDevice) throws {
        self.device = device
        let descriptor = MTL4CompilerDescriptor()
        descriptor.label = "MetalSprockets compiler"
        compiler = try device.makeCompiler(descriptor: descriptor)
    }

    func renderPipeline(_ configuration: RenderPipelineConfiguration) throws -> RenderPipeline {
        // Vertex descriptors are mutable; copy so later caller mutation cannot change a cached identity.
        let layout = (configuration.vertexDescriptor?.copy() as? MTLVertexDescriptor).map(VertexLayoutKey.init)
        let vertexLinked = Self.uniqued(configuration.linkedFunctions + configuration.vertexLinkedFunctions)
        let fragmentLinked = Self.uniqued(configuration.linkedFunctions + configuration.fragmentLinkedFunctions)
        let key = RenderKey(
            vertex: configuration.vertex.reference,
            fragment: configuration.fragment.reference,
            vertexLinked: vertexLinked.map(\.reference),
            fragmentLinked: fragmentLinked.map(\.reference),
            colorPixelFormats: configuration.colorPixelFormats,
            depthPixelFormat: configuration.depthPixelFormat,
            stencilPixelFormat: configuration.stencilPixelFormat,
            rasterSampleCount: configuration.rasterSampleCount,
            vertexLayout: layout,
            base: (configuration.baseDescriptor?.copy() as? MTL4RenderPipelineDescriptor).map(DescriptorKey.init),
            label: configuration.label
        )
        if let cached = renderPipelines[key] {
            return cached
        }
        let allLinked = Self.uniqued(vertexLinked + fragmentLinked)
        try validate([key.vertex, key.fragment] + allLinked.map(\.reference), label: configuration.label)
        try Self.validateExportNames(key.vertexLinked, label: configuration.label)
        try Self.validateExportNames(key.fragmentLinked, label: configuration.label)
        try ShaderDeviceCheck.validateLinkedFunctions(allLinked, device: device, label: configuration.label)
        let descriptor = (key.base?.descriptor.copy() as? MTL4RenderPipelineDescriptor) ?? MTL4RenderPipelineDescriptor()
        descriptor.label = configuration.label ?? descriptor.label
        descriptor.vertexFunctionDescriptor = try key.vertex.makeFunctionDescriptor()
        descriptor.fragmentFunctionDescriptor = try key.fragment.makeFunctionDescriptor()
        for (index, format) in configuration.colorPixelFormats.enumerated() {
            // A format the caller configured explicitly wins over the pass's.
            let attachment = descriptor.colorAttachments[index]
            let explicit = attachment?.pixelFormat ?? .invalid
            Self.configure(attachment, format: explicit == .invalid ? format : explicit)
        }
        descriptor.rasterSampleCount = configuration.rasterSampleCount
        descriptor.vertexDescriptor = layout?.descriptor
        if !key.vertexLinked.isEmpty {
            descriptor.vertexStaticLinkingDescriptor = try Self.staticLinking(key.vertexLinked)
        }
        if !key.fragmentLinked.isEmpty {
            descriptor.fragmentStaticLinkingDescriptor = try Self.staticLinking(key.fragmentLinked)
        }
        descriptor.options = Self.reflectingOptions()
        // Depth and stencil formats are not MTL4RenderPipelineDescriptor state; they key the cache so pipelines built
        // for different pass layouts stay distinct, and render-state parity (#426) validates them against passes.
        let state = try compiler.makeRenderPipelineState(descriptor: descriptor)
        compilationCount += 1
        let reflection = try state.reflection.orThrow(.resourceCreationFailure("Metal 4 render pipeline returned no reflection"))
        let pipeline = RenderPipeline(state: state, bindings: PipelineBindings([(.vertex, reflection.vertexBindings), (.fragment, reflection.fragmentBindings)]))
        renderPipelines[key] = pipeline
        return pipeline
    }

    func meshRenderPipeline(_ configuration: MeshRenderPipelineConfiguration) throws -> RenderPipeline {
        let key = MeshKey(
            object: configuration.object?.reference,
            mesh: configuration.mesh.reference,
            fragment: configuration.fragment.reference,
            linked: configuration.linkedFunctions.map(\.reference),
            colorPixelFormats: configuration.colorPixelFormats,
            depthPixelFormat: configuration.depthPixelFormat,
            stencilPixelFormat: configuration.stencilPixelFormat,
            rasterSampleCount: configuration.rasterSampleCount,
            label: configuration.label
        )
        if let cached = meshPipelines[key] {
            return cached
        }
        guard device.supportsFamily(.apple7) || device.supportsFamily(.mac2) else {
            throw MetalSprocketsError.deviceCababilityFailure("Device '\(device.name)' does not support mesh shaders.")
        }
        try validate([key.object, key.mesh, key.fragment].compactMap(\.self) + key.linked, label: configuration.label)
        try Self.validateExportNames(key.linked, label: configuration.label)
        try ShaderDeviceCheck.validateLinkedFunctions(configuration.linkedFunctions, device: device, label: configuration.label)
        let descriptor = MTL4MeshRenderPipelineDescriptor()
        descriptor.label = configuration.label
        descriptor.objectFunctionDescriptor = try key.object?.makeFunctionDescriptor()
        descriptor.meshFunctionDescriptor = try key.mesh.makeFunctionDescriptor()
        descriptor.fragmentFunctionDescriptor = try key.fragment.makeFunctionDescriptor()
        for (index, format) in configuration.colorPixelFormats.enumerated() {
            Self.configure(descriptor.colorAttachments[index], format: format)
        }
        descriptor.rasterSampleCount = configuration.rasterSampleCount
        if !key.linked.isEmpty {
            let linking = MTL4StaticLinkingDescriptor()
            linking.functionDescriptors = try key.linked.map { try $0.makeFunctionDescriptor() }
            if key.object != nil {
                descriptor.objectStaticLinkingDescriptor = linking
            }
            descriptor.meshStaticLinkingDescriptor = linking
            descriptor.fragmentStaticLinkingDescriptor = linking
        }
        descriptor.options = Self.reflectingOptions()
        let state = try compiler.makeRenderPipelineState(descriptor: descriptor)
        compilationCount += 1
        let reflection = try state.reflection.orThrow(.resourceCreationFailure("Metal 4 mesh pipeline returned no reflection"))
        var stageBindings: [(MTLFunctionType, [any MTLBinding])] = [(.mesh, reflection.meshBindings), (.fragment, reflection.fragmentBindings)]
        if key.object != nil {
            stageBindings.insert((.object, reflection.objectBindings), at: 0)
        }
        let pipeline = RenderPipeline(state: state, bindings: PipelineBindings(stageBindings), stages: stageBindings.map(\.0))
        meshPipelines[key] = pipeline
        return pipeline
    }

    private static func staticLinking(_ functions: [ShaderFunction]) throws -> MTL4StaticLinkingDescriptor {
        let linking = MTL4StaticLinkingDescriptor()
        linking.functionDescriptors = try functions.map { try $0.makeFunctionDescriptor() }
        return linking
    }

    /// Shared and stage-specific lists can name the same function; link it once.
    private static func uniqued(_ functions: [VisibleFunction]) -> [VisibleFunction] {
        var seen: Set<ShaderFunction> = []
        return functions.filter { seen.insert($0.reference).inserted }
    }

    private static func configure(_ attachment: MTL4RenderPipelineColorAttachmentDescriptor?, format: MTLPixelFormat) {
        attachment?.pixelFormat = format
    }

    func computePipeline(kernel: ComputeKernel, linkedFunctions: [VisibleFunction] = [], label: String? = nil) throws -> ComputePipeline {
        let key = ComputeKey(kernel: kernel.reference, linked: linkedFunctions.map(\.reference), label: label)
        if let cached = computePipelines[key] {
            return cached
        }
        try validate([key.kernel] + key.linked, label: label)
        try Self.validateExportNames(key.linked, label: label)
        try ShaderDeviceCheck.validateLinkedFunctions(linkedFunctions, device: device, label: label)
        let descriptor = MTL4ComputePipelineDescriptor()
        descriptor.label = label
        descriptor.computeFunctionDescriptor = try key.kernel.makeFunctionDescriptor()
        if !key.linked.isEmpty {
            let linking = MTL4StaticLinkingDescriptor()
            linking.functionDescriptors = try key.linked.map { try $0.makeFunctionDescriptor() }
            descriptor.staticLinkingDescriptor = linking
        }
        descriptor.options = Self.reflectingOptions()
        let state = try compiler.makeComputePipelineState(descriptor: descriptor)
        compilationCount += 1
        let reflection = try state.reflection.orThrow(.resourceCreationFailure("Metal 4 compute pipeline returned no reflection"))
        let pipeline = ComputePipeline(state: state, bindings: PipelineBindings([(.kernel, reflection.bindings)]))
        computePipelines[key] = pipeline
        return pipeline
    }

    static func validateDevice(expected: ObjectIdentifier, actual: ObjectIdentifier, label: String?) throws {
        guard expected == actual else {
            let pipeline = label.map { "pipeline '\($0)'" } ?? "pipeline"
            throw MetalSprocketsError.configurationError("A shader for \(pipeline) belongs to a different MTLDevice than the Metal 4 context.")
        }
    }

    private func validate(_ functions: [ShaderFunction], label: String?) throws {
        for function in functions {
            try Self.validateDevice(expected: ObjectIdentifier(device), actual: ObjectIdentifier(function.library.device), label: label)
        }
    }

    /// Handles resolve by export name, so two different linked functions visible under one name would be ambiguous.
    static func validateExportNames(_ linked: [ShaderFunction], label: String?) throws {
        var seen: [String: ShaderFunction] = [:]
        for function in linked {
            if let existing = seen[function.exportName], existing != function {
                let pipeline = label.map { "pipeline '\($0)'" } ?? "pipeline"
                throw MetalSprocketsError.configurationError("Two different linked functions in \(pipeline) are both exported as '\(function.exportName)'. Give specializations distinct specializedName values.")
            }
            seen[function.exportName] = function
        }
    }

    private static func reflectingOptions() -> MTL4PipelineOptions {
        let options = MTL4PipelineOptions()
        options.shaderReflection = .bindingInfo
        return options
    }
}
