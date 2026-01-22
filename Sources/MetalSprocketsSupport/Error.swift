import Foundation

public indirect enum MetalSprocketsError: Error, Equatable {
    case undefined
    case generic(String)
    case missingEnvironment(String)
    case missingBinding(String)
    case resourceCreationFailure(String)
    case deviceCababilityFailure(String)
    case validationError(String)
    case configurationError(String)
    case unexpectedError(Self)
    /// Wraps an error with a hint to help the user understand what might be wrong.
    case withHint(Self, hint: String)
}

extension MetalSprocketsError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .undefined:
            return "Undefined error"
        case .generic(let message):
            return message
        case .missingEnvironment(let name):
            return "Missing environment value: \(name)"
        case .missingBinding(let name):
            return "Missing binding: \(name)"
        case .resourceCreationFailure(let message):
            return "Resource creation failure: \(message)"
        case .deviceCababilityFailure(let message):
            return "Device capability failure: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .unexpectedError(let error):
            return "Unexpected error: \(error)"
        case let .withHint(error, hint):
            return "\(error.description)\nHint: \(hint)"
        }
    }
}

public extension Optional {
    func orThrow(_ error: @autoclosure () -> MetalSprocketsError) throws -> Wrapped {
        // swiftlint:disable:next self_binding
        guard let value = self else {
            let error = error()
            if ProcessInfo.processInfo.fatalErrorOnThrow {
                fatalError("\(error)")
            }
            else {
                throw error
            }
        }
        return value
    }

    func orFatalError(_ message: @autoclosure () -> String = String()) -> Wrapped {
        // swiftlint:disable:next self_binding
        guard let value = self else {
            fatalError(message())
        }
        return value
    }

    func orFatalError(_ error: @autoclosure () -> MetalSprocketsError) -> Wrapped {
        // swiftlint:disable:next self_binding
        guard let value = self else {
            fatalError("\(error())")
        }
        return value
    }
}

public func _throw(_ error: some Error) throws -> Never {
    if ProcessInfo.processInfo.fatalErrorOnThrow {
        fatalError("\(error)")
    }
    else {
        throw error
    }
}
