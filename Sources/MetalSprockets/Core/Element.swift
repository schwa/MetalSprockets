import MetalSprocketsSupport
import Observation

// MARK: - Element Protocol

/// The fundamental building block of MetalSprockets render graphs.
///
/// `Element` is analogous to SwiftUI's `View` protocol. Elements can represent many things:
/// GPU work (render passes, pipelines, draw commands), organizational containers (``Group``,
/// ``ForEach``), or modifiers that configure child elements. Elements compose together
/// to form a declarative render graph.
///
/// ## Creating Custom Elements
///
/// Conform to `Element` and implement the `body` property to compose other elements.
/// Use ``ElementBuilder`` to combine multiple child elements:
///
/// ```swift
/// struct MyTriangle: Element {
///     var body: some Element {
///         RenderPass {
///             RenderPipeline(vertexShader: vs, fragmentShader: fs) {
///                 Draw { encoder in
///                     // Issue draw commands
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Core Elements
/// - ``RenderPass``
/// - ``RenderPipeline``
/// - ``Draw``
/// - ``ComputePass``
///
/// ### State Management
/// - ``MSState``
/// - ``MSBinding``
/// - ``MSEnvironment``
public protocol Element {
    /// The type of element returned by the `body` property.
    associatedtype Body: Element

    /// The content and behavior of this element.
    ///
    /// Implement this property to compose child elements. Use the ``ElementBuilder``
    /// result builder to combine multiple elements.
    @ElementBuilder var body: Body { get throws }
}

extension Never: Element {
    public typealias Body = Never
}

public extension Element where Body == Never {
    var body: Never {
        unreachable("`body` is not implemented for `Never` types (on \(self)).")
    }
}

internal extension Element {
    func visitChildren(_ visit: (any Element) throws -> Void) throws {
        if let bodyless = self as? any BodylessElement {
            try bodyless.visitChildrenBodyless(visit)
        } else if Body.self != Never.self {
            // See #248. Writing `var body: any Element` satisfies the protocol but
            // silently breaks traversal because the existential never matches the
            // concrete-type paths the system expects. Catch it in debug builds.
            assert(Body.self != (any Element).self, "Element body must return `some Element`, not `any Element` (on \(type(of: self))). See #248.")
            try visit(trackedBody)
        }
    }

    /// `body`, evaluated under observation tracking so that mutating any `@Observable` property it read marks the
    /// owning node dirty. This is the `@Observable` counterpart of ``StateBox``'s read-tracking. See #287.
    private var trackedBody: Body {
        get throws {
            guard let system = System.current, let node = system.traversalContext.currentNode else {
                return try body
            }
            // Only the identifier is captured: the change handler is `@Sendable` and may run off the owning
            // isolation, and marking dirty is the lock-guarded part. The next update re-evaluates the node's element
            // and decides whether setup has to run again.
            let id = node.id
            var result: Result<Body, any Error>?
            withObservationTracking {
                result = Result { try body }
            } onChange: {
                system.markDirty(id)
            }
            guard let result else {
                preconditionFailure("withObservationTracking did not run its body.")
            }
            return try result.get()
        }
    }
}
