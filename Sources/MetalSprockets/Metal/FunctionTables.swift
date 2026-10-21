import Metal
import MetalSprocketsSupport

/// Visible-function tables for one compiled pipeline, filled from its function handles and reused across frames.
///
/// After the tables are filled, they do not change. Thus reuse is safe while earlier submissions are on the GPU. Each
/// use still retains the table on the recording scope, for residency and for its lifetime until completion. Confined to the owning context.
internal final class FunctionTables {
    private struct Key: Hashable {
        let stage: MTLFunctionType
        let functions: [ShaderFunction]
    }

    private let makeTable: (MTLFunctionType, Int) -> (any MTLVisibleFunctionTable)?
    private let handle: (String, MTLFunctionType) -> (any MTLFunctionHandle)?
    private var tables: [Key: any MTLVisibleFunctionTable] = [:]
    private(set) var creationCount = 0
    private(set) var resources: ResourceCollection?

    /// `base` is the pipeline that `state` extends with binary functions. Static functions resolve by name only there.
    init(render state: any MTLRenderPipelineState, base: (any MTLRenderPipelineState)? = nil, binaryFunctions: [MTLFunctionType: [String: any MTL4BinaryFunction]] = [:]) {
        makeTable = { stage, count in
            let descriptor = MTLVisibleFunctionTableDescriptor()
            descriptor.functionCount = count
            return state.makeVisibleFunctionTable(descriptor: descriptor, stage: Self.renderStage(stage))
        }
        handle = { name, stage in
            if let binary = binaryFunctions[stage]?[name] {
                return state.functionHandle(function: binary, stage: Self.renderStage(stage))
            }
            return state.functionHandle(withName: name, stage: Self.renderStage(stage))
                ?? base?.functionHandle(withName: name, stage: Self.renderStage(stage))
        }
    }

    /// Name lookup does not find binary-linked functions, so those resolve through `binaryFunctions`.
    init(compute state: any MTLComputePipelineState, base: (any MTLComputePipelineState)? = nil, binaryFunctions: [String: any MTL4BinaryFunction] = [:]) {
        makeTable = { _, count in
            let descriptor = MTLVisibleFunctionTableDescriptor()
            descriptor.functionCount = count
            return state.makeVisibleFunctionTable(descriptor: descriptor)
        }
        handle = { name, _ in
            if let binary = binaryFunctions[name] {
                return state.functionHandle(function: binary)
            }
            return state.functionHandle(withName: name) ?? base?.functionHandle(withName: name)
        }
    }

    func table(named name: String, stage: MTLFunctionType, functions: [VisibleFunction]) throws -> any MTLVisibleFunctionTable {
        let key = Key(stage: stage, functions: functions.map(\.reference))
        if let cached = tables[key] {
            return cached
        }
        let table = try makeTable(stage, functions.count).orThrow(.resourceCreationFailure("Failed to create visible function table '\(name)'"))
        for (index, function) in functions.enumerated() {
            let exportName = function.reference.exportName
            guard let handle = handle(exportName, stage) else {
                throw ParameterSet.Failure.unlinkedFunction(table: name, function: exportName)
            }
            table.setFunction(handle, index: index)
        }
        table.label = name
        if resources == nil {
            resources = try ResourceCollection(device: table.device)
        }
        try resources?.register(table)
        creationCount += 1
        tables[key] = table
        return table
    }

    static func renderStage(_ stage: MTLFunctionType) -> MTLRenderStages {
        switch stage {
        case .vertex:
            .vertex
        case .object:
            .object
        case .mesh:
            .mesh
        default:
            .fragment
        }
    }
}

internal extension ShaderFunction {
    /// The name a linked function is visible under inside a pipeline.
    var exportName: String { specializedName ?? name }
}
