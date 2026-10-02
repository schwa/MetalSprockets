import Metal
import MetalSprocketsSupport
import os

public extension MetalSprocketsError {
    static func missingEnvironment(_ key: PartialKeyPath<MSEnvironmentValues>) -> Self {
        missingEnvironment("\(key)")
    }
}

// Resource declarations on Metal 4 are residency and lifetime: the resource stays resident and alive until the
// submission completes. They are not hazard tracking. `usage` and `stages` are accepted for source compatibility and
// documentation only; order dependent work with EncoderBarrier and QueueBarrier.

public extension Element {
    /// Keeps `resource` resident and alive for the submission, for resources a shader reaches indirectly (argument
    /// buffers, GPU addresses) or that a raw encoder closure uses.
    func useResource(_ resource: any MTLResource, usage: MTLResourceUsage, stages: MTLRenderStages) -> some Element {
        useResources([resource], usage: usage, stages: stages)
    }

    @ElementBuilder
    func useResource(_ resource: (any MTLResource)?, usage: MTLResourceUsage, stages: MTLRenderStages) -> some Element {
        if let resource {
            self.useResource(resource, usage: usage, stages: stages)
        }
        else {
            self
        }
    }

    /// Keeps `resources` resident and alive for the submission.
    func useResources(_ resources: [any MTLResource], usage: MTLResourceUsage, stages: MTLRenderStages) -> some Element {
        ScopeModifier(content: self) { scope in
            for resource in resources {
                try scope.retainAllocation(resource)
            }
        }
    }
}

public extension Element {
    /// Keeps `resource` resident and alive for the submission. See ``useResource(_:usage:stages:)``.
    func useComputeResource(_ resource: any MTLResource, usage: MTLResourceUsage) -> some Element {
        useComputeResources([resource], usage: usage)
    }

    @ElementBuilder
    func useComputeResource(_ resource: (any MTLResource)?, usage: MTLResourceUsage) -> some Element {
        if let resource {
            self.useComputeResource(resource, usage: usage)
        }
        else {
            self
        }
    }

    /// Keeps `resources` resident and alive for the submission.
    func useComputeResources(_ resources: [any MTLResource], usage: MTLResourceUsage) -> some Element {
        ScopeModifier(content: self) { scope in
            for resource in resources {
                try scope.retainAllocation(resource)
            }
        }
    }

    @ElementBuilder
    // The optional mirrors the single-resource overloads: nil means "nothing to bind", so callers can pass an
    // optional straight through without unwrapping.
    // swiftlint:disable:next discouraged_optional_collection
    func useComputeResources(_ resources: [any MTLResource]?, usage: MTLResourceUsage) -> some Element {
        if let resources {
            self.useComputeResources(resources, usage: usage)
        }
        else {
            self
        }
    }
}

internal func abbreviatedTypeName<T>(of t: T) -> String {
    let name = "\(type(of: t))"
    return String(name[..<(name.firstIndex(of: "<") ?? name.endIndex)])
}

internal extension ObjectIdentifier {
    var shortId: String {
        let description = String(describing: self)
        let pattern = #/^ObjectIdentifier\(0x(?'hex'[0-9a-f]+)\)$/#
        guard let match = description.firstMatch(of: pattern) else {
            fatalError("Cannot get shortID for \(self)")
        }
        guard let int = UInt64(match.output.hex, radix: 16) else {
            fatalError("Cannot get shortID for \(self)")
        }

        let alphabet: [Character] = Array("klmnopqrstuvwxyz")
        func encode(_ value: UInt64, minLength: Int = 1) -> String {
            precondition(minLength >= 1, "minLength must be ≥ 1")

            var v = value
            var out: [Character] = []

            if v == 0 {
                // Zero is just 'k' repeated to the requested minimum length.
                return String(repeating: "k", count: minLength)
            }

            while v > 0 {
                let nibble = Int(v & 0xF)
                out.append(alphabet[nibble])  // least-significant nibble first
                v >>= 4
            }

            // Pad to minimum length with 'k' (the zero digit), then reverse to big-endian.
            while out.count < minLength { out.append("k") }
            return String(out.reversed())
        }
        return encode(int)
    }
}
