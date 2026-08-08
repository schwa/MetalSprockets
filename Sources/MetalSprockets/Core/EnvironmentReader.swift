//
//  EnvironmentReader.swift
//  MetalSprockets
//
//  Created by Jonathan Wight on 9/12/25.
//

public struct EnvironmentReader<Value, Content: Element>: Element, BodylessElement {
    var keyPath: KeyPath<MSEnvironmentValues, Value>
    var content: (Value) throws -> Content

    public init(keyPath: KeyPath<MSEnvironmentValues, Value>, @ElementBuilder content: @escaping (Value) throws -> Content) {
        self.keyPath = keyPath
        self.content = content
    }

    func visitChildrenBodyless(_ visit: (any Element) throws -> Void) throws {
        // TODO: #212 Ideally we would be passed a Node as a parameter here instead of asking the traversal context
        guard let system = System.current, let node = system.traversalContext.currentNode else {
            fatalError("EnvironmentReader must be visited within a System context, during an active traversal.")
        }
        let value = node.environmentValues[keyPath: keyPath]
        let content = try content(value)
        try visit(content)
    }

    nonisolated func requiresSetup(comparedTo old: EnvironmentReader<Value, Content>) -> Bool {
        // The reader itself does no setup work; it only produces content, which is visited as a
        // child and compared on its own terms. Only a different key path matters here. (#343)
        keyPath != old.keyPath
    }
}
