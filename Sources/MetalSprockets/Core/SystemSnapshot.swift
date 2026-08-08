import Foundation

/// A complete snapshot of the System state for debugging purposes
public struct SystemSnapshot: Codable, Sendable {
    public let timestamp: Date
    public let nodes: [NodeSnapshot]
    public let orderedIdentifiers: [String]
    public let dirtyIdentifiers: Set<String>
    public let activeNodeStackDepth: Int

    package init(system: System) {
        self.timestamp = Date()

        // Only enter events; exit events would duplicate every identifier.
        var extractedIdentifiers: [StructuralIdentifier] = []
        for event in system.traversalEvents {
            if case .enter(let node) = event {
                extractedIdentifiers.append(node.id)
            }
        }

        self.orderedIdentifiers = extractedIdentifiers.map(\.description)
        self.dirtyIdentifiers = Set(system.dirtyIdentifiers.map(\.description))
        self.activeNodeStackDepth = system.traversalContext.depth

        self.nodes = extractedIdentifiers.compactMap { identifier in
            guard let node = system.nodes[identifier] else {
                return nil
            }
            return NodeSnapshot(node: node)
        }
    }
}

/// Snapshot of a single node
public struct NodeSnapshot: Codable, Sendable {
    public let identifier: String
    public let parentIdentifier: String?
    public let elementType: String
    public let elementDescription: String
    public let stateProperties: [StatePropertySnapshot]
    public let environmentValues: EnvironmentSnapshot
    public let needsSetup: Bool

    init(node: Node) {
        self.identifier = node.id.description
        self.parentIdentifier = node.parentIdentifier?.description
        self.needsSetup = node.needsSetup

        let element = node.element
        self.elementType = String(describing: type(of: element))

        let mirror = Mirror(reflecting: element)
        var elementInfo = [String: String]()
        for child in mirror.children {
            if let label = child.label {
                elementInfo[label] = "\(child.value)"
            }
        }
        self.elementDescription = elementInfo.isEmpty ? elementType : "\(elementType)(\(elementInfo.map { "\($0.key): \($0.value)" }.joined(separator: ", ")))"

        self.stateProperties = node.stateProperties.compactMap { key, value in
            StatePropertySnapshot(key: key, value: value)
        }

        self.environmentValues = EnvironmentSnapshot(environmentValues: node.environmentValues)
    }
}

/// Snapshot of a state property
public struct StatePropertySnapshot: Codable, Sendable {
    public let key: String
    public let type: String
    public let value: String
    public let dependencies: [String]

    init(key: String, value: Any) {
        self.key = key

        let mirror = Mirror(reflecting: value)

        if String(describing: Swift.type(of: value)).contains("StateBox") {
            self.type = "StateBox"

            if let valueProvider = value as? (any SnapshotValueProviding) {
                self.value = "\(valueProvider.snapshotValue)"
            } else {
                if let valueChild = mirror.children.first(where: { $0.label == "_value" }) {
                    self.value = "\(valueChild.value)"
                } else {
                    self.value = "\(value)"
                }
            }

            if let depsChild = mirror.children.first(where: { $0.label == "dependencies" }) {
                let depsMirror = Mirror(reflecting: depsChild.value)
                var deps = [String]()
                for child in depsMirror.children {
                    let weakBoxMirror = Mirror(reflecting: child.value)
                    if let nodeChild = weakBoxMirror.children.first {
                        if let node = nodeChild.value as? Node {
                            deps.append(node.id.description)
                        }
                    }
                }
                self.dependencies = deps
            } else {
                self.dependencies = []
            }
        } else {
            self.type = String(describing: Swift.type(of: value))
            self.value = "\(value)"
            self.dependencies = []
        }
    }
}

/// Snapshot of environment values
public struct EnvironmentSnapshot: Codable, Sendable {
    public let values: [String: String]
    public let hasParent: Bool

    init(environmentValues: MSEnvironmentValues) {
        var extractedValues = [String: String]()
        for (key, value) in environmentValues.values {
            let keyDescription = "\(key.value)".components(separatedBy: ".").last ?? "\(key.value)"
            extractedValues[keyDescription] = "\(value)"
        }
        self.values = extractedValues
        self.hasParent = !environmentValues.inheritedValues.isEmpty
    }
}

// MARK: - Text Dump Support

public extension SystemSnapshot {
    /// Generate a human-readable text dump
    func textDump(includeEnvironment: Bool = false) -> String {
        var output = [String]()

        output.append("=== SYSTEM SNAPSHOT ===")
        output.append("Timestamp: \(timestamp)")
        output.append("Total Nodes: \(nodes.count)")
        output.append("Dirty Nodes: \(dirtyIdentifiers.count)")
        output.append("Active Stack Depth: \(activeNodeStackDepth)")
        output.append("")

        var nodesByIdentifier = [String: NodeSnapshot]()
        for node in nodes {
            nodesByIdentifier[node.identifier] = node
        }

        let rootNodes = nodes.filter { $0.parentIdentifier == nil }

        output.append("=== NODE HIERARCHY ===")
        for rootNode in rootNodes {
            output.append(contentsOf: dumpNode(rootNode, nodesByIdentifier: nodesByIdentifier, indent: 0, includeEnvironment: includeEnvironment))
        }

        if !dirtyIdentifiers.isEmpty {
            output.append("")
            output.append("=== DIRTY NODES ===")
            for identifier in dirtyIdentifiers.sorted() {
                output.append("  • \(identifier)")
            }
        }

        return output.joined(separator: "\n")
    }

    private func dumpNode(_ node: NodeSnapshot, nodesByIdentifier: [String: NodeSnapshot], indent: Int, includeEnvironment: Bool) -> [String] {
        var output = [String]()
        let indentStr = String(repeating: "  ", count: indent)

        let isDirty = dirtyIdentifiers.contains(node.identifier)
        let dirtyMarker = isDirty ? " [DIRTY]" : ""
        let setupMarker = node.needsSetup ? " [NEEDS SETUP]" : ""
        output.append("\(indentStr)• \(node.elementType)\(dirtyMarker)\(setupMarker)")
        output.append("\(indentStr)  ID: \(node.identifier)")

        if !node.stateProperties.isEmpty {
            output.append("\(indentStr)  State:")
            for prop in node.stateProperties {
                output.append("\(indentStr)    - \(prop.key): \(prop.value)")
                if !prop.dependencies.isEmpty {
                    output.append("\(indentStr)      deps: [\(prop.dependencies.joined(separator: ", "))]")
                }
            }
        }

        if includeEnvironment, !node.environmentValues.values.isEmpty {
            output.append("\(indentStr)  Environment:")
            for (key, value) in node.environmentValues.values.sorted(by: { $0.key < $1.key }) {
                output.append("\(indentStr)    - \(key): \(value)")
            }
        }

        let children = nodes.filter { $0.parentIdentifier == node.identifier }
        for child in children {
            output.append(contentsOf: dumpNode(child, nodesByIdentifier: nodesByIdentifier, indent: indent + 1, includeEnvironment: includeEnvironment))
        }

        return output
    }
}
