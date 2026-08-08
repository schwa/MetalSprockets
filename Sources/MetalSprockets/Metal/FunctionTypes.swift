import Metal

/// A set of Metal function types, for APIs that can target more than one shader stage at once.
///
/// ```swift
/// .parameter("uniforms", functionTypes: [.vertex, .fragment], value: uniforms)
/// ```
public struct FunctionTypes: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let vertex = Self(rawValue: 1 << 0)
    public static let fragment = Self(rawValue: 1 << 1)
    public static let kernel = Self(rawValue: 1 << 2)
    public static let object = Self(rawValue: 1 << 3)
    public static let mesh = Self(rawValue: 1 << 4)
    public static let visible = Self(rawValue: 1 << 5)
    public static let intersection = Self(rawValue: 1 << 6)

    /// The stages of a classic vertex/fragment render pipeline.
    public static let render: Self = [.vertex, .fragment]

    /// The stages of a mesh render pipeline.
    public static let meshRender: Self = [.object, .mesh, .fragment]

    /// Creates a set containing a single Metal function type.
    public init(_ functionType: MTLFunctionType) {
        switch functionType {
        case .vertex:
            self = .vertex
        case .fragment:
            self = .fragment
        case .kernel:
            self = .kernel
        case .object:
            self = .object
        case .mesh:
            self = .mesh
        case .visible:
            self = .visible
        case .intersection:
            self = .intersection
        @unknown default:
            self = []
        }
    }

    /// Creates a set containing a single Metal function type, or an empty set for `nil`.
    public init(_ functionType: MTLFunctionType?) {
        guard let functionType else {
            self = []
            return
        }
        self.init(functionType)
    }

    /// The individual Metal function types in this set, in pipeline order.
    public var functionTypes: [MTLFunctionType] {
        let ordered: [(Self, MTLFunctionType)] = [
            (.object, .object),
            (.mesh, .mesh),
            (.vertex, .vertex),
            (.fragment, .fragment),
            (.kernel, .kernel),
            (.visible, .visible),
            (.intersection, .intersection)
        ]
        return ordered.compactMap { option, functionType in
            contains(option) ? functionType : nil
        }
    }
}
