import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// Expands `@MSState var x: T = expr` the way SwiftUI 27 expands `@State` (#578):
// - `_x` is the `MSState` storage. A declaration default goes through `MSState(initialValue:)`, which takes an
//   autoclosure, so it is evaluated once per element identity rather than on every rebuild.
// - Without a default, `x` gets an init accessor, so `self.x = value` in an initializer works (eagerly). With a
//   default, the assignment goes through the setter.
// - `$x` is the binding. Without a type annotation it uses `@MSStateProjectedValue`, whose initializer exists only
//   to infer the type.
public struct MSStateMacro: AccessorMacro, PeerMacro {
    struct Info {
        var name: String
        var type: TypeSyntax?
        var initializer: ExprSyntax?
        var accessModifier: String
    }

    static func info(of declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext, diagnose: Bool) -> Info? {
        let isMember = context.lexicalContext.first.map { scope in
            scope.is(StructDeclSyntax.self) || scope.is(ClassDeclSyntax.self) || scope.is(ActorDeclSyntax.self)
                || scope.is(EnumDeclSyntax.self) || scope.is(ExtensionDeclSyntax.self)
        } ?? false
        guard isMember else {
            if diagnose {
                context.diagnose(Diagnostic(node: declaration, message: MSStateDiagnostic.notAProperty))
            }
            return nil
        }
        guard let variable = declaration.as(VariableDeclSyntax.self),
              variable.bindingSpecifier.tokenKind == .keyword(.var),
              variable.bindings.count == 1,
              let binding = variable.bindings.first,
              let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              binding.accessorBlock == nil
        else {
            if diagnose {
                context.diagnose(Diagnostic(node: declaration, message: MSStateDiagnostic.notStoredVar))
            }
            return nil
        }
        if binding.typeAnnotation == nil, binding.initializer == nil {
            if diagnose {
                context.diagnose(Diagnostic(node: declaration, message: MSStateDiagnostic.missingType))
            }
            return nil
        }
        let accessModifier = variable.modifiers
            .first { modifier in
                [.keyword(.public), .keyword(.package), .keyword(.internal), .keyword(.fileprivate), .keyword(.private)]
                    .contains(modifier.name.tokenKind) && modifier.detail == nil
            }
            .map { "\($0.name.text) " } ?? ""
        return Info(
            name: name,
            type: binding.typeAnnotation?.type.trimmed,
            initializer: binding.initializer?.value.trimmed,
            accessModifier: accessModifier
        )
    }

    static func isOptional(_ type: TypeSyntax) -> Bool {
        if type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return true
        }
        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.name.text == "Optional" {
            return true
        }
        if let member = type.as(MemberTypeSyntax.self), member.name.text == "Optional" {
            return true
        }
        return false
    }

    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let info = info(of: declaration, in: context, diagnose: false) else {
            return []
        }
        let name = info.name
        // `nonmutating` is only valid in value types.
        let isInReferenceType = context.lexicalContext.first.map { $0.is(ClassDeclSyntax.self) || $0.is(ActorDeclSyntax.self) } ?? false
        let setter = isInReferenceType ? "set" : "nonmutating set"
        // With an init accessor, the compiler passes the declaration default through it in every initializer, which
        // evaluates it eagerly (this is what SwiftUI 27's `@State` does). Without one, the default only lives in the
        // lazy `_x` storage, and assigning in an initializer goes through the setter.
        if info.initializer != nil {
            return [
                """
                get {
                    _\(raw: name).wrappedValue
                }
                """,
                """
                \(raw: setter) {
                    _\(raw: name).wrappedValue = newValue
                }
                """
            ]
        }
        return [
            """
            @storageRestrictions(initializes: _\(raw: name))
            init(initialValue) {
                _\(raw: name) = MetalSprockets.MSState(wrappedValue: initialValue)
            }
            """,
            """
            get {
                _\(raw: name).wrappedValue
            }
            """,
            """
            \(raw: setter) {
                _\(raw: name).wrappedValue = newValue
            }
            """
        ]
    }

    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let info = info(of: declaration, in: context, diagnose: true) else {
            return []
        }
        let name = info.name
        let stateType: String = info.type.map { "MetalSprockets.MSState<\($0)>" } ?? "MetalSprockets.MSState"

        var initializer = info.initializer
        if initializer == nil, let type = info.type, isOptional(type) {
            initializer = "nil"
        }

        let storage: DeclSyntax
        let projection: DeclSyntax
        if let initializer {
            storage = "private var _\(raw: name) = \(raw: stateType)(initialValue: \(initializer))"
        } else if info.type != nil {
            storage = "private var _\(raw: name): \(raw: stateType)"
        } else {
            return []
        }
        if let type = info.type {
            projection = """
            \(raw: info.accessModifier)var $\(raw: name): MetalSprockets.MSBinding<\(type)> {
                _\(raw: name).projectedValue
            }
            """
        } else if let initializer {
            projection = """
            @MetalSprockets.MSStateProjectedValue
            \(raw: info.accessModifier)var $\(raw: name) = \(raw: stateType)(initialValue: \(initializer)).projectedValue
            """
        } else {
            return [storage]
        }
        return [storage, projection]
    }
}

// Turns `var $x = MSState(initialValue: …).projectedValue` into a getter for `_x.projectedValue`. The initializer is
// only used to infer the type and is never evaluated.
public struct MSStateProjectedValueMacro: AccessorMacro {
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let binding = declaration.as(VariableDeclSyntax.self)?.bindings.first,
              let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              name.hasPrefix("$")
        else {
            return []
        }
        return [
            """
            get {
                _\(raw: name.dropFirst()).projectedValue
            }
            """
        ]
    }
}

internal enum MSStateDiagnostic: String, DiagnosticMessage {
    case notStoredVar
    case notAProperty
    case missingType

    var message: String {
        switch self {
        case .notStoredVar:
            "@MSState can only be applied to a single stored 'var' property"
        case .notAProperty:
            "@MSState can only be applied to a property of a type, not a local or global variable"
        case .missingType:
            "@MSState property needs a type annotation or an initial value"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "MetalSprocketsMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
