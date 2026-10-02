import Metal
import MetalSprocketsSupport

public struct ShaderFunction: Hashable, Sendable {
    public let library: any MTLLibrary
    public let name: String
    public let functionType: MTLFunctionType
    public let constants: FunctionConstants
    public let specializedName: String?
    public let metalFunction: any MTLFunction

    public init(library: any MTLLibrary, name: String, type: MTLFunctionType, constants: FunctionConstants = FunctionConstants(), specializedName: String? = nil) throws {
        if let specializedName, specializedName.isEmpty {
            throw MetalSprocketsError.configurationError("A specialized function name must not be empty")
        }
        guard let baseFunction = library.makeFunction(name: name) else {
            throw MetalSprocketsError.resourceCreationFailure("Function '\(name)' not found in library")
        }
        guard baseFunction.functionType == type else {
            throw MetalSprocketsError.configurationError("Function '\(name)' has type \(baseFunction.functionType), expected \(type)")
        }
        let values = try constants.validatedMTLConstants(declared: baseFunction.functionConstantInfos, functionName: name)
        self.library = library
        self.name = name
        self.functionType = type
        self.constants = constants
        self.specializedName = specializedName
        if constants.isEmpty, specializedName == nil {
            self.metalFunction = baseFunction
        } else {
            let descriptor = MTLFunctionDescriptor()
            descriptor.name = name
            descriptor.constantValues = values
            descriptor.specializedName = specializedName
            self.metalFunction = try library.makeFunction(descriptor: descriptor)
        }
    }

    init(library: any MTLLibrary, name: String, constants: FunctionConstants, validatedFunction: any MTLFunction) {
        self.library = library
        self.name = name
        self.functionType = validatedFunction.functionType
        self.constants = constants
        self.specializedName = nil
        self.metalFunction = validatedFunction
    }

    func validate(type: MTLFunctionType) throws {
        guard functionType == type else {
            throw MetalSprocketsError.configurationError("Function '\(name)' has type \(functionType), expected \(type)")
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.library === rhs.library && lhs.name == rhs.name && lhs.functionType == rhs.functionType && lhs.constants == rhs.constants && lhs.specializedName == rhs.specializedName
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(library))
        hasher.combine(name)
        hasher.combine(functionType.rawValue)
        hasher.combine(constants)
        hasher.combine(specializedName)
    }

    @available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
    func makeFunctionDescriptor() throws -> MTL4FunctionDescriptor {
        let descriptor = MTL4LibraryFunctionDescriptor()
        descriptor.library = library
        descriptor.name = name
        guard !constants.isEmpty || specializedName != nil else {
            return descriptor
        }
        guard let baseFunction = library.makeFunction(name: name) else {
            throw MetalSprocketsError.resourceCreationFailure("Function '\(name)' not found in library")
        }
        let specialized = MTL4SpecializedFunctionDescriptor()
        specialized.functionDescriptor = descriptor
        specialized.specializedName = specializedName
        specialized.constantValues = try constants.validatedMTLConstants(declared: baseFunction.functionConstantInfos, functionName: name)
        return specialized
    }
}
