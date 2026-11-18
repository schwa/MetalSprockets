import Metal

// One element of an argument buffer, as the shader declares it: field offsets and kinds from pipeline reflection.
internal struct ArgumentBufferLayout: Equatable {
    enum Kind: Equatable {
        case texture
        case sampler
        case pointer
        case textures(count: Int)
        case samplers(count: Int)
        case bytes
    }

    struct Field: Equatable {
        let offset: Int
        // Bytes up to the next field or the end of the element.
        let span: Int
        let kind: Kind
    }

    let stride: Int
    let fields: [String: Field]

    init?(_ binding: any MTLBufferBinding) {
        guard let structType = binding.bufferStructType else {
            return nil
        }
        let size = binding.bufferDataSize
        let alignment = max(binding.bufferAlignment, 1)
        stride = (size + alignment - 1) / alignment * alignment
        let members = structType.members.sorted { $0.offset < $1.offset }
        var fields: [String: Field] = [:]
        for (index, member) in members.enumerated() {
            let end = index + 1 < members.count ? members[index + 1].offset : size
            fields[member.name] = Field(offset: member.offset, span: end - member.offset, kind: Self.kind(of: member))
        }
        self.fields = fields
    }

    private static func kind(of member: MTLStructMember) -> Kind {
        switch member.dataType {
        case .texture:
            return .texture
        case .sampler:
            return .sampler
        case .pointer:
            return .pointer
        case .array:
            guard let array = member.arrayType() else {
                return .bytes
            }
            switch array.elementType {
            case .texture: return .textures(count: array.arrayLength)
            case .sampler: return .samplers(count: array.arrayLength)
            default: return .bytes
            }
        default:
            return .bytes
        }
    }
}
