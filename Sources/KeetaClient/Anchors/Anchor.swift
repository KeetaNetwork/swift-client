import Foundation

public protocol OperationIdentifiable: RawRepresentable & CaseIterable & Hashable {
    var id: RawValue { get }
    var isOptional: Bool { get }
}

public extension OperationIdentifiable {
    var id: RawValue { rawValue }
    var isOptional: Bool { false }
}

public protocol Anchor: HTTPClient {
    associatedtype OperationID: OperationIdentifiable
    
    var operations: [OperationID: AnchorOperation] { get }
}

extension Anchor {
    func validateOperations(_ exclude: Set<OperationID> = []) throws {
        // Ensure all required operations are available
        for operation in OperationID.allCases {
            if operation.isOptional || exclude.contains(operation) { continue }
            
            guard operations[operation] != nil else {
                throw AnchorOperationError.missingOperation(operation.rawValue)
            }
        }
    }
    
    func url(for operation: OperationID, parameters: [String: String] = [:]) throws -> URL {
        guard let operation = operations[operation] else {
            throw AnchorOperationError.missingOperation(operation.rawValue)
        }
        return try operation.url(with: parameters)
    }

    func authenticationType(for operation: OperationID) -> AuthenticationType {
        guard let op = operations[operation] else { return .none }
        for option in op.options {
            if case .authentication(let type, _) = option {
                return type
            }
        }
        return .none
    }
}
