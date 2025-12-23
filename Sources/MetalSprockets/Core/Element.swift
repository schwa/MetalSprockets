import MetalSprocketsSupport

// MARK: - Element Protocol

/// The fundamental building block of MetalSprockets render graphs.
///
/// `Element` is analogous to SwiftUI's `View` protocol. Each element describes
/// a unit of GPU work — such as a render pass, pipeline configuration, or draw command.
/// Elements compose together to form a declarative render graph.
///
/// ## Creating Custom Elements
///
/// Conform to `Element` and implement the `body` property to compose other elements:
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
/// ## Element Lifecycle
///
/// Elements go through two phases:
/// 1. **Setup**: Pipeline states and resources are created (runs when structure changes)
/// 2. **Workload**: Draw commands are encoded (runs every frame)
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
    /// Implement this property to compose child elements. Use the `@ElementBuilder`
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
            try visit(body)
        }
    }
}
