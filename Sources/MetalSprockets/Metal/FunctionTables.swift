import Metal
import MetalSprocketsSupport

/// Visible-function tables for one compiled pipeline, filled from its function handles and reused across frames.
///
/// Tables are immutable once filled, so reuse is safe while earlier submissions are in flight; each use still retains
/// the table on the recording scope for residency and completion-bound lifetime. Confined to the owning context.
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

    init(render state: any MTLRenderPipelineState) {
        makeTable = { stage, count in
            let descriptor = MTLVisibleFunctionTableDescriptor()
            descriptor.functionCount = count
            return state.makeVisibleFunctionTable(descriptor: descriptor, stage: Self.renderStage(stage))
        }
        handle = { name, stage in state.functionHandle(withName: name, stage: Self.renderStage(stage)) }
    }

    init(compute state: any MTLComputePipelineState) {
        makeTable = { _, count in
            let descriptor = MTLVisibleFunctionTableDescriptor()
            descriptor.functionCount = count
            return state.makeVisibleFunctionTable(descriptor: descriptor)
        }
        handle = { name, _ in state.functionHandle(withName: name) }
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
