import Metal
import MetalSprocketsSupport

/// The argument table for each programmable stage of one draw or dispatch. Fixed slots instead of a dictionary: a
/// pipeline has at most a few stages, and this is built for every draw.
internal struct StageTables {
    /// Every table, in no particular order.
    var values: [any MTL4ArgumentTable] {
        [vertex, fragment, kernel, object, mesh].compactMap(\.self) + Array(other.values)
    }

    private var vertex: (any MTL4ArgumentTable)?
    private var fragment: (any MTL4ArgumentTable)?
    private var kernel: (any MTL4ArgumentTable)?
    private var object: (any MTL4ArgumentTable)?
    private var mesh: (any MTL4ArgumentTable)?
    private var other: [MTLFunctionType: any MTL4ArgumentTable] = [:]

    subscript(stage: MTLFunctionType) -> (any MTL4ArgumentTable)? {
        get {
            switch stage {
            case .vertex: vertex
            case .fragment: fragment
            case .kernel: kernel
            case .object: object
            case .mesh: mesh
            default: other[stage]
            }
        }
        set {
            switch stage {
            case .vertex: vertex = newValue
            case .fragment: fragment = newValue
            case .kernel: kernel = newValue
            case .object: object = newValue
            case .mesh: mesh = newValue
            default: other[stage] = newValue
            }
        }
    }
}

/// Named and indexed shader inputs resolved against reflected pipeline bindings into per-stage argument tables.
///
/// Every `makeTables` call leases cleared tables, so a draw or dispatch can never inherit a stale binding
/// from a sibling or an earlier draw. Buffers and textures register residency through the recording scope; values are
/// copied into the scope's scratch storage.
internal struct ParameterSet {
    enum Failure: Error, Equatable {
        case missingBinding(String)
        case kindMismatch(name: String, expected: MTLBindingType)
        case offsetOutOfRange(name: String, offset: Int, length: Int)
        case textureArrayTooLong(name: String, count: Int, capacity: Int)
        case invalidVertexBufferIndex(Int)
        case tableCreationFailed(MTLFunctionType)
        case functionTableNotFound(String)
        case ambiguousFunctionTable(name: String, stages: [MTLFunctionType])
        case unsupportedFunctionTableStage(name: String, stage: MTLFunctionType)
        case unlinkedFunction(table: String, function: String)
    }

    private struct FunctionTableEntry {
        let name: String
        let stage: MTLFunctionType?
        let functions: [VisibleFunction]
    }

    private enum Value {
        case buffer(any MTLBuffer, offset: Int)
        case texture((any MTLTexture)?)
        case textures([any MTLTexture])
        case sampler(any MTLSamplerState)
        case bytes((RecordingScope) throws -> MTLGPUAddress)
        case accelerationStructure(any MTLAccelerationStructure)

        func accepts(_ type: MTLBindingType) -> Bool {
            switch self {
            case .buffer, .bytes:
                type == .buffer
            case .texture, .textures:
                type == .texture
            case .sampler:
                type == .sampler
            case .accelerationStructure:
                type == .instanceAccelerationStructure || type == .primitiveAccelerationStructure
            }
        }
    }

    private struct Entry {
        let name: String
        let stages: FunctionTypes
        let value: Value
        let isOptional: Bool
    }

    // Buffer argument slots available to an argument table.
    static let maximumBufferIndex = 30

    private var entries: [Entry] = []
    private var vertexBuffers: [(index: Int, buffer: any MTLBuffer, offset: Int)] = []
    private var functionTableEntries: [FunctionTableEntry] = []
    private var vertexValues: [(index: Int, store: (RecordingScope) throws -> MTLGPUAddress)] = []

    /// Adds every entry of `other` after this set's own, so `other` wins where names collide.
    mutating func append(contentsOf other: Self) {
        entries += other.entries
        vertexBuffers += other.vertexBuffers
        functionTableEntries += other.functionTableEntries
        vertexValues += other.vertexValues
    }

