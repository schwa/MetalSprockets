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
    /// Caller-configured pipeline state (for example blending from `renderPipelineDescriptorTransformer`). The cache
    /// fills in shaders, layout, and sample count. It fills in color formats only where the base has `.invalid`.
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
        /// Built once for each compiled pipeline. Setup publishes it every frame.
        let reflection: Reflection?
        let tableLabels: [MTLFunctionType: String]

        init(state: any MTLRenderPipelineState, bindings: PipelineBindings, stages: [MTLFunctionType] = [.vertex, .fragment], reflection: MTLRenderPipelineReflection? = nil, base: (any MTLRenderPipelineState)? = nil, binaryFunctions: [MTLFunctionType: [String: any MTL4BinaryFunction]] = [:]) {
            self.state = state
            self.bindings = bindings
            self.stages = stages
            functionTables = FunctionTables(render: state, base: base, binaryFunctions: binaryFunctions)
            self.reflection = (reflection ?? state.reflection).map(Reflection.init)
            tableLabels = ParameterSet.tableLabels(pipelineLabel: state.label, stages: stages)
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
        let tableLabels: [MTLFunctionType: String]

        init(state: any MTLComputePipelineState, bindings: PipelineBindings, reflection: MTLComputePipelineReflection? = nil, base: (any MTLComputePipelineState)? = nil, binaryFunctions: [String: any MTL4BinaryFunction] = [:]) {
            self.state = state
            self.bindings = bindings
            functionTables = FunctionTables(compute: state, base: base, binaryFunctions: binaryFunctions)
            self.reflection = (reflection ?? state.reflection).map(Reflection.init)
            tableLabels = ParameterSet.tableLabels(pipelineLabel: state.label, stages: [.kernel])
        }
    }

    private struct VertexLayoutKey: Hashable {
        let descriptor: MTLVertexDescriptor

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.descriptor.isEqual(rhs.descriptor) }
        func hash(into hasher: inout Hasher) { hasher.combine(descriptor.hash) }
    }

    private struct RenderKey: Hashable {
        let base: RenderBaseKey
        let vertexBinary: [ShaderFunction]
        let fragmentBinary: [ShaderFunction]
    }

    /// Everything in a render pipeline's identity except its binary-linked functions.
    private struct RenderBaseKey: Hashable {
        let vertexStatic: [ShaderFunction]
        let fragmentStatic: [ShaderFunction]
        let vertex: ShaderFunction
        let fragment: ShaderFunction
        let colorPixelFormats: [MTLPixelFormat]
        let depthPixelFormat: MTLPixelFormat
        let stencilPixelFormat: MTLPixelFormat
        let rasterSampleCount: Int
        let vertexLayout: VertexLayoutKey?
        let descriptor: DescriptorKey?
        let label: String?
    }

    /// A render pipeline built once with binary linking, so new linked functions do not rebuild its shaders.
    private enum RenderBase {
        case binary(any MTLRenderPipelineState, MTLRenderPipelineReflection)
        /// A shader calls linked functions directly (`extern`), which needs static linking.
        case staticOnly
    }

    /// Value identity for a private descriptor copy. Metal 4 descriptors implement `isEqual` and `hash` by value.
    private struct DescriptorKey: Hashable {
        let descriptor: MTL4RenderPipelineDescriptor

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.descriptor.isEqual(rhs.descriptor) }
        func hash(into hasher: inout Hasher) { hasher.combine(descriptor.hash) }
    }

    private struct ComputeKey: Hashable {
        let base: ComputeBaseKey
        let binary: [ShaderFunction]
    }

    private struct ComputeBaseKey: Hashable {
        let kernel: ShaderFunction
        let staticLinked: [ShaderFunction]
        let label: String?
    }

    /// A kernel pipeline built once with binary linking, so new linked functions do not rebuild the kernel.
    private enum ComputeBase {
        case binary(any MTLComputePipelineState, MTLComputePipelineReflection)
        /// The kernel calls linked functions directly (`extern`), which needs static linking.
        case staticOnly
    }

    private let device: any MTLDevice
    let compiler: any MTL4Compiler
    private var renderPipelines: [RenderKey: RenderPipeline] = [:]
    private var computePipelines: [ComputeKey: ComputePipeline] = [:]
    private var computeBases: [ComputeBaseKey: ComputeBase] = [:]
    private var renderBases: [RenderBaseKey: RenderBase] = [:]
    private var binaryFunctions: [ShaderFunction: any MTL4BinaryFunction] = [:]
    private var meshPipelines: [MeshKey: RenderPipeline] = [:]

    private(set) var compilationCount = 0

    /// False under GPU frame capture, where binary-linked pipelines crash (#542). Then every linked function links
    /// statically, so each new set of linked functions compiles a new pipeline.
    let allowsBinaryLinking: Bool

    init(device: any MTLDevice) throws {
        self.device = device
        allowsBinaryLinking = !Self.isCaptureDevice(device)
        if !allowsBinaryLinking {
            logger?.warning("GPU frame capture is active. Linked functions link statically, so new linked functions recompile pipelines (#542).")
        }
        let descriptor = MTL4CompilerDescriptor()
        descriptor.label = "MetalSprockets compiler"
        compiler = try device.makeCompiler(descriptor: descriptor)
    }

    func renderPipeline(_ configuration: RenderPipelineConfiguration) throws -> RenderPipeline {
        // Vertex descriptors are mutable; copy so later caller mutation cannot change a cached identity.
        let layout = (configuration.vertexDescriptor?.copy() as? MTLVertexDescriptor).map(VertexLayoutKey.init)
        let vertexLinked = Self.uniqued(configuration.linkedFunctions + configuration.vertexLinkedFunctions)
        let fragmentLinked = Self.uniqued(configuration.linkedFunctions + configuration.fragmentLinkedFunctions)
        let baseKey = RenderBaseKey(
            vertexStatic: Self.references(vertexLinked, .static),
            fragmentStatic: Self.references(fragmentLinked, .static),
            vertex: configuration.vertex.reference,
            fragment: configuration.fragment.reference,
            colorPixelFormats: configuration.colorPixelFormats,
            depthPixelFormat: configuration.depthPixelFormat,
            stencilPixelFormat: configuration.stencilPixelFormat,
            rasterSampleCount: configuration.rasterSampleCount,
            vertexLayout: layout,
            descriptor: (configuration.baseDescriptor?.copy() as? MTL4RenderPipelineDescriptor).map(DescriptorKey.init),
            label: configuration.label
        )
        let key = RenderKey(base: baseKey, vertexBinary: Self.references(vertexLinked, .binary), fragmentBinary: Self.references(fragmentLinked, .binary))
        if let cached = renderPipelines[key] {
            return cached
        }
        let allLinked = Self.uniqued(vertexLinked + fragmentLinked)
        try validate([baseKey.vertex, baseKey.fragment] + allLinked.map(\.reference), label: configuration.label)
        try Self.validateExportNames(vertexLinked.map(\.reference), label: configuration.label)
        try Self.validateExportNames(fragmentLinked.map(\.reference), label: configuration.label)
        try ShaderDeviceCheck.validateLinkedFunctions(allLinked, device: device, label: configuration.label)
        let hasBinary = !key.vertexBinary.isEmpty || !key.fragmentBinary.isEmpty
        if hasBinary, allowsBinaryLinking, case let .binary(base, reflection) = try renderBase(baseKey) {
            let vertexBinaries = try key.vertexBinary.map { try binaryFunction($0) }
            let fragmentBinaries = try key.fragmentBinary.map { try binaryFunction($0) }
            let functions = MTL4RenderPipelineBinaryFunctionsDescriptor()
            functions.vertexAdditionalBinaryFunctions = vertexBinaries
            functions.fragmentAdditionalBinaryFunctions = fragmentBinaries
            let state = try base.makeRenderPipelineState(additionalBinaryFunctions: functions)
            let named: [MTLFunctionType: [String: any MTL4BinaryFunction]] = [
                .vertex: Dictionary(zip(key.vertexBinary.map(\.exportName), vertexBinaries)) { first, _ in first },
                .fragment: Dictionary(zip(key.fragmentBinary.map(\.exportName), fragmentBinaries)) { first, _ in first }
            ]
            let bindings = PipelineBindings([(.vertex, reflection.vertexBindings), (.fragment, reflection.fragmentBindings)])
            let pipeline = RenderPipeline(state: state, bindings: bindings, reflection: reflection, base: base, binaryFunctions: named)
            renderPipelines[key] = pipeline
            return pipeline
        }
        // No binary functions, or the shaders need static linking: link everything statically.
        let descriptor = try makeRenderDescriptor(baseKey)
        let vertexAll = baseKey.vertexStatic + key.vertexBinary
        let fragmentAll = baseKey.fragmentStatic + key.fragmentBinary
        descriptor.vertexStaticLinkingDescriptor = vertexAll.isEmpty ? nil : try Self.staticLinking(vertexAll)
        descriptor.fragmentStaticLinkingDescriptor = fragmentAll.isEmpty ? nil : try Self.staticLinking(fragmentAll)
        // Depth and stencil formats are not MTL4RenderPipelineDescriptor state; they key the cache so pipelines built
        // for different pass layouts stay distinct, and render-state parity (#426) validates them against passes.
        let state = try compiler.makeRenderPipelineState(descriptor: descriptor)
        compilationCount += 1
        let reflection = try state.reflection.orThrow(.resourceCreationFailure("Metal 4 render pipeline returned no reflection"))
        let pipeline = RenderPipeline(state: state, bindings: PipelineBindings([(.vertex, reflection.vertexBindings), (.fragment, reflection.fragmentBindings)]))
        renderPipelines[key] = pipeline
        return pipeline
    }

    private func makeRenderDescriptor(_ key: RenderBaseKey) throws -> MTL4RenderPipelineDescriptor {
        let descriptor = (key.descriptor?.descriptor.copy() as? MTL4RenderPipelineDescriptor) ?? MTL4RenderPipelineDescriptor()
        descriptor.label = key.label ?? descriptor.label
        descriptor.vertexFunctionDescriptor = try key.vertex.makeFunctionDescriptor()
        descriptor.fragmentFunctionDescriptor = try key.fragment.makeFunctionDescriptor()
        for (index, format) in key.colorPixelFormats.enumerated() {
            // A format the caller configured explicitly wins over the pass's.
            let attachment = descriptor.colorAttachments[index]
            let explicit = attachment?.pixelFormat ?? .invalid
            Self.configure(attachment, format: explicit == .invalid ? format : explicit)
        }
        descriptor.rasterSampleCount = key.rasterSampleCount
        descriptor.vertexDescriptor = key.vertexLayout?.descriptor
        if !key.vertexStatic.isEmpty {
            descriptor.vertexStaticLinkingDescriptor = try Self.staticLinking(key.vertexStatic)
        }
        if !key.fragmentStatic.isEmpty {
            descriptor.fragmentStaticLinkingDescriptor = try Self.staticLinking(key.fragmentStatic)
        }
        descriptor.options = Self.reflectingOptions()
        return descriptor
    }

    private func renderBase(_ key: RenderBaseKey) throws -> RenderBase {
        if let cached = renderBases[key] {
            return cached
        }
        let descriptor = try makeRenderDescriptor(key)
        descriptor.supportVertexBinaryLinking = true
        descriptor.supportFragmentBinaryLinking = true
        let base: RenderBase
        // Any failure falls back to static linking, which reports the real error if there is one.
        if let state = try? compiler.makeRenderPipelineState(descriptor: descriptor), let reflection = state.reflection {
            compilationCount += 1
            base = .binary(state, reflection)
        } else {
            base = .staticOnly
        }
        renderBases[key] = base
        return base
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

    private static func references(_ functions: [VisibleFunction], _ linking: VisibleFunction.Linking) -> [ShaderFunction] {
        functions.filter { $0.linking == linking }.map(\.reference)
    }

    /// Shared and stage-specific lists can name the same function. Link it once.
    /// If the lists disagree on its linking, the first occurrence wins.
    private static func uniqued(_ functions: [VisibleFunction]) -> [VisibleFunction] {
        var seen: Set<ShaderFunction> = []
        return functions.filter { seen.insert($0.reference).inserted }
    }

    private static func configure(_ attachment: MTL4RenderPipelineColorAttachmentDescriptor?, format: MTLPixelFormat) {
        attachment?.pixelFormat = format
    }

    func computePipeline(kernel: ComputeKernel, linkedFunctions: [VisibleFunction] = [], label: String? = nil) throws -> ComputePipeline {
        let linkedFunctions = Self.uniqued(linkedFunctions)
        let baseKey = ComputeBaseKey(kernel: kernel.reference, staticLinked: Self.references(linkedFunctions, .static), label: label)
        let key = ComputeKey(base: baseKey, binary: Self.references(linkedFunctions, .binary))
        if let cached = computePipelines[key] {
            return cached
        }
        let allLinked = linkedFunctions.map(\.reference)
        try validate([baseKey.kernel] + allLinked, label: label)
        try Self.validateExportNames(allLinked, label: label)
        try ShaderDeviceCheck.validateLinkedFunctions(linkedFunctions, device: device, label: label)
        if !key.binary.isEmpty, allowsBinaryLinking, case .binary(_, let reflection) = try computeBase(baseKey) {
            let binaries = try key.binary.map { try binaryFunction($0) }
            // Pass the binary functions at creation. Adding them to the base pipeline with
            // makeComputePipelineState(additionalBinaryFunctions:) crashes under Metal API validation (#541).
            // This is a pipeline creation, not a kernel compile, so compilationCount does not count it.
            let linking = MTL4PipelineStageDynamicLinkingDescriptor()
            linking.binaryLinkedFunctions = binaries
            let state = try compiler.makeComputePipelineState(descriptor: try makeComputeDescriptor(baseKey), dynamicLinkingDescriptor: linking, compilerTaskOptions: nil)
            let named = Dictionary(zip(key.binary.map(\.exportName), binaries)) { first, _ in first }
            // The state holds the static functions too, so table lookups need no base.
            let pipeline = ComputePipeline(state: state, bindings: PipelineBindings([(.kernel, reflection.bindings)]), reflection: reflection, binaryFunctions: named)
            computePipelines[key] = pipeline
            return pipeline
        }
        // No binary functions, or the kernel needs static linking: link everything statically.
        let descriptor = MTL4ComputePipelineDescriptor()
        descriptor.label = label
        descriptor.computeFunctionDescriptor = try baseKey.kernel.makeFunctionDescriptor()
        let staticAll = baseKey.staticLinked + key.binary
        if !staticAll.isEmpty {
            descriptor.staticLinkingDescriptor = try Self.staticLinking(staticAll)
        }
        descriptor.options = Self.reflectingOptions()
        let state = try compiler.makeComputePipelineState(descriptor: descriptor)
        compilationCount += 1
        let reflection = try state.reflection.orThrow(.resourceCreationFailure("Metal 4 compute pipeline returned no reflection"))
        let pipeline = ComputePipeline(state: state, bindings: PipelineBindings([(.kernel, reflection.bindings)]))
        computePipelines[key] = pipeline
        return pipeline
    }

    private func computeBase(_ key: ComputeBaseKey) throws -> ComputeBase {
        if let cached = computeBases[key] {
            return cached
        }
        let descriptor = try makeComputeDescriptor(key)
        let base: ComputeBase
        // Any failure falls back to static linking, which reports the real error if there is one.
        if let state = try? compiler.makeComputePipelineState(descriptor: descriptor), let reflection = state.reflection {
            compilationCount += 1
            base = .binary(state, reflection)
        } else {
            base = .staticOnly
        }
        computeBases[key] = base
        return base
    }

    /// The descriptor for a kernel pipeline that accepts binary-linked functions.
    private func makeComputeDescriptor(_ key: ComputeBaseKey) throws -> MTL4ComputePipelineDescriptor {
        let descriptor = MTL4ComputePipelineDescriptor()
        descriptor.label = key.label
        descriptor.computeFunctionDescriptor = try key.kernel.makeFunctionDescriptor()
        if !key.staticLinked.isEmpty {
            descriptor.staticLinkingDescriptor = try Self.staticLinking(key.staticLinked)
        }
        descriptor.supportBinaryLinking = true
        descriptor.options = Self.reflectingOptions()
        return descriptor
    }

    private func binaryFunction(_ function: ShaderFunction) throws -> any MTL4BinaryFunction {
        if let cached = binaryFunctions[function] {
            return cached
        }
        let descriptor = MTL4BinaryFunctionDescriptor()
        descriptor.name = function.exportName
        descriptor.functionDescriptor = try function.makeFunctionDescriptor()
        let binary = try compiler.makeBinaryFunction(descriptor: descriptor, compilerTaskOptions: nil)
        binaryFunctions[function] = binary
        return binary
    }

    /// Under capture, MTL4Compiler.makeBinaryFunction returns functions that the capture layer cannot unwrap, and any
    /// pipeline call that takes them raises an Objective-C exception (#542). Swift cannot catch that, and Metal has no
    /// public API that reports capture is on (MTLCaptureManager.supportsDestination is false), so this checks the
    /// class name of the capture layer's device wrapper. That name is private and can change.
    static func isCaptureDevice(_ device: any MTLDevice) -> Bool {
        String(describing: type(of: device)).hasPrefix("Capture")
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

    /// Handles resolve by export name, so two different linked functions with one name are ambiguous.
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
