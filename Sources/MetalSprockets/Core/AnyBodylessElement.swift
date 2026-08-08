/// A leaf element with no body that runs caller-supplied closures at the setup and workload phase boundaries.
///
/// This is the escape hatch for elements that need to do work during a phase but have nothing to render on their own.
/// Instead of declaring a bespoke `Element` type that conforms to ``SetupElement``/``WorkloadElement`` just to hang one
/// closure off it, build one of these with the `on…` modifiers and return it as an element's `body`:
///
/// ```swift
/// public var body: some Element {
///     AnyBodylessElement()
///         .onWorkloadEnter { (node: Node) in
///             // Encode something using the node's environment.
///         }
/// }
/// ```
///
/// `MetalFXTemporal` and `MetalFXSpatial` are the canonical uses.
///
/// - Important: ``requiresSetup(comparedTo:)`` always returns `true` because closures cannot be compared, so the
///   setup phase re-runs every frame. Put per-frame work in `onWorkloadEnter`/`onWorkloadExit`, and only put work in
///   `onSetupEnter`/`onSetupExit` if running it every frame is harmless.
internal struct AnyBodylessElement: Element, SetupElement, WorkloadElement {
    fileprivate var _setupEnter: ((Node) throws -> Void)?
    fileprivate var _setupExit: ((Node) throws -> Void)?
    fileprivate var _workloadEnter: ((Node) throws -> Void)?
    fileprivate var _workloadExit: ((Node) throws -> Void)?

    init() {
        // This line intentionally left blank.
    }

    func configureNodeBodyless(_ node: Node) throws {
        // This line intentionally left blank.
    }

    func setupEnter(_ node: Node) throws {
        try _setupEnter?(node)
    }

    func setupExit(_ node: Node) throws {
        try _setupExit?(node)
    }

    func workloadEnter(_ node: Node) throws {
        try _workloadEnter?(node)
    }

    func workloadExit(_ node: Node) throws {
        try _workloadExit?(node)
    }

    nonisolated func requiresSetup(comparedTo old: Self) -> Bool {
        // Closures are not comparable, so a changed closure is indistinguishable from an unchanged one.
        true
    }
}

// Modifier-style builders. Each returns a copy with one phase closure replaced, so they chain like SwiftUI modifiers:
//
//     AnyBodylessElement().onSetupEnter { … }.onWorkloadEnter { … }
//
// Each phase holds at most one closure; calling the same modifier twice replaces the previous one rather than
// accumulating. Every hook comes in two overloads: one taking the `Node` (for environment access) and one taking
// nothing, for closures that don't need it.
internal extension AnyBodylessElement {
    /// Runs `action` when the setup phase enters this element, before its children.
    func onSetupEnter(_ action: @escaping (Node) throws -> Void) -> AnyBodylessElement {
        var modifier = self
        modifier._setupEnter = action
        return modifier
    }

    /// Runs `action` when the setup phase enters this element, before its children.
    func onSetupEnter(_ action: @escaping () throws -> Void) -> AnyBodylessElement {
        var modifier = self
        modifier._setupEnter = { _ in try action() }
        return modifier
    }

    /// Runs `action` when the setup phase leaves this element, after its children.
    func onSetupExit(_ action: @escaping (Node) throws -> Void) -> AnyBodylessElement { // periphery:ignore
        var modifier = self
        modifier._setupExit = action
        return modifier
    }

    /// Runs `action` when the setup phase leaves this element, after its children.
    func onSetupExit(_ action: @escaping () throws -> Void) -> AnyBodylessElement { // periphery:ignore
        var modifier = self
        modifier._setupExit = { _ in try action() }
        return modifier
    }

    /// Runs `action` when the workload phase enters this element, before its children.
    func onWorkloadEnter(_ action: @escaping (Node) throws -> Void) -> AnyBodylessElement {
        var modifier = self
        modifier._workloadEnter = action
        return modifier
    }

    /// Runs `action` when the workload phase enters this element, before its children.
    func onWorkloadEnter(_ action: @escaping () throws -> Void) -> AnyBodylessElement {
        var modifier = self
        modifier._workloadEnter = { _ in try action() }
        return modifier
    }

    /// Runs `action` when the workload phase leaves this element, after its children.
    func onWorkloadExit(_ action: @escaping (Node) throws -> Void) -> AnyBodylessElement { // periphery:ignore
        var modifier = self
        modifier._workloadExit = action
        return modifier
    }

    /// Runs `action` when the workload phase leaves this element, after its children.
    func onWorkloadExit(_ action: @escaping () throws -> Void) -> AnyBodylessElement { // periphery:ignore
        var modifier = self
        modifier._workloadExit = { _ in try action() }
        return modifier
    }
}