    /// Binds a visible-function table filled with `functions`. A nil `stage` resolves from reflection and must be unique.
    mutating func setFunctionTable(_ name: String, stage: MTLFunctionType? = nil, functions: [VisibleFunction]) {
        functionTableEntries.append(FunctionTableEntry(name: name, stage: stage, functions: functions))
    }

    mutating func set(_ name: String, buffer: any MTLBuffer, offset: Int = 0, stages: FunctionTypes = [], isOptional: Bool = false) {
        entries.append(Entry(name: name, stages: stages, value: .buffer(buffer, offset: offset), isOptional: isOptional))
    }

    /// A nil texture leaves its slot cleared.
    mutating func set(_ name: String, texture: (any MTLTexture)?, stages: FunctionTypes = [], isOptional: Bool = false) {
        entries.append(Entry(name: name, stages: stages, value: .texture(texture), isOptional: isOptional))
    }

    /// Binds an array texture argument, writing each texture to consecutive slots from the reflected base index.
    mutating func set(_ name: String, textures: [any MTLTexture], stages: FunctionTypes = [], isOptional: Bool = false) {
        entries.append(Entry(name: name, stages: stages, value: .textures(textures), isOptional: isOptional))
    }

    mutating func set(_ name: String, sampler: any MTLSamplerState, stages: FunctionTypes = [], isOptional: Bool = false) {
        entries.append(Entry(name: name, stages: stages, value: .sampler(sampler), isOptional: isOptional))
    }

    mutating func set(_ name: String, accelerationStructure: any MTLAccelerationStructure, stages: FunctionTypes = [], isOptional: Bool = false) {
        entries.append(Entry(name: name, stages: stages, value: .accelerationStructure(accelerationStructure), isOptional: isOptional))
    }

    mutating func set<T>(_ name: String, value: T, stages: FunctionTypes = [], isOptional: Bool = false) {
        entries.append(Entry(name: name, stages: stages, value: .bytes { try $0.scratch(value).gpuAddress }, isOptional: isOptional))
    }

    mutating func set<T>(_ name: String, values: [T], stages: FunctionTypes = [], isOptional: Bool = false) {
        entries.append(Entry(name: name, stages: stages, value: .bytes { try $0.scratch(values).gpuAddress }, isOptional: isOptional))
    }

    /// Binds a `[[stage_in]]` vertex layout buffer by its layout index. Reflection does not name these slots reliably.
    mutating func setVertexBuffer(_ buffer: any MTLBuffer, layoutIndex: Int, offset: Int = 0) {
        vertexBuffers.append((layoutIndex, buffer, offset))
    }

    /// Copies small per-draw vertex data into scratch storage, the counterpart of legacy `setVertexBytes`.
    mutating func setVertexValues<T>(_ values: [T], layoutIndex: Int) {
        vertexValues.append((layoutIndex, { try $0.scratch(values).gpuAddress }))
    }

    /// Argument table label for one stage of a pipeline. Pipelines precompute these (`tableLabels`) so draws do not build
    /// strings (#514).
    static func tableLabel(pipelineLabel: String?, stage: MTLFunctionType) -> String {
        let stageName = switch stage {
        case .vertex: "Vertex"
        case .fragment: "Fragment"
        case .kernel: "Compute"
        case .object: "Object"
        case .mesh: "Mesh"
        default: "Stage \(stage.rawValue)"
        }
        return "\(pipelineLabel ?? "MetalSprockets"): \(stageName) Arguments"
    }

    static func tableLabels(pipelineLabel: String?, stages: [MTLFunctionType]) -> [MTLFunctionType: String] {
        Dictionary(uniqueKeysWithValues: stages.map { ($0, tableLabel(pipelineLabel: pipelineLabel, stage: $0)) })
    }

