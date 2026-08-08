public extension Element {
    func dump(to output: inout String, indent: Int = 0) throws {
        output.append(try dumpedTree(indent: indent) { element in
            element.debugName
        })
    }

    func dump() throws -> String {
        var output = ""
        try dump(to: &output)
        return output
    }

    func printDump() throws {
        print(try dump())
    }
}

// More detailed dump with additional information
public extension Element {
    func dumpVerbose(to output: inout String, indent: Int = 0) throws {
        output.append(try dumpedTree(indent: indent) { element in
            let typeName = String(describing: type(of: element))
            let typeId = ObjectIdentifier(type(of: element) as any Element.Type).shortId
            let isBodyless = element is any BodylessElement
            return "\(typeName) [id: \(typeId), bodyless: \(isBodyless)]"
        })
    }

    func dumpVerbose() throws -> String {
        var output = ""
        try dumpVerbose(to: &output)
        return output
    }
}

private extension Element {
    /// Renders the element tree by expanding it into a throwaway ``System`` and walking the resulting nodes.
    ///
    /// Walking the element tree directly is unsafe: expansion of elements like ``EnvironmentReader`` needs an active
    /// system, and dynamic properties expect to be bound to a node. Building a private system gives the tree the
    /// context it needs and leaves any live system untouched. See #218.
    func dumpedTree(indent: Int, describe: (any Element) -> String) throws -> String {
        let system = System()
        try system.update(root: self)

        var output = ""
        var depth = indent
        for event in system.traversalEvents {
            switch event {
            case .enter(let node):
                output.append("\(String(repeating: "  ", count: depth))\(describe(node.element))\n")
                depth += 1
            case .exit:
                depth -= 1
            }
        }
        return output
    }
}
