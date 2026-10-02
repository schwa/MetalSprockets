import Metal

public struct ResidencyConfiguration {
    public enum Mode: Sendable {
        case automatic
        case manual
    }

    public var mode: Mode
    public var collections: [ResourceCollection]
    public var residencySets: [any MTLResidencySet]

    public init(mode: Mode = .automatic, collections: [ResourceCollection] = [], residencySets: [any MTLResidencySet] = []) {
        self.mode = mode
        self.collections = collections
        self.residencySets = residencySets
    }
}