    func makeTables(for bindings: PipelineBindings, stages: [MTLFunctionType], functionTables: FunctionTables? = nil, pipelineLabel: String? = nil, tableLabels: [MTLFunctionType: String] = [:], scope: RecordingScope) throws -> StageTables {
        try validateVertexInputs()
        var tables = StageTables()
        for stage in stages {
            var sizes = bindings.tableSizes(stage: stage)
            if stage == .vertex, let highest = highestVertexIndex {
                sizes.buffers = max(sizes.buffers, highest + 1)
            }
            guard sizes.buffers + sizes.textures + sizes.samplers > 0 else {
                continue
            }
            let label = tableLabels[stage] ?? Self.tableLabel(pipelineLabel: pipelineLabel, stage: stage)
            tables[stage] = try scope.argumentTable(sizes: sizes, label: label)
        }
        for entry in entries {
            try bind(entry, bindings: bindings, stages: stages, tables: tables, scope: scope)
        }
        for entry in functionTableEntries {
            let stage = try Self.resolveStage(entry, bindings: bindings, stages: stages)
            let index = try bindings.index(of: entry.name, stage: stage).orThrow(.generic("No binding for \(entry.name)"))
            let cache = try functionTables.orThrow(.generic("This pipeline cannot provide visible function tables"))
            let table = try cache.table(named: entry.name, stage: stage, functions: entry.functions)
            if let resources = cache.resources {
                try scope.useResourceCollection(resources)
            }
            try scope.retainAllocation(table)
            let argumentTable = try tables[stage].orThrow(.generic("No argument table for stage \(stage)"))
            argumentTable.setResource(table.gpuResourceID, bufferIndex: index)
        }
        if let vertexTable = tables[.vertex] {
            for vertexBuffer in vertexBuffers {
                try scope.retainAllocation(vertexBuffer.buffer)
                vertexTable.setAddress(vertexBuffer.buffer.gpuAddress + UInt64(vertexBuffer.offset), index: vertexBuffer.index)
            }
            for vertexValue in vertexValues {
                vertexTable.setAddress(try vertexValue.store(scope), index: vertexValue.index)
            }
        }
        return tables
    }

    private var highestVertexIndex: Int? {
        var highest: Int?
        for vertexBuffer in vertexBuffers {
            highest = max(highest ?? vertexBuffer.index, vertexBuffer.index)
        }
        for vertexValue in vertexValues {
            highest = max(highest ?? vertexValue.index, vertexValue.index)
        }
        return highest
    }

    private func bind(_ entry: Entry, bindings: PipelineBindings, stages: [MTLFunctionType], tables: StageTables, scope: RecordingScope) throws {
        var address: MTLGPUAddress?
        var matched = false
        for stage in stages {
            // Empty stage filters mean every requested stage, matching the legacy parameter API.
            guard entry.stages.isEmpty || entry.stages.contains(FunctionTypes(stage)), let binding = bindings.binding(named: entry.name, stage: stage) else {
                continue
            }
            matched = true
            guard entry.value.accepts(binding.type) else {
                throw Failure.kindMismatch(name: entry.name, expected: binding.type)
            }
            let table = try tables[stage].orThrow(.generic("No argument table for stage \(stage)"))
            switch entry.value {
            case let .buffer(buffer, offset):
                try Self.validate(name: entry.name, buffer: buffer, offset: offset)
                try scope.retainAllocation(buffer)
                table.setAddress(buffer.gpuAddress + UInt64(offset), index: binding.index)
            case .texture(let texture):
                if let texture {
                    try scope.retainAllocation(texture)
                    table.setTexture(texture.gpuResourceID, index: binding.index)
                }
            case .textures(let textures):
                guard textures.count <= binding.arrayLength else {
                    throw Failure.textureArrayTooLong(name: entry.name, count: textures.count, capacity: binding.arrayLength)
                }
                for (offset, texture) in textures.enumerated() {
                    try scope.retainAllocation(texture)
                    table.setTexture(texture.gpuResourceID, index: binding.index + offset)
                }
            case .sampler(let sampler):
                try scope.retainObject(sampler)
                table.setSamplerState(sampler.gpuResourceID, index: binding.index)
            case .bytes(let store):
                // Copy once and share the address across every stage that reads this value.
                let resolved = try address ?? store(scope)
                address = resolved
                table.setAddress(resolved, index: binding.index)
            case .accelerationStructure(let accelerationStructure):
                try scope.retainAllocation(accelerationStructure)
                table.setResource(accelerationStructure.gpuResourceID, bufferIndex: binding.index)
            }
        }
        if !matched, !entry.isOptional {
            throw Failure.missingBinding(entry.name)
        }
    }

    private func validateVertexInputs() throws {
        for vertexBuffer in vertexBuffers {
            guard (0...Self.maximumBufferIndex).contains(vertexBuffer.index) else {
                throw Failure.invalidVertexBufferIndex(vertexBuffer.index)
            }
            try Self.validate(name: "vertex buffer \(vertexBuffer.index)", buffer: vertexBuffer.buffer, offset: vertexBuffer.offset)
        }
        for vertexValue in vertexValues where !(0...Self.maximumBufferIndex).contains(vertexValue.index) {
            throw Failure.invalidVertexBufferIndex(vertexValue.index)
        }
    }

    private static func resolveStage(_ entry: FunctionTableEntry, bindings: PipelineBindings, stages: [MTLFunctionType]) throws -> MTLFunctionType {
        let isTable = { (stage: MTLFunctionType) in bindings.binding(named: entry.name, stage: stage)?.type == .visibleFunctionTable }
        if let stage = entry.stage {
            guard stages.contains(stage) else {
                throw Failure.unsupportedFunctionTableStage(name: entry.name, stage: stage)
            }
            guard isTable(stage) else {
                throw Failure.functionTableNotFound(entry.name)
            }
            return stage
        }
        // A table is stage-specific, so a name bound in several stages cannot be guessed.
        let matches = stages.filter(isTable)
        guard let stage = matches.first else {
            throw Failure.functionTableNotFound(entry.name)
        }
        guard matches.count == 1 else {
            throw Failure.ambiguousFunctionTable(name: entry.name, stages: matches)
        }
        return stage
    }

    private static func validate(name: String, buffer: any MTLBuffer, offset: Int) throws {
        guard offset >= 0, offset < buffer.length else {
            throw Failure.offsetOutOfRange(name: name, offset: offset, length: buffer.length)
        }
    }
}

extension ParameterSet.Failure: CustomStringConvertible {
    var description: String {
        switch self {
        case .missingBinding(let name):
            "Parameter '\(name)' is not a binding of any stage the filter allows in this pipeline."
        case let .kindMismatch(name, expected):
            "Parameter '\(name)' has the wrong kind; the shader expects a \(expected) binding."
        case let .offsetOutOfRange(name, offset, length):
            "Parameter '\(name)' offset \(offset) is outside its buffer of \(length) bytes."
        case let .textureArrayTooLong(name, count, capacity):
            "Parameter '\(name)' was given \(count) textures but the shader's array holds \(capacity)."
        case .invalidVertexBufferIndex(let index):
            "Vertex buffer index \(index) is outside the argument table's buffer slots."
        case .tableCreationFailed(let stage):
            "Could not create a Metal 4 argument table for the \(stage) stage."
        case .functionTableNotFound(let name):
            "Visible function table '\(name)' is not found in the requested stage's bindings."
        case let .ambiguousFunctionTable(name, stages):
            "Visible function table '\(name)' is found in multiple function types (\(stages)); specify functionType explicitly."
        case let .unsupportedFunctionTableStage(name, stage):
            "Visible function table '\(name)' names functionType \(stage), which this pipeline does not have."
        case let .unlinkedFunction(table, function):
            "Visible function table '\(table)' lists '\(function)', which is not linked into the pipeline. Add it with .linkedFunctions(_:)."
        }
    }
}
